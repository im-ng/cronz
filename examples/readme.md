### tasks

This example demonstrates the usage of the `cronz` to schedule and repeat the tasks at your will.


```zig
const cronz = try Cronz.create(allocator);

// executes tasks on every 0th, 10th, 20th, 30th and 40th second of each minute
try cronz.AddCronJob("0,10,20,30,40 * * * * *", "task-1", task1);

//execute tasks on every 2 second
try cronz.AddCronJob("*/2 * * * * *", "task-2", task2);

cronz.Run();
```
