const std = @import("std");
const Allocator = std.mem.Allocator;
const AvlNode = struct {
    key: i32 = -1,
    value: u32 = 1,
    height: usize = 0,
    cnt: usize = 0,
    left: ?*AvlNode = null,
    right: ?*AvlNode = null,
    const Self = @This();
    pub fn new(alloc: Allocator) !*Self {
        var newNode = try alloc.create(Self);
        newNode.* = AvlNode{};
        return newNode;
    }

    pub fn withKV(alloc: Allocator, key: i32, val: u32) !*Self {
        var new_n = try Self.new(alloc);
        new_n.key = key;
        new_n.value = val;
        return new_n;
    }
    pub fn Height(node: ?*Self) usize {
        if (node) |n| {
            return n.height;
        }
        return 0;
    }
    fn Cnt(node: ?*Self) usize {
        if (node) |n| {
            return n.cnt;
        }
        return 0;
    }

    fn update(node: *Self) void {
        node.height = 1 + std.math.max(Self.Height(node.left), Self.Height(node.right));
        node.cnt = 1 + Self.Cnt(node.left) + Self.Cnt(node.right);
    }

    fn rotateLeft(node: *AvlNode) *AvlNode {
        // node.right will be new_node
        // node will be new_node.left
        // if new_node had a former left , it will become
        // node.right
        var new_node = node.right.?;
        node.right = new_node.left; // node.right is either valid node or null, don't care
        new_node.left = node;
        Self.update(node); // Since we update children of nodes, height might change
        Self.update(new_node); // so once we rejig the node, update their heights
        return new_node;
    }

    fn rotateRight(node: *AvlNode) *AvlNode {
        //node.left will be new_node
        // r is new_node.right
        // r will be node.left

        var new_node = node.left.?;
        node.left = new_node.right;
        new_node.right = node;
        Self.update(node);
        Self.update(new_node);
        return new_node;
    }

    pub fn balanceFactor(node: ?*Self) i32 {
        if (node) |n| {
            var left_height = Self.Height(n.left);
            var right_height = Self.Height(n.right);
            // usize cannot be < 0
            if (right_height > left_height) {
                var diff = right_height - left_height;
                return -1 * @intCast(i32, diff);
            } else {
                return @intCast(i32, left_height - right_height);
            }
        } else {
            return 0;
        }
    }

    pub fn insert(self: ?*Self, child: *AvlNode) *AvlNode {
        if (self == null) {
            return child;
        }
        var cur = self.?;
        if (child.key == cur.key) {
            cur.value = child.value;
            return cur;
        }
        if (child.key < cur.key) {
            cur.left = Self.insert(cur.left, child);
        } else {
            cur.right = Self.insert(cur.right, child);
        }
        cur.height = 1 + std.math.max(Self.Height(cur.left), Self.Height(cur.right));

        var balance = Self.balanceFactor(cur);
        if (balance == -1 or balance == 0 or balance == 1) {
            return cur;
        }
        var new_root: *AvlNode = undefined;
        if (balance > 1 and child.key < cur.left.?.key) {
            new_root = cur.rotateRight();
        } else if (balance > 1 and child.key > cur.left.?.key) {
            cur.left = Self.rotateLeft(cur.left.?);
            new_root = cur.rotateRight();
        } else if (balance < -1 and child.key > cur.right.?.key) {
            new_root = cur.rotateLeft();
        } else if (balance < -1 and child.key < cur.right.?.key) {
            cur.right = Self.rotateRight(cur.right.?);
            new_root = cur.rotateLeft();
        }

        return new_root;
    }

    pub fn delete(self: ?*Self, alloc: Allocator, key: i32) ?*AvlNode {
        if (self == null) {
            return null;
        }
        var node = self.?;
        if (key < node.key) {
            node.left = Self.delete(node.left, alloc, key);
        } else if (key > node.key) {
            node.right = Self.delete(node.right, alloc, key);
        } else {
            if (node.left == null) {
                var tmp = node.right;
                alloc.destroy(node);
                return tmp;
            } else if (node.right == null) {
                var tmp = node.left;
                alloc.destroy(node);
                return tmp;
            } else {
                var tmp = Self.getMinValNode(node.right.?);
                node.key = tmp.key;
                node.value = tmp.value;
                node.right = Self.delete(node.right, alloc, tmp.key);
            }
        }
        if (self == null) {
            return null;
        } // why this check again ?

        node.height = 1 + std.math.max(Self.Height(node.left), Self.Height(node.right));
        var balance = Self.balanceFactor(self);
        if (balance > 1 and Self.balanceFactor(node.left) >= 0) {
            return Self.rotateRight(node);
        }
        if (balance > 1 and Self.balanceFactor(node.left) < 0) {
            node.left = Self.rotateLeft(node.left.?);
            return node.rotateRight();
        }

        if (balance < -1 and Self.balanceFactor(node.right) <= 0) {
            return Self.rotateLeft(node);
        }

        if (balance < -1 and Self.balanceFactor(node.right) > 0) {
            node.right = Self.rotateRight(node.right.?);
            return node.rotateLeft();
        }
        return node;
    }

    pub fn getMinValNode(node: *AvlNode) *AvlNode {
        if (node.left == null) {
            return node;
        }
        return getMinValNode(node.left.?);
    }
    pub fn check(node: *AvlNode) void {
        var balance = Self.balanceFactor(node);
        if (balance > 1 or balance < -1) {
            std.debug.print("unbalanced tree at key {}\n", .{node.key});
            @panic("unbalanced");
        }
        if (node.left) |l| {
            if (l.key >= node.key) {
                std.debug.print("violation: left >= node {} :: {}\n", .{ l.key, node.key });
            }
            Self.check(node.left.?);
        }
        if (node.right) |r| {
            if (r.key <= node.key) {
                std.debug.print("violation: right <= node {} :: {}\n", .{ r.key, node.key });
            }
            Self.check(node.right.?);
        }
    }

    pub fn search(self: *Self, key: i32) ?u32 {
        if (self.key == key) {
            return self.value;
        }
        if (key < self.key) {
            if (self.left) |l| {
                return Self.search(l, key);
            }
            return null;
        } else if (key > self.key) {
            if (self.right) |r| {
                return Self.search(r, key);
            }
            return null;
        }
        // most probably redundant , but still lets put it there
        return null;
    }
};

const AvlTree = struct {
    root: ?*AvlNode = null,
    const Self = @This();
    pub fn insert(self: *Self, alloc: Allocator, key: i32, val: u32) !void {
        var new_node = try AvlNode.withKV(alloc, key, val);
        self.root = AvlNode.insert(self.root, new_node);
    }
    pub fn delete(self: *Self, alloc: Allocator, key: i32) void {
        self.root = AvlNode.delete(self.root, alloc, key);
    }

    pub fn search(self: *Self, key: i32) ?u32 {
        if (self.root == null) {
            return null;
        }

        return self.root.?.search(key);
    }
};

pub fn main() !void {
    // Prints to stderr (it's a shortcut based on `std.io.getStdErr()`)
    std.debug.print("All your {s} are belong to us.\n", .{"codebase"});
    var arena = std.heap.ArenaAllocator.init(std.heap.c_allocator);
    defer arena.deinit();
    var allocator = arena.allocator();
    var tree = AvlTree{};
    var prng = std.rand.DefaultPrng.init(0);
    prng.seed(100);
    const random = prng.random();
    var i: usize = 0;
    var keysList = std.ArrayList(i32).init(allocator);

    while (i < 100) : (i += 1) {
        var key: i32 = random.int(i32);
        var value: u32 = random.uintAtMost(u32, 350000);
        try tree.insert(allocator, key, value);
        tree.root.?.check();
        try keysList.append(key);
    }
    for (keysList.items) |k| {
        var v = tree.search(k);
        std.debug.assert(v != null);
        std.debug.print("deleting key {}\n", .{k});
        tree.delete(allocator, k);
        if (tree.root != null) {
            tree.root.?.check();
        }
    }
    std.debug.assert(tree.root == null);
}

test "simple test" {}
