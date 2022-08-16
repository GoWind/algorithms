const calculator_iface = @import("calculator_interface.zig");
const std = @import("std");
const print = std.debug.print;

const Implementation = struct {
    const Self = @This();
    secret: i32,

    pub fn init(i_secret: i32) Self {
        return .{
            .secret = i_secret,
        };
    }
    pub fn add(_: *anyopaque, x: i32, y: i32) i32 {
        print("my add implementation", .{});
        return x + y;
    }
    pub fn sub(_: *anyopaque, x: i32, y: i32) i32 {
        print("my sub implementation", .{});
        return x - y;
    }
    pub fn mul(_: *anyopaque, x: i32, y: i32) i32 {
        print("my mul implementation", .{});
        return x * y;
    }
    pub fn div(_: *anyopaque, x: f32, y: f32) f32 {
        print("my div implementation", .{});
        return x / y;
    }

    pub fn myInterface(s: *Self) calculator_iface {
        return calculator_iface.init(s, Self.add, Self.sub, Self.mul, Self.div);
    }

    pub fn myInterfaceStack(s: *Self) calculator_iface {
        return calculator_iface.initStack(s, Self.add, Self.sub, Self.mul, Self.div);
    }
};

pub fn main() void {
    var i = Implementation.init(@as(i32, 45));
    var imi = i.myInterface();
    print("{}\n", .{imi.add(@as(i32, 10), @as(i32, 20))});
    print("{}\n", .{imi.div(@as(f32, 12.0), @as(f32, 2.10))});

    var imiS = i.myInterfaceStack();
    print("{}\n", .{imiS.add(@as(i32, 10), @as(i32, 20))});
    print("{}\n", .{imiS.div(@as(f32, 12.0), @as(f32, 2.10))});
}
