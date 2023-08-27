const std = @import("std");
const Allocator = std.mem.Allocator;
const Order = std.math.Order;

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
            node.height = 1 + std.math.max(Self.Height(node.left), Self.Height(node.right));
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
                    return -1 * @intCast(i32, diff);
                } else {
                    return @intCast(i32, left_height - right_height);
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
                var idx = traversal_list.items.len - r_idx - 1;
                var elem = traversal_list.items[idx];
                elem.update();
                var balance = Self.balanceFactor(elem);
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
            var balance = Self.balanceFactor(elem);
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
            } else {
                return;
            }
        }
        pub fn deleteIter(self: ?*Self, node_alloc: Allocator, key: K) ?*Self {
            if (self == null) {
                return null;
            }
            std.debug.print("deleting {}\n", .{key});
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
                }
                if (cur_node.?.key < key and cur_node.?.right != null) {
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
                    move_node(n, min_node, maybe_curnode_parent);
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
                var idx = traversal_list.items.len - r_idx - 1;
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
            var balance = Self.balanceFactor(node);
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
                    return true;
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
            var new_node = try node_type.withKV(alloc, key, val);
            self.root = try node_type.insert(self.root, new_node);
        }
        pub fn delete(self: *Self, alloc: Allocator, key: K) void {
            self.root = node_type.deleteIter(self.root, alloc, key);
        }

        const SelfPrioS = struct {
            key: *node_type,
            prio: u32,
            const SSelf = @This();
            pub fn comparator(_: void, a: SSelf, b: SSelf) Order {
                if (a.prio <= b.prio) {
                    return Order.lt;
                } else {
                    return Order.gt;
                }
            }
        };

        const QType = std.PriorityQueue(SelfPrioS, void, SelfPrioS.comparator);
        pub fn visitLevelwise(self: *Self, alloc: Allocator) !void {
            if (self.root == null) {
                return;
            }
            var q = QType.init(alloc, {});
            defer q.deinit();
            try q.add(SelfPrioS{ .key = self.root.?, .prio = 0 });
            while (q.removeOrNull()) |front| {
                std.debug.print("level {} and key {} \n", .{ front.prio, front.key.key });
                if (front.key.left) |fl| {
                    try q.add(SelfPrioS{ .key = fl, .prio = 2 * front.prio + 1 });
                }
                if (front.key.right) |fr| {
                    try q.add(SelfPrioS{ .key = fr, .prio = 2 * front.prio + 2 });
                }
            }
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

    var tree = utree{};

    var prng = std.rand.DefaultPrng.init(0);
    prng.seed(100);
    const random = prng.random();
    var i: usize = 0;
    var keysList = std.ArrayList(u32).init(allocator);

    while (i < 100) : (i += 1) {
        var key: u32 = random.intRangeAtMost(u32, 10, 99999);
        var value: u32 = random.uintAtMost(u32, 350000);
        try tree.insert(allocator, key, value);
        std.debug.assert(tree.root.?.check() == true);
        try keysList.append(key);
    }
    try tree.visitLevelwise(allocator);
    for (keysList.items) |k| {
        var v = tree.search(k);
        std.debug.print("searching for key: {} \n", .{k});
        if (v == null) {
            std.debug.print("missing {}\n", .{k});
        }
        tree.delete(allocator, k);
        if (tree.root != null and tree.root.?.check() == false) {
            try tree.visitLevelwise(allocator);
        }
    }
    std.debug.assert(tree.root == null);
}

test "simple test" {}