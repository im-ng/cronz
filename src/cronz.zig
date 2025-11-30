const std = @import("std");
const job = @import("job.zig");
const Error = @import("error.zig");

const Cronz = @This();
const Self = @This();
const CronError = Error.CronError;
const RegExp = @import("regexp").Regex;
const Captures = @import("regexp").Captures;
const Datetime = @import("zdt").Datetime;
const time = std.time;
const Thread = std.Thread;
const Atomic = std.atomic.Value;

const totalDays: u8 = 31;
const totalHours: u8 = 23;
const totalMonths: u8 = 12;
const totalSeconds: u8 = 59;
const totalMinutes: u8 = 59;
const totalDaysOfWeek: u8 = 6;
const secondsIncluded: u8 = 6;
const minutesIncluded: u8 = 5;
pub const splitFormat = "(.*)/(\\d+)";
pub const rangeFormat = "^(\\d+)-(\\d+)$";
var _cronz: *Cronz = undefined;

allocator: std.mem.Allocator = undefined,
thread: std.Thread = undefined,
jobs: std.array_list.Managed(*job) = undefined,
mutex: std.Thread.Mutex = undefined,
signal: Atomic(bool) = undefined,
io: std.Io = undefined,

pub fn create(io: std.Io, allocator: std.mem.Allocator) !*Cronz {
    const c = try allocator.create(Cronz);
    errdefer allocator.destroy(c);

    c.mutex = .{};
    c.allocator = allocator;
    c.signal = Atomic(bool).init(true);
    c.jobs = std.array_list.Managed(*job).init(allocator);
    c.thread = try Thread.spawn(.{}, Cronz.runSchedules, .{c});
    c.io = io;

    _cronz = c;

    Cronz.registerInterruption();

    return c;
}

fn registerInterruption() void {
    // interrupt signal
    std.posix.sigaction(std.posix.SIG.INT, &.{
        .handler = .{ .handler = shutdown },
        .mask = std.posix.sigemptyset(),
        .flags = 0,
    }, null);

    // terminate signal
    std.posix.sigaction(std.posix.SIG.TERM, &.{
        .handler = .{ .handler = shutdown },
        .mask = std.posix.sigemptyset(),
        .flags = 0,
    }, null);
}

fn shutdown(_: std.posix.SIG) callconv(.c) void {
    _cronz.signal.store(false, .release);
}

pub fn Run(self: *Self) void {
    self.thread.join();
}

pub fn AddCronJob(
    self: *Self,
    schedule: []const u8,
    name: []const u8,
    hook: *const fn () anyerror!void,
) !void {
    try self.AddCron(schedule, name, hook);
}

fn AddCron(
    self: *Self,
    schedule: []const u8,
    name: []const u8,
    hook: *const fn () anyerror!void,
) !void {
    const j = self.parseSchedule(schedule) catch |err| {
        std.log.err("Bad schedule format provided {any}", .{err});
        return;
    };

    j.name = name;
    j.exec = hook;

    self.mutex.lock();
    try self.jobs.append(j);
    self.mutex.unlock();

    var msg: []u8 = undefined;
    msg = try self.allocator.alloc(u8, 100);
    msg = try std.fmt.bufPrint(msg, "{s} cron job added for execution", .{j.name});
    std.log.debug("{s}", .{msg});
}

pub fn destroy(self: *Self) void {
    self.signal.store(false, .release);
    self.thread.join();
}

fn runSchedules(self: *Self) !void {
    while (self.signal.load(.monotonic)) {
        try std.Io.Clock.Duration.sleep(.{ .clock = .real, .raw = .fromSeconds(1) }, self.io);
        const now = Datetime.nowUTC();
        for (self.jobs.items) |j| {
            if (j.compare(now)) {
                const thread = Thread.spawn(.{}, job.run, .{j}) catch |err| {
                    std.log.err("{any}", .{err});
                    return;
                };
                thread.join();
            }
        }
    }
}

fn expandOccurance(
    _: *Self,
    map: *std.AutoHashMap(u8, bool),
    max: u8,
    min: u8,
    step: u8,
) !void {
    var i = min;
    while (i <= max) {
        try map.put(i, true);
        i += step;
    }
}

fn expandRanges(
    self: *Self,
    value: []const u8,
    map: *std.AutoHashMap(u8, bool),
    max: u8,
    min: u8,
    step: u8,
) !void {
    var iterator = std.mem.splitAny(u8, value, ",");
    while (iterator.next()) |item| {
        // global compilation crashes
        var r = try RegExp.compile(self.allocator, "^(\\d+)-(\\d+)$");
        const rangeMatches = try RegExp.captures(&r, item);

        if (rangeMatches) |ranges| {
            const _min = try std.fmt.parseInt(u8, ranges.sliceAt(1).?, 10);
            const _max = try std.fmt.parseInt(u8, ranges.sliceAt(2).?, 10);

            if (_min < min and _max > max) {
                return Error.CronError.BadScheduleFormat;
            }

            try self.expandOccurance(map, _max, _min, step);
        } else {
            const _item = try std.fmt.parseInt(u8, item, 10);
            if (_item < min and _item > max) {
                return Error.CronError.BadScheduleFormat;
            }

            try map.put(_item, true);
        }
    }

    return;
}

fn expandSteps(
    self: *Self,
    prefix: []const u8,
    suffix: []const u8,
    map: *std.AutoHashMap(u8, bool),
    max: u8,
    min: u8,
) !void {
    var _min = min;
    var _max = max;

    if (std.mem.eql(u8, prefix, " ") == false and
        std.mem.eql(u8, prefix, "*") == false)
    {
        // global compilation crashes
        var r = try RegExp.compile(self.allocator, rangeFormat);
        const rangeMatches = try RegExp.captures(&r, suffix);
        if (rangeMatches == null) {
            return Error.CronError.BadScheduleFormat;
        }
        if (rangeMatches) |ranges| {
            _min = try std.fmt.parseInt(u8, ranges.sliceAt(1).?, 10);
            _max = try std.fmt.parseInt(u8, ranges.sliceAt(2).?, 10);

            if (_min < min and _max > max) {
                return Error.CronError.BadScheduleFormat;
            }
        }
    }

    const step = try std.fmt.parseInt(u8, suffix, 10);

    return self.expandOccurance(map, _max, _min, step);
}

fn expandOccurances(self: *Self, value: []const u8, map: *std.AutoHashMap(u8, bool), max: u8, min: u8) !void {
    // if it *, expand to the limits
    if (std.mem.eql(u8, value, "*")) {
        try self.expandOccurance(map, max, min, 1);
        return;
    }

    //*/5 1-4/5 * * *
    // global compilation crashes
    var s = try RegExp.compile(self.allocator, splitFormat);
    const matches = try RegExp.captures(&s, value);
    if (matches) |matched| {
        const prefix = matched.sliceAt(1).?;
        const suffix = matched.sliceAt(2).?;
        return self.expandSteps(prefix, suffix, map, max, min);
    }

    //55-59 1-4/5 * * *
    return self.expandRanges(value, map, max, min, 1);
}

fn parseSchedule(self: *Self, schedule: []const u8) !*job {
    var seconds: []const u8 = "";
    var minutes: []const u8 = "";
    var hours: []const u8 = "";
    var days: []const u8 = "";
    var months: []const u8 = "";
    var weekDay: []const u8 = "";
    var iterator = std.mem.splitAny(u8, schedule, " ");

    var scheduleLength: usize = 0;
    while (iterator.next()) |part| {
        switch (scheduleLength) {
            0 => seconds = part,
            1 => minutes = part,
            2 => hours = part,
            3 => days = part,
            4 => months = part,
            5 => weekDay = part,
            else => {},
        }
        scheduleLength += 1;
    }

    switch (scheduleLength) {
        5...6 => {
            // do nothing
        },
        else => {
            return Error.CronError.BadScheduleFormat;
        },
    }

    // create job for execution
    const j = try job.create(self.allocator);

    var index: u8 = 0;
    switch (scheduleLength) {
        6 => {
            try self.expandOccurances(seconds, &j.sec, totalSeconds, 0);
            index += 1;
        },
        else => {
            // do nothing
        },
    }

    // expand job occurances
    try self.expandOccurances(minutes, &j.min, totalMinutes, 0);

    try self.expandOccurances(hours, &j.hour, totalHours, 0);

    try self.expandOccurances(days, &j.day, totalDays, 0);

    try self.expandOccurances(months, &j.month, totalMonths, 0);

    try self.expandOccurances(weekDay, &j.dayOfWeek, totalDaysOfWeek, 0);

    return j;
}
