const std = @import("std");
const Allocator = std.mem.Allocator;
const Order = std.math.Order;
var stdout = std.io.getStdOut().writer();
const perfInstruments = @import("perfLib");

pub fn AvlNode(comptime K: type, comptime V: type) type {
    return struct {
        const Self = @This();
        const SelfList = std.ArrayList(*Self);
        key: K,
        value: V,
        height: usize = 0,
        cnt: usize = 0,
        left: ?*Self = null,
        right: ?*Self = null,
        pub fn new(alloc: Allocator) !*Self {
            const newNode = try alloc.create(Self);
            return newNode;
        }

        pub fn bst_print_dot(maybe_tree: ?*Self, writer: *std.fs.File.Writer) !void {
            try writer.print("digraph BST {{\n", .{});
            try writer.print("    node [fontname=\"Arial\"];\n", .{});
            if (maybe_tree) |tree| {
                try writer.print("\n", .{});

                if (tree.left == null and tree.right == null) {
                    try writer.print("    {};\n", .{tree.key});
                } else {
                    try Self.bst_print_dot_aux(tree, writer);
                }
            }
            try writer.print("}}\n", .{});
        }
        fn bst_print_dot_aux(node: *Self, writer: *std.fs.File.Writer) !void {
            const NodeCounter = struct {
                var node_count: usize = 0;
            };
            if (node.left) |l| {
                try writer.print("    {} -> {};\n", .{ node.key, l.key });
                try Self.bst_print_dot_aux(l, writer);
            } else {
                NodeCounter.node_count += 1;
                try Self.bst_print_dot_null(node, NodeCounter.node_count, writer);
            }
            if (node.right) |r| {
                try writer.print("    {} -> {};\n", .{ node.key, r.key });
                try Self.bst_print_dot_aux(r, writer);
            } else {
                NodeCounter.node_count += 1;
                try Self.bst_print_dot_null(node, NodeCounter.node_count, writer);
            }
        }

        fn bst_print_dot_null(node: *Self, node_count: usize, writer: *std.fs.File.Writer) !void {
            try writer.print("    null{} [shape=point];\n", .{node_count});
            try writer.print("    {} -> null{};\n", .{ node.key, node_count });
        }

        pub fn withKV(alloc: Allocator, key: K, val: V) !*Self {
            const new_n = try Self.new(alloc);
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
                const left_height = Self.Height(n.left);
                const right_height = Self.Height(n.right);
                // usize cannot be < 0
                if (right_height > left_height) {
                    const diff = right_height - left_height;
                    return -1 * @as(i32, @intCast(diff));
                } else {
                    return @as(i32, @intCast(left_height - right_height));
                }
            } else {
                return 0;
            }
        }

        pub fn insert(self: ?*Self, child: *Self) !*Self {
            var buffer: [1000]u8 = undefined;
            var fba = std.heap.FixedBufferAllocator.init(&buffer);
            const allocator = fba.allocator();
            if (self == null) {
                return child;
            }
            var cur = self.?;
            if (child.key == cur.key) {
                cur.value = child.value;
                return cur;
            }
            var traversal_list = SelfList.init(allocator);
            while (1 == 1) {
                if (child.key < cur.key and cur.left != null) {
                    try traversal_list.append(cur);
                    cur = cur.left.?;
                } else if (child.key > cur.key and cur.right != null) {
                    try traversal_list.append(cur);
                    cur = cur.right.?;
                } else {
                    break;
                }
            }
            if (child.key < cur.key) {
                cur.left = child;
            } else if (child.key > cur.key) {
                cur.right = child;
            } else {
                cur.value = child.value;
            }
            //update height of element
            try traversal_list.append(cur);
            var r_idx: usize = 0;
            while (r_idx < traversal_list.items.len) : (r_idx += 1) {
                const idx = traversal_list.items.len - r_idx - 1;
                var elem = traversal_list.items[idx];
                elem.update();
                const balance = Self.balanceFactor(elem);
                if (balance == -1 or balance == 0 or balance == 1) {
                    continue;
                }
                var new_root: *Self = undefined;
                // LL rotation
                if (balance > 1 and child.key < elem.left.?.key) {
                    new_root = elem.rotateRight();
                    // LR rotation
                } else if (balance > 1 and child.key > elem.left.?.key) {
                    elem.left = Self.rotateLeft(elem.left.?);
                    new_root = elem.rotateRight();
                    // RR rotation
                } else if (balance < -1 and child.key > elem.right.?.key) {
                    new_root = elem.rotateLeft();
                    // RL rotation
                } else if (balance < -1 and child.key < elem.right.?.key) {
                    elem.right = Self.rotateRight(elem.right.?);
                    new_root = elem.rotateLeft();
                } else {
                    @panic("should never be here");
                }
                if ((idx > 0) and idx - 1 >= 0) {
                    var prev_elem = traversal_list.items[idx - 1];
                    if (new_root.key > prev_elem.key) {
                        prev_elem.right = new_root;
                        prev_elem.update();
                    } else {
                        prev_elem.left = new_root;
                        prev_elem.update();
                    }
                } else {
                    return new_root;
                }
            }
            return self.?;
        }

        fn balanceNode(elem: *Self) *Self {
            const balance = Self.balanceFactor(elem);
            if (balance == -1 or balance == 0 or balance == 1) {
                return elem;
            }
            var new_root: *Self = undefined;
            // LL rotation
            if (balance > 1 and Self.balanceFactor(elem.left.?) >= 0) {
                new_root = elem.rotateRight();
                // LR rotation
            } else if (balance > 1 and Self.balanceFactor(elem.left.?) < 0) {
                elem.left = Self.rotateLeft(elem.left.?);
                new_root = elem.rotateRight();
                // RR rotation
            } else if (balance < -1 and Self.balanceFactor(elem.right.?) <= 0) {
                new_root = elem.rotateLeft();
                // RL rotation
            } else if (balance < -1 and Self.balanceFactor(elem.right.?) > 0) {
                elem.right = Self.rotateRight(elem.right.?);
                new_root = elem.rotateLeft();
            } else {
                @panic("should never be here");
            }
            return new_root;
        }

        fn move_node(u: *Self, v: ?*Self, maybe_us_parent: ?*Self) void {
            if (maybe_us_parent) |us_parent| {
                if (u == us_parent.left) {
                    us_parent.left = v;
                } else {
                    us_parent.right = v;
                }
            }
        }
        pub fn deleteIter(self: ?*Self, node_alloc: Allocator, key: K) ?*Self {
            if (self == null) {
                return null;
            }
            const root = self;
            // traversal list
            var buffer: [1000]u8 = undefined;
            var fba = std.heap.FixedBufferAllocator.init(&buffer);
            const allocator = fba.allocator();
            var traversal_list = SelfList.init(allocator);
            var cur_node: ?*Self = self;
            while (cur_node != null and cur_node.?.key != key) {
                if (cur_node.?.key > key and cur_node.?.left != null) {
                    traversal_list.append(cur_node.?) catch @panic("allocation error");
                    cur_node = cur_node.?.left;
                } else if (cur_node.?.key < key and cur_node.?.right != null) {
                    traversal_list.append(cur_node.?) catch @panic("allocation error");
                    cur_node = cur_node.?.right;
                } else {
                    break;
                }
            }
            if (cur_node != null and cur_node.?.key != key) {
                return root;
            }

            var n = cur_node.?;
            var maybe_curnode_parent: ?*Self = null;
            if (traversal_list.items.len != 0) {
                maybe_curnode_parent = traversal_list.items[traversal_list.items.len - 1];
            }
            if (n.left == null) {
                move_node(n, n.right, maybe_curnode_parent);
                if (n == root) {
                    return n.right;
                }
            } else if (n.right == null) {
                move_node(n, n.left, maybe_curnode_parent);
                if (n == root) {
                    return n.left;
                }
            } else {
                var min_node_parent = n;
                var min_node = n.right.?;
                traversal_list.append(n) catch @panic("oom when traversing");
                while (min_node.left != null) {
                    traversal_list.append(min_node) catch @panic("oom when traversing");
                    min_node_parent = min_node;
                    min_node = min_node.left.?;
                }
                if (min_node_parent == n) {
                    std.debug.assert(traversal_list.items[traversal_list.items.len - 1] == n);
                    move_node(n, min_node, maybe_curnode_parent);
                    min_node.left = n.left;
                    _ = traversal_list.popOrNull();
                    traversal_list.append(min_node) catch @panic("oom when traversing");
                } else {
                    // set min_node.right to be the child of min_node's parent
                    move_node(min_node, min_node.right, min_node_parent);
                    n.key = min_node.key;
                    n.value = min_node.value;
                    n = min_node;
                }
            }
            var r_idx: usize = 0;
            while (r_idx < traversal_list.items.len) : (r_idx += 1) {
                const idx = traversal_list.items.len - r_idx - 1;
                var last_item = traversal_list.items[idx];
                last_item.update();
                last_item = last_item.balanceNode();
                traversal_list.items[idx] = last_item;
                if (idx > 0) {
                    var prev = traversal_list.items[idx - 1];
                    if (prev.key > last_item.key) {
                        prev.left = last_item;
                    } else {
                        prev.right = last_item;
                    }
                    traversal_list.items[idx - 1] = prev;
                }
            }
            node_alloc.destroy(n);
            return traversal_list.items[0];
        }

        pub fn check(node: *Self) bool {
            const balance = Self.balanceFactor(node);
            if (balance > 1 or balance < -1) {
                std.debug.print("unbalanced {} left {} and right {} keys and balanceFactor {} \n", .{ node.key, node.left.?.key, node.right.?.key, balance });
                return false;
            }
            var left_check = true;
            var right_check = true;
            if (node.left) |l| {
                if (l.key >= node.key) {
                    std.debug.print("violation: left >= node {} :: {}\n", .{ l.key, node.key });
                    return false;
                }
                left_check = Self.check(node.left.?);
            }
            if (node.right) |r| {
                if (r.key <= node.key) {
                    std.debug.print("violation: right <= node {} :: {}\n", .{ r.key, node.key });
                    return false;
                }
                right_check = Self.check(node.right.?);
            }
            return left_check and right_check;
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
            const new_node = try node_type.withKV(alloc, key, val);
            self.root = try node_type.insert(self.root, new_node);
        }
        pub fn delete(self: *Self, alloc: Allocator, key: K) void {
            self.root = node_type.deleteIter(self.root, alloc, key);
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
    var counter1 = [_]u64{0} ** 32;
    var counter2 = [_]u64{0} ** 32;
    var arena = std.heap.ArenaAllocator.init(std.heap.c_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    const events_slice: []const []const u8 = &perfInstruments.m2MacEvents;
    var perfCounters = try perfInstruments.Perf.init(events_slice, allocator);
    defer _ = &perfCounters.deinit();

    // u32 -> u32
    const utree = AvlTree(u32, u32);

    var tree = utree{};

    var prng = std.rand.DefaultPrng.init(0);
    prng.seed(100);
    const random = prng.random();
    var i: usize = 0;
    var keysList = std.ArrayList(u32).init(allocator);

    while (i < 100) : (i += 1) {
        const key: u32 = random.intRangeAtMost(u32, 10, 99999);
        const value: u32 = random.uintAtMost(u32, 350000);
        const pc = perfCounters.getThreadCounters(&counter1);
        try tree.insert(allocator, key, value);
        const pc2 = perfCounters.getThreadCounters(&counter2);
        std.debug.print("insert took {} cycles and {} instructions\n", .{ pc2.cycles - pc.cycles, pc2.instructions - pc.instructions });

        std.debug.assert(tree.root.?.check() == true);
        try keysList.append(key);
    }
    for (keysList.items) |k| {
        var v = tree.search(k);
        if (v == null) {
            @panic("failed to delete and return something");
        }
        const pc = perfCounters.getThreadCounters(&counter1);
        tree.delete(allocator, k);
        const pc2 = perfCounters.getThreadCounters(&counter2);
        std.debug.print("delete took {} cycles and {} instructions\n", .{ pc2.cycles - pc.cycles, pc2.instructions - pc.instructions });

        v = tree.search(k);
        if (v != null) {
            std.debug.print("failed to delete {}\n", .{k});
            try tree.root.?.bst_print_dot(&stdout);
            @panic("kokaka");
        }
        if (tree.root != null and tree.root.?.check() == false) {
            try tree.root.?.bst_print_dot(&stdout);
            @panic("check failed after delete");
        }
    }
    std.debug.assert(tree.root == null);
}

test "simple test" {}
