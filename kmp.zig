const std = @import("std");

// Return an array of border lengths where each element i
// holds the length of the longest border of str[0..i]
// A border is the longer *proper* suffix of str[0..i]
// that is also a *proper* prefix of str[0..i]
fn borderArray(pattern: []const u8, allocator: std.mem.Allocator) ![]usize {
    var border_array = try allocator.alloc(usize, pattern.len);
    var i: usize = 1;
    var len: usize = 0; // holds the length of the current border under consideration
    border_array[0] = 0; // No valid border for a single character
    while (i < pattern.len) {
        //pattern[0..len-1] is our current border
        //we try to see if we can extend our border by one character
        //to do this, we check if pattern[i] == pattern[len]
        //if yes, we increment len and i
        //if not, we find the border of the current border until len == 0
        //or the next char after the boder == pattern[i]
        if (pattern[len] == pattern[i]) {
            len += 1; //current border is from 0..len-1 (=> length n). We are extending
            //it by one
            border_array[i] = len;
            i += 1;
        } else {
            if (len != 0) {
                len = border_array[len - 1];
            } else {
                border_array[i] = 0;
                len = 0;
                i += 1;
            }
        }
    }
    return border_array;
}

fn kmpSearch(allocator: std.mem.Allocator, str: []const u8, pattern: []const u8) !void {
    const border_array = try borderArray(pattern, allocator);
    var i: usize = 0;
    var j: usize = 0;
    while (i < str.len) {
        if (str[i] == pattern[j]) {
            j += 1;
            i += 1;

            if (j == pattern.len) {
                std.debug.print("Found pattern starting at pos {}\n", .{i - j});
                j = border_array[j - 1];
            }
        } else {
            if (j != 0) {
                j = border_array[j - 1];
            } else {
                i += 1;
            }
        }
    }
}

pub fn main() !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    var allocator = arena.allocator();
    const pattern = "AAAB";
    const missing_pattern = "badaboom";
    const string = "AAAB AAB AA BB AAAAAAB";
    try kmpSearch(allocator, string, pattern);
    try kmpSearch(allocator, string, missing_pattern);
}
