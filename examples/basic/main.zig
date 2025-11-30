const std = @import("std");
const Cronz = @import("cronz");

var allocator: std.mem.Allocator = undefined;

pub fn main() !void {
    var arena_instance = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena_instance.deinit();
    allocator = arena_instance.allocator();

    var threaded : std.Io.Threaded = .init(allocator);
    defer threaded.deinit();
    const cronz = try Cronz.create(threaded.io(), allocator);

    // executes tasks on every 0th, 5th, 10th, 20th, 30th and 40th second of each minute
    try cronz.AddCronJob("0,5,10,20,30,40 * * * * *", "task-1", task1);

    //execute tasks on every 2 second
    try cronz.AddCronJob("*/2 * * * * *", "task-2", task2);

    cronz.Run();
}

fn task1() !void {
    var msg: []u8 = undefined;
    msg = try allocator.alloc(u8, 100);
    msg = try std.fmt.bufPrint(msg, "Task 1 performed", .{});

    var threaded : std.Io.Threaded = .init(allocator);
    defer threaded.deinit();
    const io = threaded.io();
    std.log.debug("{d} {s}", .{ (try std.Io.Clock.Timestamp.now(io, .real)).raw.nanoseconds, msg });
}

fn task2() !void {
    var msg: []u8 = undefined;
    msg = try allocator.alloc(u8, 100);
    msg = try std.fmt.bufPrint(msg, "Task 2  performed", .{});

    std.log.debug("{s}", .{msg});
}
