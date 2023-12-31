const std = @import("std");
const Allocator = std.mem.Allocator;

pub fn AvlNode(comptime K: type, comptime V: type) type {
    return struct {
        const Self = @This();

        key: K,
        value: V,
        height: usize = 0,
        cnt: usize = 0,
        left: ?*Self = null,
        right: ?*Self = null,
        pub fn new(alloc: Allocator) !*Self {
            var newNode = try alloc.create(Self);
            return newNode;
        }

        pub fn withKV(alloc: Allocator, key: K, val: V) !*Self {
            var new_n = try Self.new(alloc);
            new_n.* = Self{ .key = key, .value = val };
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
            node.height = 1 + @max(Self.Height(node.left), Self.Height(node.right));
            node.cnt = 1 + Self.Cnt(node.left) + Self.Cnt(node.right);
        }

        fn rotateLeft(node: *Self) *Self {
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

        fn rotateRight(node: *Self) *Self {
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
                    return -1 * @as(i32, @intCast(diff));
                } else {
                    return @as(i32, @intCast(left_height - right_height));
                }
            } else {
                return 0;
            }
        }

        pub fn insert(self: ?*Self, child: *Self) *Self {
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
            cur.height = 1 + @max(Self.Height(cur.left), Self.Height(cur.right));

            var balance = Self.balanceFactor(cur);
            if (balance == -1 or balance == 0 or balance == 1) {
                return cur;
            }
            var new_root: *Self = undefined;
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

        pub fn delete(self: ?*Self, alloc: Allocator, key: K) ?*Self {
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
            // This section is reached, if the deleted node is a child leaf/node of the current node
            // we check that all the nodes from the deleted leaf/node -> root are balanced and if not, rebalance
            node.height = 1 + @max(Self.Height(node.left), Self.Height(node.right));
            var balance = Self.balanceFactor(self);
            // Left Left
            if (balance > 1 and Self.balanceFactor(node.left) >= 0) {
                return Self.rotateRight(node);
            }
            // Left right
            if (balance > 1 and Self.balanceFactor(node.left) < 0) {
                node.left = Self.rotateLeft(node.left.?);
                return node.rotateRight();
            }
            // Right Right
            if (balance < -1 and Self.balanceFactor(node.right) <= 0) {
                return Self.rotateLeft(node);
            }
            // Right Left
            if (balance < -1 and Self.balanceFactor(node.right) > 0) {
                node.right = Self.rotateRight(node.right.?);
                return node.rotateLeft();
            }
            return node;
        }

        pub fn getMinValNode(node: *Self) *Self {
            if (node.left == null) {
                return node;
            }
            return getMinValNode(node.left.?);
        }
        pub fn check(node: *Self) void {
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

        pub fn search(self: *Self, key: K) ?u32 {
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
}

fn AvlTree(comptime K: type, comptime V: type) type {
    return struct {
        const Self = @This();
        const node_type = AvlNode(K, V);
        root: ?*node_type = null,
        pub fn insert(self: *Self, alloc: Allocator, key: K, val: V) !void {
            var new_node = try node_type.withKV(alloc, key, val);
            self.root = node_type.insert(self.root, new_node);
        }
        pub fn delete(self: *Self, alloc: Allocator, key: K) void {
            self.root = node_type.delete(self.root, alloc, key);
        }

        pub fn search(self: *Self, key: K) ?V {
            if (self.root == null) {
                return null;
            }

            return self.root.?.search(key);
        }
    };
}

pub fn main() !void {
    // Prints to stderr (it's a shortcut based on `std.io.getStdErr()`)
    std.debug.print("All your {s} are belong to us.\n", .{"codebase"});
    var arena = std.heap.ArenaAllocator.init(std.heap.c_allocator);
    defer arena.deinit();
    var allocator = arena.allocator();
    // u32 -> u32
    const utree = AvlTree(u32, u32);
    // i32 key -> f32 value
    const ftree = AvlTree(u32, f32);

    var tree = utree{};
    var fp_tree = ftree{};

    var prng = std.rand.DefaultPrng.init(0);
    prng.seed(100);
    const random = prng.random();
    var i: usize = 0;
    var keysList = std.ArrayList(u32).init(allocator);

    while (i < 100) : (i += 1) {
        var key: u32 = random.int(u32);
        var value: u32 = random.uintAtMost(u32, 350000);
        var fpvalue: f32 = random.float(f32);
        try tree.insert(allocator, key, value);
        try fp_tree.insert(allocator, key, fpvalue);
        tree.root.?.check();
        fp_tree.root.?.check();
        try keysList.append(key);
    }
    for (keysList.items) |k| {
        var v = tree.search(k);
        std.debug.assert(v != null);
        var fp_v = tree.search(k);
        std.debug.assert(fp_v != null);
        tree.delete(allocator, k);
        if (tree.root != null) {
            tree.root.?.check();
        }
    }
    std.debug.assert(tree.root == null);
}

test "simple test" {}
