const std = @import("std");
const DateTime = @import("zdt").Datetime;
const ticker = @import("ticker.zig");
const Self = @This();
const Job = @This();

name: []const u8 = undefined,
sec: std.AutoHashMap(u8, bool) = undefined,
min: std.AutoHashMap(u8, bool) = undefined,
hour: std.AutoHashMap(u8, bool) = undefined,
day: std.AutoHashMap(u8, bool) = undefined,
month: std.AutoHashMap(u8, bool) = undefined,
dayOfWeek: std.AutoHashMap(u8, bool) = undefined,
exec: *const fn () anyerror!void = undefined,
allocator: std.mem.Allocator = undefined,

pub fn create(allocator: std.mem.Allocator) !*Job {
    const j = try allocator.create(Job);
    j.sec = std.AutoHashMap(u8, bool).init(allocator);
    j.min = std.AutoHashMap(u8, bool).init(allocator);
    j.hour = std.AutoHashMap(u8, bool).init(allocator);
    j.day = std.AutoHashMap(u8, bool).init(allocator);
    j.month = std.AutoHashMap(u8, bool).init(allocator);
    j.dayOfWeek = std.AutoHashMap(u8, bool).init(allocator);
    j.allocator = allocator;
    return j;
}

pub fn run(self: *Self) !void {
    var timer = std.time.Timer.start() catch |err| {
        std.log.err("{any}", .{err});
        return;
    };

    self.exec() catch |err| {
        std.log.err("{any}", .{err});
        return;
    };

    const elapsed: f32 = @floatFromInt(timer.lap() / 1000000);

    var msg: []u8 = undefined;
    msg = try self.allocator.alloc(u8, 100);
    msg = try std.fmt.bufPrint(msg, "completed cron job: {s} in {d}ms", .{ self.name, elapsed });
    std.log.debug("{s}", .{msg});
}

pub fn getTick(_: *Self, now: DateTime) *const ticker {
    const yr: u16 = @as(u16, @intCast(now.year));
    const t = &ticker{
        .sec = @as(u16, now.second),
        .min = @as(u16, now.minute),
        .hour = @as(u16, now.hour),
        .day = @as(u16, now.day),
        .month = @as(u16, now.month),
        .year = yr,
        .dayOfWeek = @as(u16, now.weekdayNumber()),
    };
    return t;
}

pub fn compare(self: *Self, t: DateTime) bool {
    if (self.sec.contains(t.second) == false) {
        return false;
    }

    if (self.min.contains(t.minute) == false) {
        return false;
    }

    if (self.hour.contains(t.hour) == false) {
        return false;
    }

    if (self.day.contains(t.day) == false) {
        return false;
    }

    if (self.month.contains(t.month) == false) {
        return false;
    }

    if (self.dayOfWeek.contains(t.weekdayNumber()) == false) {
        return false;
    }

    return true;
}
