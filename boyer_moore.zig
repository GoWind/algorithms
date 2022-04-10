const std = @import("std");
const assert = std.debug.assert;
const expect = std.testing.expect;

const StringFinder = struct { pattern: []u8, badCharSkip: [256]u8, goodSuffixSkip: []usize };

fn makeFinder(pat: []const u8) StringFinder {
    const last = pat.len - 1;
    var i: usize = 0;
    var stringFinder = StringFinder{ .pattern = pat, .badCharSkip = [_]u8{0} ** 256, .goodSuffixSkip = ([_]usize{0} ** pat.len)[0..] };

    //Set values for
    while (i < badCharSkip.len - 1) : (i += 1) {
        badCharSkip[i] = pat.len;
    }
    i = 0;
    assert(i == 0);
    while (i < last) : (i += 1) {
        badCharSkip[pat[i]] = last - i;
    }

    // goodSuffixSkip[i] gives the jump (or `shift`) in text T
    // when there is a mismatch matching T[j] to pattern[i]
    // We then start matching T[j+shift] with pattern[pattern.len-1]
    // until all of pattern is matched or another mismatch or we run
    // out of text to match
    // To build this table, we look at 2 conditions.
    // 1. pattern[i+1..] doesn't exist at an index n < i, but
    //    a suffix s of pattern[i+1..] starting at pattern[m] is also a prefix of pattern.
    //    In this case, goodSuffixSkip[i] = len(pattern[i+1..])+m
    // 2. pattern[i+1..] exists starting at an index n < i.
    //    goodSuffixSkip[i] = i+1-n+len(pattern[i-1..])
    //  3. Neither 1 nor 2 holds
    //    Then we use the badCharSkip table (or shift by pat.len)

    i = last;
    // Case 1. This is clever. We use the term `border` (similar to KMP), to denote a suffix , that is also prefix. A
    // We start with i = pattern.len - 1 to 0
    // and keep track of the longest border we have seen so far
    // For each i, we use the largest observed border to create the skip for i
    // start with i == last index and end at 0.
    assert(i == last);
    var largest_border_start = 0;
    while (i >= 0) : (i -= 1) {
        if (i + 1 >= last) {
            continue;
        }
        if (hasPrefix(pat, pattern[i + 1 ..])) {
            largest_border_start = i + 1;
        }
        stringFinder.goodSuffixSkip[i] = largest_border_start + last - i;
    }
    // Case 2. We find pattern[i+1..] at an index n before i.
    i = 0;
    assert(i == 0);
    while (i < last) : (i += 1) {
        var lenSuffix = longestCommonSuffix(pat, 1, i + 1);
        if (pat[i - lenSuffix] != pat[last - lenSuffix]) {
            stringFinder.goodSuffixSkip[last - lenSuffix] = lenSuffix + last - i;
        }
    }
    return stringFinder;
}

fn longestCommonSuffix(pat: []u8, start: usize, end: usize) usize {
    var j: usize = 0;
    while (j < pat.len and (j + start) < end) : (j += 1) {
        if (pat[pat.len - 1 - j] != pat[end - 1 - j]) {
            break;
        }
    }
    return j;
}

// Golang implementation for comparison
// HasPrefix tests whether the string s begins with prefix.
// func HasPrefix(s, prefix string) bool {
// 	return len(s) >= len(prefix) && s[0:len(prefix)] == prefix
// }

//return true if pattern[prefixStart:prefixStart+prefixSize]
//== pattern[0:prefixSize]
fn hasPrefix(pattern: []const u8, prefix: []const u8) bool {
    if (prefix.len > pattern.len) {
        return false;
    }
    return std.mem.eql(u8, pattern[0..prefix.len], prefix);
}

// Golang implementation: HasSuffix tests whether the string s ends with suffix.
// func HasSuffix(s, suffix string) bool {
// 	return len(s) >= len(suffix) && s[len(s)-len(suffix):] == suffix
// }
fn hasSuffix(pattern: []const u8, suffix: []const u8) bool {
    if (suffix.len > pattern.len) {
        return false;
    }
    return std.mem.equal(u8, pattern[pattern.len - suffix.len ..], suffix);
}
pub fn main() void {}
