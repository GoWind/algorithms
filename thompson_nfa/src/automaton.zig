const std = @import("std");
const fmt = std.fmt;
const debug = std.debug;
const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayList;
const heap = std.heap;
const expect = std.testing.expect;
const testing = std.testing;

pub const State = struct { label: ?u8 = null, out: ?*State = null, out1: ?*State = null, state_num: u32 = 0 };
pub const NFA = struct { initial: *State, accept: *State };
pub const NFAList = ArrayList(NFA);
pub const StateSet = std.AutoHashMap(*State, bool);

const MyError = error{MyErr};

const Err = error{ShuntErr};

fn is_special_label(c: u8) bool {
    switch (c) {
        '+', ' ', '|', '?', '*', '@' => {
            return true;
        },
        else => {
            return false;
        },
    }
}

fn shunt(a: Allocator, infix: []const u8, postfix: []u8) !usize {
    const shunt_state = struct { nalt: usize = 0, natom: usize = 0 };
    var shunt_stack = ArrayList(shunt_state).init(a);
    var ii: usize = 0; //index into infix
    var pi: usize = 0; //index into postfix
    var natom: usize = 0;
    var nalt: usize = 0;
    while (ii < infix.len) : (ii += 1) {
        var char = infix[ii];
        switch (char) {
            '(' => {
                if (natom > 1) {
                    natom -= 1;
                    postfix[pi] = '.';
                    pi += 1;
                }
                try shunt_stack.append(shunt_state{ .natom = natom, .nalt = nalt });
                nalt = 0;
                natom = 0;
            },
            '|' => {
                if (natom == 0) {
                    return Err.ShuntErr;
                }
                natom -= 1;
                while (natom > 0) : (natom -= 1) {
                    postfix[pi] = '.';
                    pi += 1;
                }
                nalt += 1;
            },
            ')' => {
                if (shunt_stack.items.len == 0) {
                    return Err.ShuntErr;
                }
                if (natom == 0) {
                    return Err.ShuntErr;
                }
                natom -= 1;
                while (natom > 0) : (natom -= 1) {
                    postfix[pi] = '.';
                    pi += 1;
                }
                while (nalt > 0) : (nalt -= 1) {
                    postfix[pi] = '|';
                    pi += 1;
                }
                var restore_stack = shunt_stack.pop();
                nalt = restore_stack.nalt;
                natom = restore_stack.natom;
                natom += 1;
            },
            '*', '+', '?' => {
                if (natom == 0) {
                    return Err.ShuntErr;
                }
                //TODO: Test what happens when we have something
                //like a++
                postfix[pi] = char;
                pi += 1;
            },
            else => {
                if (natom > 1) {
                    natom -= 1;
                    postfix[pi] = '.';
                    pi += 1;
                }
                postfix[pi] = char;
                pi += 1;
                natom += 1;
            },
        }
    }
    if (shunt_stack.items.len != 0) {
        return Err.ShuntErr;
    }
    if (natom > 0) {
        natom -= 1;
        while (natom > 0) : (natom -= 1) {
            postfix[pi] = '.';
            pi += 1;
        }
    }
    if (nalt > 0) {
        nalt -= 1;
        while (nalt > 0) : (nalt -= 1) {
            postfix[pi] = '|';
            pi += 1;
        }
    }
    shunt_stack.deinit();
    return pi;
}

test "proper_shunt test " {
    var t = testing.allocator;
    var infix = "ab+cd".*;
    var postfix = try t.alloc(u8, 2 * infix.len);
    defer t.free(postfix);
    _ = try shunt(t, &infix, postfix);
    try expect(std.mem.eql(u8, postfix[0..8], "ab+.c.d."));
    var infix2 = "ab+c*(e|d)?f".*;
    var postfix2 = try t.alloc(u8, 2 * infix2.len);
    defer t.free(postfix2);
    _ = try shunt(t, &infix2, postfix2);
    debug.print("postfix2 {s}\n", .{postfix2});
    try expect(std.mem.eql(u8, postfix2[0..14], "ab+.c*.ed|?.f."));
}

pub fn compile_nfa(a: Allocator, infix: []const u8) !NFA {
    var postfix = try a.alloc(u8, 2 * infix.len);
    defer a.free(postfix);
    var postfixlen = try shunt(a, infix, postfix);
    postfix = a.resize(postfix, postfixlen) orelse return Err.ShuntErr;
    var nfa = compile(a, postfix) catch @panic("failed to compile NFA");
    return nfa;
}

fn compile(a: Allocator, postfix: []const u8) !NFA {
    var nfaStack = NFAList.init(a);
    var i: usize = 0;
    var node_counter: u32 = 0;
    while (i < postfix.len) : (i += 1) {
        const c = postfix[i];
        switch (c) {
            '*' => {
                var nfa1 = nfaStack.pop();
                var initial = try create_state(a, &node_counter, '*');
                var accept = try create_state(a, &node_counter, ' ');
                initial.out = nfa1.initial;
                initial.out1 = accept;
                // point back to initial state to match more chars
                nfa1.accept.out = nfa1.initial;
                // point to the accept state on empty string
                nfa1.accept.out1 = accept;
                try nfaStack.append(NFA{ .initial = initial, .accept = accept });
            },
            '.' => {
                var e2 = nfaStack.pop();
                var e1 = nfaStack.pop();
                e1.accept.out = e2.initial;
                try nfaStack.append(NFA{ .initial = e1.initial, .accept = e2.accept });
            },
            '|' => {
                var e2 = nfaStack.pop();
                var e1 = nfaStack.pop();
                var initial = try create_state(a, &node_counter, '|');
                initial.out = e1.initial;
                initial.out1 = e2.initial;
                var accept = try create_state(a, &node_counter, ' ');
                e1.accept.out = accept;
                e2.accept.out = accept;
                try nfaStack.append(NFA{ .initial = initial, .accept = accept });
            },
            '+' => {
                var e1 = nfaStack.pop();
                var initial = try create_state(a, &node_counter, '+');
                var accept = try create_state(a, &node_counter, '@');

                initial.out = e1.initial;
                e1.accept.out = e1.initial;
                e1.accept.out1 = accept;
                try nfaStack.append(NFA{ .initial = initial, .accept = accept });
            },
            '?' => {
                var e1 = nfaStack.pop();
                var initial = try create_state(a, &node_counter, '?');
                var accept = try create_state(a, &node_counter, ' ');
                initial.out = e1.initial;
                initial.out1 = accept;
                e1.accept.out = accept;
                try nfaStack.append(NFA{ .initial = initial, .accept = accept });
            },
            else => {
                var initial = try create_state(a, &node_counter, c);
                var accept = try create_state(a, &node_counter, ' ');
                initial.out = accept;
                try nfaStack.append(NFA{ .initial = initial, .accept = accept });
            },
        }
    }
    debug.assert(nfaStack.items.len == 1);
    return nfaStack.pop();
}

fn create_state(a: Allocator, node_counter: *u32, label: u8) !*State {
    var s = try a.create(State);
    node_counter.* += 1;
    s.out = null;
    s.out1 = null;
    s.label = label;
    s.state_num = node_counter.*;
    return s;
}

// This is equivalent to the addstate fn
pub fn follows(state: *State, state_set: *StateSet) MyError!void {
    _ = state_set.put(state, true) catch return MyError.MyErr;
    if (state.label == null or (is_special_label(state.label.?) == true)) {
        if (state.out != null) {
            try follows(state.out.?, state_set);
        }
        if (state.out1 != null) {
            try follows(state.out1.?, state_set);
        }
    }
    return;
}

test "follows test" {
    var s = State{ .label = null, .out = null, .out1 = null };
    var t = State{ .label = 'a', .out = null, .out1 = null };
    var u = State{ .label = 'b', .out = null, .out1 = null };
    s.out = &t;
    s.out1 = &u;
    var alloc = testing.allocator;
    var hm = StateSet.init(alloc);
    defer hm.deinit();
    try follows(&s, &hm);
    try expect(hm.contains(&t) == true);
    try expect(hm.contains(&u) == true);
}

test "compile fn test" {
    var buffer: [4096]u8 = undefined;
    var t = std.heap.FixedBufferAllocator.init(&buffer).allocator();
    var nfa = compile(t, "ab.c.") catch @panic("failed to compile NFA");
    try expect(nfa.initial.label.? == 'a');
}

pub fn to_postfix(a: Allocator, infix: []u8) ![]u8 {
    var postfix = try a.alloc(u8, 2 * infix.len);
    var postfixlen = try shunt(a, infix, postfix);
    postfix = a.resize(postfix, postfixlen) orelse return Err.ShuntErr;
    return postfix;
}

pub fn match(a: Allocator, infix: []const u8, input: []const u8) !bool {
    var currents = StateSet.init(a);
    var nexts = StateSet.init(a);
    // Next 4 lines is a duplicate of the
    // to_postfix fn (except the defer)
    var postfix = try a.alloc(u8, 2 * infix.len);
    defer a.free(postfix);
    var postfixlen = try shunt(a, infix, postfix);
    postfix = a.resize(postfix, postfixlen) orelse return Err.ShuntErr;
    var nfa = compile(a, postfix) catch @panic("failed to compile NFA");
    // **ALGO STARTS HERE**
    // Add initial state to current
    // this is equivalent to startnfa
    //
    try follows(nfa.initial, &currents);
    var ii: usize = 0;
    while (ii < input.len) : (ii += 1) {
        var c = input[ii];
        var c_iterator = currents.keyIterator();
        while (c_iterator.next()) |key| {
            if (key.*.label) |l| {
                if (l == c and key.*.out != null) {
                    follows(key.*.out.?, &nexts) catch @panic("kaboom");
                }
            }
        }
        var temp_currents = currents;
        currents = nexts;
        nexts = StateSet.init(a);
        temp_currents.deinit();
    }
    defer nexts.deinit();
    return currents.contains(nfa.accept);
}
test "match test" {
    var t = testing.allocator;
    var arena = std.heap.ArenaAllocator.init(t);
    defer arena.deinit();
    var h = arena.allocator();
    var infix = "ab+".*;
    var input = "abbb".*;
    var matched = try match(h, &infix, &input);
    try expect(matched == true);
    var infix2 = "a(c|d)+".*;
    var input2 = "acd".*;
    matched = try match(h, &infix2, &input2);
    try expect(matched == true);
}

//return a string representing the dotviz
//representation of the NFA
pub fn printNFA(a: Allocator, n: NFA) ![]u8 {
    var seen_set = StateSet.init(a);
    defer seen_set.clearAndFree();
    var state_queue = ArrayList(*State).init(a);
    var nfa_string = try fmt.allocPrint(a, "digraph G {{ rankdir=LR; \n", .{});
    var initial = n.initial;
    try state_queue.append(initial);
    while (state_queue.items.len > 0) {
        var item = state_queue.items[0];
        if (seen_set.contains(item) == false) {
            var split: u8 = item.label orelse '-';
            nfa_string = try fmt.allocPrint(a, "{s} \n {d} [label=\"{c}\"]", .{ nfa_string, item.state_num, split });
            if (item.out != null) {
                try state_queue.append(item.out.?);
                nfa_string = try fmt.allocPrintZ(a, "{s} \n {d} -> {d}", .{ nfa_string, item.state_num, item.out.?.state_num });
            }
            if (item.out1 != null) {
                try state_queue.append(item.out1.?);
                nfa_string = try fmt.allocPrintZ(a, "{s} \n {d} -> {d}", .{ nfa_string, item.state_num, item.out1.?.state_num });
            }
            try seen_set.put(item, true);
        }
        _ = state_queue.orderedRemove(0);
    }
    nfa_string = try fmt.allocPrint(a, "{s} \n {d} [shape=polygon,sides=5,peripheries=3]", .{ nfa_string, n.accept.state_num });
    nfa_string = try fmt.allocPrint(a, "{s} }}", .{nfa_string});
    return nfa_string;
}

// test "printNFA test" {
//     var t = std.testing.allocator;
//     var arena = std.heap.ArenaAllocator.init(t);
//     defer arena.deinit();
//     var h = arena.allocator();
//     var c = State{ .label = 'c', .out = null, .out1 = null };
//     var b = State{ .label = 'b', .out = null, .out1 = null };
//     var a = State{ .label = 'a', .out = &b, .out1 = &c };
//     var nfa = NFA{ .initial = &a, .accept = &c };
//     var nfa_string = try printNFA(h, nfa);
//     var expected_nfa = "digraph G { \n a -> b \n a -> c }".*;
//     try std.testing.expectEqualStrings(nfa_string, &expected_nfa);
// }
