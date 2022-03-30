const std = @import("std");
const Allocator = std.mem.Allocator;

fn prefixArray(alloc: std.mem.Allocator, pattern: []const u8) ![]const i32 {
    var max_prefix_len = try alloc.alignedAlloc(i32, null, pattern.len);
    std.mem.set(i32, max_prefix_len, 0);
    // of pattern
    var i: i32 = 1;
    while (i < pattern.len) : (i += 1) {
        // can the border of p[0..i-1] be extended by p[i] ?
        // For this to happen, char after border(p[0..i-1]) must be == p[i]
        // let j = border(p[0..i-1]). => Next char of border(p[0..i-1]) == p[j]
        // we check then if p[j] = p[i]
        // if not, we recursively loop by setting j = p[j] until j >=0 till j goes < 0
        // or p[j] == p[i]
        var j: i32 = max_prefix_len[@intCast(usize, i) - 1];
        while (j > 0 and pattern[@intCast(usize, i)] != pattern[@intCast(usize, j)]) {
            if (j - 1 >= 0) {
                j = max_prefix_len[@intCast(usize, j) - 1];
            } else j -= 1;
        }
        j += 1;
        max_prefix_len[@intCast(usize, i)] = j;
    }

    return max_prefix_len;
}

pub fn main() !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    var allocator = arena.allocator();
    defer arena.deinit();
    var pattern: []const u8 = "abcabc";
    var preCompute = try prefixArray(allocator, pattern);
    std.debug.print("precompute array of {s} is {d}\n", .{ pattern, preCompute });
    var text: []const u8 = "abcabd acbaet abcabc deadbeef abcabc";
    search(text, pattern, preCompute);
    pattern = "aaaaa";
    preCompute = try prefixArray(allocator, pattern);
    std.debug.print("precompute array of {s} is {d}\n", .{ pattern, preCompute });
    pattern = "ababab";
    preCompute = try prefixArray(allocator, pattern);
    std.debug.print("precompute array of {s} is {d}\n", .{ pattern, preCompute });
    pattern = "abacabab";
    preCompute = try prefixArray(allocator, pattern);
    std.debug.print("precompute array of {s} is {d}\n", .{ pattern, preCompute });
    pattern = "aaabaaaaab";
    preCompute = try prefixArray(allocator, pattern);
    std.debug.print("precompute array of {s} is {d}\n", .{ pattern, preCompute });
    pattern = "deadbutter";
    preCompute = try prefixArray(allocator, pattern);
    std.debug.print("precompute array of {s} is {d}\n", .{ pattern, preCompute });
    text = "deadap deadbutter";
    search(text, pattern, preCompute);
}

fn search(text: []const u8, pattern: []const u8, lsp: []const i32) void {
    var j: i32 = 0; // Number of chars matched in pattern
    var i: usize = 0;
    while (i < text.len) : (i += 1) {
        while (j > 0 and text[i] != pattern[@intCast(usize, j)]) {
            // Fall back in the pattern
            j = lsp[@intCast(usize, j) - 1]; // Strictly decreasing
        }
        if (text[i] == pattern[@intCast(usize, j)]) {
            // Next char matched, increment position
            j += 1;
            if (j == pattern.len) {
                var k = @intCast(usize, j) - 1;
                std.debug.print("found from {}", .{i - k});
                std.debug.print(": {s}\n", .{text[i - k .. i - k + pattern.len]});
                j = lsp[@intCast(usize, j) - 1];
            }
            // Key Insight: When we finish matching the entire pattern
            // we do start matching from the first character.
            // Instead, we shift the length of the largest `border` of the pattern
            // and start matching again from that, rather than j = 0
        }
    }

    // return -1;  // Not found
}
