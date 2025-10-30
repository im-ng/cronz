![cronz](./docs/cronz.webp)

The purpose of this `zig` library is to enhance the scheduling of the repeatable tasks using the crontab notation with zero allocations once it is set.

This module prefers crontab notation to provide a clear and concise understanding of task repetition.

Cronz even supports the second-level execution. `* * * * * *`

This `zig` module has few dependencies apart from the std library. Refer to the attribution for more.

Additionally, it offers a straightforward invocation that allows developers to easily define and manage their scheduling needs.

With its focus on simple and zero allocation, this library is ideal for applications requiring efficient task management.

### [Example](./examples/basic/main.zig)

```zig
const std = @import("std");
const Cronz = @import("cronz");

var allocator: std.mem.Allocator = undefined;

pub fn main() !void {
    var arena_instance = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena_instance.deinit();
    allocator = arena_instance.allocator();

    const cronz = try Cronz.create(allocator);

    // executes tasks on every 0th, 10th, 20th, 30th and 40th second of each minute
    try cronz.AddCronJob("0,10,20,30,40 * * * * *", "task-1", task1);

    //execute tasks on every 2 second
    try cronz.AddCronJob("*/2 * * * * *", "task-2", task2);

    cronz.Run();
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
```

![alt](./docs/basic.webp)

### TODOs
- [x] Hook predefined method signature `fn method() !void`
- [ ] Hook custom method signatures `fn (comptime T) any returns`


### Usage

We can refer to examples [build.zig.zon](./examples/build.zig.zon) for quick setup

Add cronz to your build.zig.zon:

```bash
zig fetch --save https://github.com/im-ng/cronz/archive/refs/heads/main.zip
```

```zig
.{
    .name = .crontasks,
    .version = "0.0.1",
    .fingerprint = 0xb4e8ff8eb48991fd,
    .minimum_zig_version = "0.15.1",
    .dependencies = .{
        .cronz = .{
          .url = "git+https://github.com/im-ng/cronz.git#ab0acfc88702ec7a29432
         568d19086306e6fc87c",
          .hash = "cronz-0.0.1-pdBYEmcvAAB09KLva66o2ANaUqs8hDem1CEq0ksXooF-",
        },
    },
    .paths = .{
        "build.zig",
        "build.zig.zon",
        "src",
    },
    .use_llvm = true,
}

```

Update module depency in [build.zig](./examples/build.zig)

```zig
//reference cronz module
const cronz = b.dependency("cronz", .{});

//import cronz module to your root
exe.root_module.addImport("cronz", cronz.module("cronz"));
```

Now start importing as seen in above example.

### Supported Crontab notations

| Format            | What it does?           | Mode |
| ----------------- | ----------------------- | --- |
| \* \* \* \* \* \* | Execute on every second | |
| 1-10 \* \* \* \* \* | Execute between 1-10 seconds of each minute| Range |
| \* *\/2  * * * * | Execute on every two minutes | Split |
| \* 1,3,5,10 * * * * | Execute on every 1st, 3rd, 5th and 10th Minute| Repeat |

Refer [crontab](https://crontab.guru) for more format support

## 🤝 Attribution

- [zig-regex](github.com/tiehuis/zig-regex.git)
- [zdt](https://codeberg.org/FObersteiner/zdt.git)

## 📄 License

This project is licensed under the MIT License - see the LICENSE file for details.
