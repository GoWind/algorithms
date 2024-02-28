const std = @import("std");

/// The events we are interested in tracking;
pub const m2MacEvents = [_][]const u8{ "FIXED_CYCLES", "FIXED_INSTRUCTIONS", "INST_BRANCH", "BRANCH_MISPRED_NONSPEC" };
const KPC_CLASS_CONFIGURABLE_MASK = 2;

const plist_data_ptr = opaque {};
const event_map_ptr = opaque {};
const c_str = [*:0]const u8;
const usize_ptr = *usize;
const kpc_config = u64;
const kpep_event = extern struct { name: c_str, description: c_str, errata: c_str, alias: c_str, fallback: c_str, mask: u32, number: u8, umask: u8, reserved: u8, is_fixed: u8 };

const kpep_db = extern struct { name: [*:0]const u8, cpu_id: [*:0]const u8, marketing_name: [*:0]const u8, plist_data: *plist_data_ptr, event_map: *event_map_ptr, event_arr: *kpep_event, fixed_event_arr: [*]*kpep_event, alias_map: *opaque {}, reserved_1: usize, reserved_2: usize, reserved_3: usize, event_count: usize, alias_count: usize, fixed_counter_count: usize, config_counter_count: usize, power_counter_count: usize, architecture: u32, fixed_counter_bits: u32, config_counter_bits: u32, power_counter_bits: u32 };
pub const kpep_config = extern struct {
    db: *kpep_db,
    ///< (sizeof(kpep_event *) * counter_count), init NULL
    ev_arr: [*]*kpep_event,
    ///< (sizeof(usize *) * counter_count), init 0
    ev_map: [*]usize_ptr,
    ///< (sizeof(usize *) * counter_count), init -1
    ev_idx: [*]usize_ptr,
    ///< (sizeof(u32 *) * counter_count), init 0
    flags: [*]*u32,
    ///< (sizeof(u64 *) * counter_count), init 0
    kpc_periods: [*]*u64,
    /// kpep_config_events_count()
    event_count: usize,
    counter_count: usize,
    ///< See `class mask constants` above.
    classes: u32,
    config_counter: u32,
    power_counter: u32,
    reserved: u32,
};

const perfDb = struct {
    const Self = @This();
    dynlib: std.DynLib,
    kpep_db_create: *const fn (?[*:0]const u8, **kpep_db) callconv(.C) i32,
    kpep_db_events_count: *const fn (*kpep_db, *usize) callconv(.C) i32,
    kpep_db_events: *const fn (*kpep_db, [*]*kpep_event, usize) callconv(.C) i32,
    kpep_db_event: *const fn (*kpep_db, [*:0]const u8, **kpep_event) callconv(.C) i32,
    kpep_config_create: *const fn (*kpep_db, **kpep_config) callconv(.C) i32,
    kpep_config_force_counters: *const fn (*kpep_config) callconv(.C) i32,
    kpep_config_add_event: *const fn (*kpep_config, **kpep_event, u32, ?*u32) callconv(.C) i32,
    // Get classes information
    kpep_config_kpc_classes: *const fn (*kpep_config, *u32) callconv(.C) i32,
    /// Get kpc register configs.
    kpep_config_kpc_count: *const fn (*kpep_config, *usize) callconv(.C) i32,
    /// Get the index mapping from event to counter.
    kpep_config_kpc_map: *const fn (*kpep_config, *usize, usize) callconv(.C) i32,
    /// Get kpc register configs.
    kpep_config_kpc: *const fn (*kpep_config, *kpc_config, usize) callconv(.C) i32,

    pub fn new(d: std.DynLib) Self {
        var libPerfData = d;
        return Self{
            .dynlib = d,
            .kpep_db_create = libPerfData.lookup(*const fn (?[*:0]const u8, **kpep_db) callconv(.C) i32, "kpep_db_create").?,
            .kpep_db_events_count = libPerfData.lookup(*const fn (*kpep_db, *usize) callconv(.C) i32, "kpep_db_events_count").?,
            .kpep_db_events = libPerfData.lookup(*const fn (*kpep_db, [*]*kpep_event, usize) callconv(.C) i32, "kpep_db_events").?,
            .kpep_config_create = libPerfData.lookup(*const fn (*kpep_db, **kpep_config) callconv(.C) i32, "kpep_config_create").?,
            .kpep_config_force_counters = libPerfData.lookup(*const fn (*kpep_config) callconv(.C) i32, "kpep_config_force_counters").?,
            .kpep_config_add_event = libPerfData.lookup(*const fn (*kpep_config, **kpep_event, u32, ?*u32) callconv(.C) i32, "kpep_config_add_event").?,
            .kpep_config_kpc_classes = libPerfData.lookup(*const fn (*kpep_config, *u32) callconv(.C) i32, "kpep_config_kpc_classes").?,
            .kpep_config_kpc_count = libPerfData.lookup(*const fn (*kpep_config, *usize) callconv(.C) i32, "kpep_config_kpc_count").?,
            .kpep_config_kpc_map = libPerfData.lookup(*const fn (*kpep_config, *usize, usize) callconv(.C) i32, "kpep_config_kpc_map").?,
            .kpep_config_kpc = libPerfData.lookup(*const fn (*kpep_config, *kpc_config, usize) callconv(.C) i32, "kpep_config_kpc").?,
            .kpep_db_event = libPerfData.lookup(*const fn (*kpep_db, [*:0]const u8, **kpep_event) callconv(.C) i32, "kpep_db_event").?,
        };
    }
};
const perfLib = struct {
    const Self = @This();
    dyn_lib: std.DynLib,
    kpc_get_thread_counters: *const fn (u32, u32, [*]u64) callconv(.C) i32,
    kpc_get_counter_count: *const fn (u32) callconv(.C) u32,
    kpc_pmu_version: *const fn () callconv(.C) u32,
    kpc_force_all_ctrs_get: *const fn (*i32) callconv(.C) i32,
    /// acquire or release counters. param 1 = acquire, 0 = release
    kpc_force_all_ctrs_set: *const fn (i32) callconv(.C) i32,

    kpc_set_config: *const fn (u32, *kpc_config) callconv(.C) i32,

    /// Set PMC classes to enable counting.
    kpc_set_counting: *const fn (u32) callconv(.C) i32,

    /// Set PMC classes to enable counting for current thread.
    kpc_set_thread_counting: *const fn (u32) callconv(.C) i32,

    pub fn new(d: std.DynLib) Self {
        var libPerf = d;
        return Self{
            .dyn_lib = d,
            .kpc_get_thread_counters = libPerf.lookup(*const fn (u32, u32, [*]u64) callconv(.C) i32, "kpc_get_thread_counters").?,
            .kpc_get_counter_count = libPerf.lookup(*const fn (u32) callconv(.C) u32, "kpc_get_counter_count").?,
            .kpc_pmu_version = libPerf.lookup(*const fn () callconv(.C) u32, "kpc_pmu_version").?,
            .kpc_force_all_ctrs_get = libPerf.lookup(*const fn (*i32) callconv(.C) i32, "kpc_force_all_ctrs_get").?,
            .kpc_force_all_ctrs_set = libPerf.lookup(*const fn (i32) callconv(.C) i32, "kpc_force_all_ctrs_set").?,
            .kpc_set_config = libPerf.lookup(*const fn (u32, *kpc_config) callconv(.C) i32, "kpc_set_config").?,
            .kpc_set_counting = libPerf.lookup(*const fn (u32) callconv(.C) i32, "kpc_set_counting").?,
            .kpc_set_thread_counting = libPerf.lookup(*const fn (u32) callconv(.C) i32, "kpc_set_thread_counting").?,
        };
    }
};

pub const Perf = struct {
    kpc_lib: perfLib,
    kpep_lib: perfDb,
    counter_map: []usize,
    regs: []u64,
    allocator: std.mem.Allocator,
    const Self = @This();

    pub fn init(requested_events: []const []const u8, allocator: std.mem.Allocator) !Self {
        const libPerf = try std.DynLib.open("/System/Library/PrivateFrameworks/kperf.framework/kperf");
        const libPerfData = try std.DynLib.open("/System/Library/PrivateFrameworks/kperfdata.framework/kperfdata");
        var perf_lib = perfLib.new(libPerf);
        var perf_doobi = perfDb.new(libPerfData);

        var res: i32 = 0;
        if (perf_lib.kpc_force_all_ctrs_get(&res) != 0) {
            std.debug.print("cannot get counter access, maybe you have to run as root", .{});
            return error.FailedToSetup;
        }
        std.debug.print("success, can run as root\n", .{});
        std.debug.print("pmu version is {}\n", .{perf_lib.kpc_pmu_version()});
        var db: *kpep_db = undefined;
        if (perf_doobi.kpep_db_create(null, &db) != 0) {
            return error.FailedToSetup;
        }
        std.debug.print("loaded db {s} with marketing name {s}\n", .{ db.*.name, db.*.marketing_name });
        std.debug.print("fixed counter count {} config counter count {}\n", .{ db.*.fixed_counter_count, db.*.config_counter_count });
        std.debug.print("we can track events # {} (just after loading db) \n", .{db.*.event_count});
        var events_count: usize = 0;
        if (perf_doobi.kpep_db_events_count(db, &events_count) != 0) {
            std.debug.print("unable to get event count\n", .{});
            return error.FailedToSetup;
        }
        std.debug.print("we can track {} events (after querying kpep_db_events_count) \n", .{events_count});
        const events_buf = try allocator.alloc(*kpep_event, events_count);
        if (perf_doobi.kpep_db_events(db, events_buf.ptr, @sizeOf(*kpep_event) * events_count) != 0) {
            std.debug.print("cant list out supported events \n", .{});
        }

        var config: *kpep_config = undefined;

        if (perf_doobi.kpep_config_create(db, &config) != 0) {
            std.debug.print("cannot create config for setting up perf counters", .{});
            return error.FailedToSetup;
        }

        if (perf_doobi.kpep_config_force_counters(config) != 0) {
            std.debug.print("unable to force counters", .{});
            return error.FailedToSetup;
        }

        var found_events = try allocator.alloc(?*kpep_event, requested_events.len);
        @memset(found_events, null);
        for (requested_events, 0..) |event, i| {
            var maybe_event: *kpep_event = undefined;
            if (perf_doobi.kpep_db_event(db, @as([*:0]const u8, @ptrCast(event)), &maybe_event) != 0) {
                std.debug.print("unable to obtain event {s} to track", .{event});
                return error.FailedToSetup;
            }
            found_events[i] = maybe_event;
            if (perf_doobi.kpep_config_add_event(config, &maybe_event, 0, null) != 0) {
                std.debug.print("failed to add event {s} to config\n", .{event});
                return error.FailedToSetup;
            }
        }
        var classes: u32 = 0;
        var reg_count: usize = 0;
        // we need to figure out if the Which class of registers are available
        // and the number of registers associated with that class
        if (perf_doobi.kpep_config_kpc_classes(config, &classes) != 0) {
            std.debug.print("failed to obtain about which  classes of regs are available", .{});
            return error.FailedToSetup;
        }
        std.debug.print("classes is {x}\n", .{classes});

        if (perf_doobi.kpep_config_kpc_count(config, &reg_count) != 0) {
            std.debug.print("could get register count", .{});
            return error.FailedToSetup;
        }
        std.debug.print("register count is {}\n", .{reg_count});
        var regs = try allocator.alloc(u64, reg_count);

        var counter_map = try allocator.alloc(usize, requested_events.len);
        // We registered that we are interested in tracking some events. When calling `get_counters`
        // we get an array of counter values, but we won't know which counter corresponds to which event
        // We thus configure the counter_map, so that counter_map[i] indicates the index j in get_counters
        // for event i:  get_counters[counter_map[i]]  = counter_for_event_i
        if (perf_doobi.kpep_config_kpc_map(config, &counter_map[0], @sizeOf(usize) * counter_map.len) != 0) {
            std.debug.print("failed to get counter map", .{});
            return error.FailedToSetup;
        }
        // some sort of register config?
        if (perf_doobi.kpep_config_kpc(config, &regs[0], @sizeOf(u64) * regs.len) != 0) {
            std.debug.print("Failed get kpc registers", .{});
            return error.FailedToSetup;
        }

        // Try to acquire registers needed for our perf counting from the Power Manager
        if (perf_lib.kpc_force_all_ctrs_set(1) != 0) {
            std.debug.print("Failed force all ctrs", .{});
            return error.FailedToSetup;
        }

        // if we cant access the configurable counters throw error
        if ((classes & KPC_CLASS_CONFIGURABLE_MASK != 0) and (reg_count > 0)) {
            if (perf_lib.kpc_set_config(classes, &regs[0]) != 0) {
                @panic("failed to set kpc config");
            }
        }

        // enable counting for configurable counters
        if (perf_lib.kpc_set_counting(classes) != 0) {
            @panic("Failed set counting");
        }

        // Set PMC classes to enable counting for current thread.
        if (perf_lib.kpc_set_thread_counting(classes) != 0) {
            @panic("Failed set thread counting");
        }

        return Self{ .allocator = allocator, .counter_map = counter_map, .kpep_lib = perf_doobi, .kpc_lib = perf_lib, .regs = regs };
    }

    pub fn getThreadCounters(self: Self, counters: []u64) PerformanceCounters {
        const lenu32: u32 = @truncate(counters.len);
        if (self.kpc_lib.kpc_get_thread_counters(0, lenu32, counters.ptr) != 0) {
            @panic("unable to get perf countes value");
        }
        return PerformanceCounters{ .cycles = counters[self.counter_map[0]], .instructions = counters[self.counter_map[1]], .branches = counters[self.counter_map[2]], .branch_misses = counters[self.counter_map[3]] };
    }

    pub fn deinit(self: *Self) void {
        if (self.kpc_lib.kpc_force_all_ctrs_set(0) != 0) {
            @panic("unable to release perf counters");
        }
        self.kpc_lib.dyn_lib.close();
        self.kpep_lib.dynlib.close();
        self.allocator.free(self.counter_map);
        self.allocator.free(self.regs);
    }
};

pub const NoOpPerf = struct {
    const Self = @This();
    pub fn init(requested_events: []const []const u8, allocator: std.mem.Allocator) Self {
        _ = requested_events;
        _ = allocator;
        return Self{};
    }
    pub fn deinit(self: Self) void {
        _ = self;
    }
    pub fn getThreadCounters(self: Self, counters: []u64) PerformanceCounters {
        _ = self;
        _ = counters;
        return PerformanceCounters{ .cycles = 0, .instructions = 0, .branches = 0, .branch_misses = 0 };
    }
};
const PerformanceCounters = struct {
    cycles: u64,
    instructions: u64,
    branches: u64,
    branch_misses: u64,
};
// threadlocal var counters = [_]u64{0} ** 32;

test "test that perf counters work" {
    var counter1 = [_]u64{0} ** 32;
    var counter2 = [_]u64{0} ** 32;

    const events_slice: []const []const u8 = &m2MacEvents;
    var perf = try Perf.init(events_slice, std.heap.c_allocator);
    defer perf.deinit();
    var pc = perf.getThreadCounters(&counter1);
    var kk = hashSliceAnd(&"old yeller had a big fat dog that would just sleep all the time".*, 16384);
    var pc2 = perf.getThreadCounters(&counter2);

    std.debug.print("hashSliceAnd took {} cycles and {} instructions with res {}\n", .{ pc2.cycles - pc.cycles, pc2.instructions - pc.instructions, kk });

    pc = perf.getThreadCounters(&counter1);
    kk = hashSliceAnd(&"old yeller had a big fat dog that would just sleep all the time".*, 16384);
    pc2 = perf.getThreadCounters(&counter2);

    std.debug.print("hashSliceModule took {} cycles and {} instructions with res {}\n", .{ pc2.cycles - pc.cycles, pc2.instructions - pc.instructions, kk });
}

fn hashSliceAnd(data: []const u8, totalSize: usize) usize {
    var k: usize = 0;
    var hash: usize = 0;
    while (k < data.len) : (k += 1) {
        hash = (hash * 31 + data[k]) & (totalSize - 1);
    }
    return hash;
}

fn hashSliceModulo(data: []const u8, totalSize: usize) usize {
    var k: usize = 0;
    var hash: usize = 0;
    while (k < data.len) : (k += 1) {
        hash = (hash * 31 + data[k]) % (totalSize);
    }
    return hash;
}
