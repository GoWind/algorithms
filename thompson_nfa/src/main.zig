const std = @import("std");
const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayList;
const heap = std.heap;
const expect = std.testing.expect;
const testing = std.testing;

const State = struct { c: u8, out: ?*State, out1: ?*State, lastlist: i32 };

const StateEnum = enum { Match, Split };
const ReErrors = error{
    InvalidRe,
};

const Frag = struct { start: *State, out: *PtrList };
const PtrType = enum { Next, State };
const PtrList = ArrayList(State);

const ParenState = struct { nalt: u32, natom: u32 };
// We assume that buf has enough capacity to store postfix
// representation of re
fn re2post(re: []const u8, buf: []u8, parens_l: *ArrayList(ParenState)) !void {
    var parens = parens_l.*;
    var i: u32 = 0;
    var bufi: u32 = 0;
    var natom: u32 = 0;
    var nalt: u32 = 0;
    // var parenList = ArrayList(ParenState)
    while (i < re.len) : (i += 1) {
        switch (re[i]) {
            '(' => {
                if (natom > 1) {
                    natom -= 1;
                    buf[bufi] = '.';
                    bufi += 1;
                }
                const p = ParenState{ .nalt = nalt, .natom = natom };
                try parens.append(p);
                nalt = 0;
                natom = 0;
            },
            ')' => {
                if (parens.items.len == 0) {
                    return ReErrors.InvalidRe;
                }
                if (natom == 0) {
                    return ReErrors.InvalidRe;
                }
                natom -= 1;
                while (natom > 0) : (natom -= 1) {
                    buf[bufi] = '.';
                    bufi += 1;
                }
                while (nalt > 0) : (nalt -= 1) {
                    buf[bufi] = '|';
                    bufi += 1;
                }
                const p = parens.items[parens.items.len - 1];
                // The corresponding `(` handler, sets nalt and natom to 0 when it see a new group. We are restoring the state prior to seeing the new group
                _ = parens.pop();
                nalt = p.nalt;
                natom = p.natom;
                natom += 1; // why ?
            },
            '|' => {
                if (natom == 0) {
                    return ReErrors.InvalidRe;
                }
                natom -= 1;
                while (natom > 0) : (natom -= 1) {
                    buf[bufi] = '.';
                    bufi += 1;
                }
                nalt += 1;
            },
            '*', '+', '?' => {
                if (natom == 0) {
                    return ReErrors.InvalidRe;
                }
                buf[bufi] = re[i];
                bufi += 1;
            },
            else => {
                if (natom > 1) {
                    natom -= 1;
                    buf[bufi] = '.';
                    bufi += 1;
                }
                buf[bufi] = re[i];
                natom += 1;
                bufi += 1;
            },
        }
    }
    if (parens.items.len != 0) {
        return ReErrors.InvalidRe;
    }
    while (natom > 0) : (natom -= 1) {
        buf[bufi] = '.';
    }
    while (nalt > 0) : (nalt -= 1) {
        buf[bufi] = '|';
    }
}

// fn make_state(a: Allocator, c: u8, out: ?*State, out1: ?*State) !*State {
//     var s = try a.create(State);
//     s.c = c;
//     s.out = out;
//     s.out1 = out1;
//     return s;
// }

fn frag(start: *State, out: *PtrList) Frag {
    var v = Frag{ .start = start, .out = out };
    return v;
}

fn list1(s: State, a: Allocator) !PtrList {
    var p = PtrList.init(a);
    try p.append(s);
    return p;
}

fn append(a: Allocator, p: *PtrList, q: *PtrList) !PtrList {
    var r = PtrList.init(a);
    var p_items = p.toOwnedSlice();
    var q_items = q.toOwnedSlice();
    try r.ensureTotalCapacity(q_items.len + p_items.len);
    r.appendSliceAssumeCapacity(p_items);
    r.appendSliceAssumeCapacity(q_items);
    return r;
}

test "list1 test " {
    var t = testing.allocator;
    var s = State{ .c = 34, .out = null, .out1 = null, .lastlist = 400 };
    var p = try list1(s, t);
    defer p.deinit();
    try expect(p.items[0].c == s.c);
}

test "append" {
    var t = testing.allocator;
    var s = State{ .c = 34, .out = null, .out1 = null, .lastlist = 400 };
    var paq = try list1(s, t);
    std.debug.print("p len is {} and capacity is {}\n", .{ paq.items.len, paq.capacity });
    try expect(paq.items[0].c == s.c);
    var sa = State{ .c = 34, .out = null, .out1 = null, .lastlist = 400 };
    var q = try list1(sa, t);
    std.debug.print("q len is {} and capacity is {}\n", .{ q.items.len, q.capacity });
    var r = try append(t, &paq, &q);
    defer r.deinit();
    try expect(r.items[0].c == s.c);
    try expect(r.items[1].c == sa.c);
    std.debug.print("\n\n\n Tests are done\n\n\n", .{});
}

pub fn main() anyerror!void {
    var a = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    var arena = a.allocator();
    const regex = "ab*cde(g|h)+";
    const postFix = try arena.alignedAlloc(u8, null, 2 * regex.len);
    //TODO: Begin tomorrow from here
    var groupsList = ArrayList(ParenState).init(arena);
    try re2post(regex, postFix, &groupsList);
    std.debug.print("postFix regex is {s}\n", .{postFix});
}
