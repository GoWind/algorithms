const std = @import("std");
const automaton = @import("automaton.zig");

const heap_allocator = std.heap.page_allocator;
pub fn main() !void {
    var arena = std.heap.ArenaAllocator.init(heap_allocator);
    defer arena.deinit();
    var allocator = arena.allocator();
    const infix_str = "ab*(c|d|e)+".*;
    var n = try automaton.compile_nfa(allocator, &infix_str);
    var nfa_string = try automaton.printNFA(allocator, n);
    std.debug.print("{s}\n", .{nfa_string});
    const input = "abccdddce".*;
    var matched = try automaton.match(allocator, &infix_str, &input);
    std.debug.print("matched is {s}\n", .{matched});
}
