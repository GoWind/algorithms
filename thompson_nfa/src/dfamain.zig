const std = @import("std");
const Allocator = std.mem.Allocator;
const expect = std.testing.expect;
const m = @import("automaton.zig");
const StateSet = m.StateSet;
const NFA = m.NFA;

const testing = std.testing;

const nexts = std.AutoHashMap(u8, DState);
const DState = struct { s: StateSet, next: nexts };
const DStateCache = std.AutoHashMap(StateSet, DState);

fn make_dfa(a: Allocator, s: StateSet) DState {
    var n = nexts.init(a);
    return .{ .s = s, .next = n };
}

test "make dfa test" {
    var t = testing.allocator;
    var s = StateSet.init(t);
    var d = make_dfa(t, s);
    defer d.next.deinit();
    defer s.deinit();
    try expect(d.s.count() == 0);
}

//This fn should take the initial nfa as input
fn match(a: Allocator, n: *NFA, string: []u8) !bool {
    var i: usize = 0;
    var initial_state = n.*.initial;
    var accept_state = n.*.accept;
    var global_cache = DStateCache.init(a);
    var initial_state_set = StateSet.init(a);
    try m.follows(initial_state, &initial_state_set);
    var initial_dstate = DState{ .s = initial_state_set, .next = nexts.init(a) };
    try global_cache.put(initial_state_set, initial_dstate);
    var cur_dstate = initial_dstate;
    while (i < string.len) : (i += 1) {
        var c = string[i];
        if (cur_dstate.next.contains(c)) {
            cur_dstate = cur_dstate.next.get(c).?;
        } else {
            var next = StateSet.init(a);
            try step(&cur_dstate.s, c, &next);
            var next_dstate = try make_next_dfa_state(a, &global_cache, next);
            try cur_dstate.next.put(c, next_dstate);
            cur_dstate = next_dstate;
        }
    }
    return cur_dstate.s.contains(accept_state);
}

fn step(s: *StateSet, c: u8, n: *StateSet) !void {
    var statesIter = s.keyIterator();
    while (statesIter.next()) |key| {
        if (key.*.label) |l| {
            if (l == c and key.*.out != null) {
                try m.follows(key.*.out.?, n);
            }
        }
    }
}
fn make_next_dfa_state(a: Allocator, cache: *DStateCache, s: StateSet) !DState {
    if (cache.contains(s)) {
        return cache.get(s).?;
    }
    //TODO: Turn this into a allocator alloc'ed
    //structure
    //actually no need to do this. DState returned as param
    //is copied, so no problem
    var new_dstate = DState{ .s = s, .next = nexts.init(a) };
    try cache.put(s, new_dstate);
    return new_dstate;
}

test "dfa test" {
    var t = testing.allocator;
    var arena = std.heap.ArenaAllocator.init(t);
    defer arena.deinit();
    var h = arena.allocator();

    var infix = "ab+".*;
    var postfix = try m.to_postfix(h, &infix);
    var nfa = try m.compile(h, postfix);
    var string = "abbbbbb".*;
    var matched = try match(h, &nfa, &string);
    try expect(matched == true);
    var string2 = "acccc".*;
    matched = try match(h, &nfa, &string2);
    try expect(matched == false);
}

test "more complicated dfa tests" {
    var t = testing.allocator;
    var arena = std.heap.ArenaAllocator.init(t);
    defer arena.deinit();
    var h = arena.allocator();

    var infix = "a(b|c)+".*;
    var postfix = try m.to_postfix(h, &infix);
    var nfa = try m.compile(h, postfix);
    var string = "abbbbbbcccbb".*;
    var matched = try match(h, &nfa, &string);
    try expect(matched == true);
    var string2 = "zbbbbbbccbb".*;
    matched = try match(h, &nfa, &string2);
    try expect(matched == false);
}
