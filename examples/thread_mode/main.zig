const std = @import("std");
const Cronz = @import("cronz");
const Thread = std.Thread;

var allocator: std.mem.Allocator = undefined;

pub fn main() !void {
    var arena_instance = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena_instance.deinit();
    allocator = arena_instance.allocator();

    // var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    // allocator = gpa.allocator();
    // defer _ = gpa.detectLeaks();

    const cronz = try Cronz.create(allocator);

    // executes tasks on every 0th, 10th, 20th, 30th and 40th second of each minute
    try cronz.AddCronJob("0,10,20,30,40 * * * * *", "task-1", task1);

    //execute tasks on every 2 second
    try cronz.AddCronJob("*/2 * * * * *", "task-2", task2);

    const local_thread = try Thread.spawn(.{}, Cronz.Run, .{cronz});

    for (1..1000) |value| {
        std.log.debug("Perform tasks on main thread {d}", .{value});
    }

    //join when done
    local_thread.join();
}

fn task1() !void {
    var msg: []u8 = undefined;
    msg = try allocator.alloc(u8, 100);
    msg = try std.fmt.bufPrint(msg, "Task 1 performed", .{});

    std.log.debug("{d} {s}", .{ std.time.microTimestamp(), msg });
}

fn task2() !void {
    var msg: []u8 = undefined;
    msg = try allocator.alloc(u8, 100);
    msg = try std.fmt.bufPrint(msg, "Task 2  performed", .{});

    std.log.debug("{s}", .{msg});
}
