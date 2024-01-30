const std = @import("std");

const plist_data_ptr = opaque {};
const event_map_ptr = opaque {};
const c_str = [*:0]const u8;
const usize_ptr = *usize;
const kpc_config = u64;
const kpep_event = extern struct { name: c_str, description: c_str, errata: c_str, alias: c_str, fallback: c_str, mask: u32, number: u8, umask: u8, reserved: u8, is_fixed: u8 };

const kpep_db = extern struct { name: [*:0]const u8, cpu_id: [*:0]const u8, marketing_name: [*:0]const u8, plist_data: *plist_data_ptr, event_map: *event_map_ptr, event_arr: *kpep_event, fixed_event_arr: [*]*kpep_event, alias_map: *opaque {}, reserved_1: usize, reserved_2: usize, reserved_3: usize, event_count: usize, alias_count: usize, fixed_counter_count: usize, config_counter_count: usize, power_counter_count: usize, architecture: u32, fixed_counter_bits: u32, config_counter_bits: u32, power_counter_bits: u32 };

const kpep_config = extern struct {
    db: *kpep_db,
    ev_arr: [*]*kpep_event,
    ///< (sizeof(kpep_event *) * counter_count), init NULL
    ev_map: [*]usize_ptr,
    ///< (sizeof(usize *) * counter_count), init 0
    ev_idx: [*]usize_ptr,
    ///< (sizeof(usize *) * counter_count), init -1
    flags: [*]*u32,
    ///< (sizeof(u32 *) * counter_count), init 0
    kpc_periods: [*]*u64,
    ///< (sizeof(u64 *) * counter_count), init 0
    event_count: usize,
    /// kpep_config_events_count()
    counter_count: usize,
    classes: u32,
    ///< See `class mask constants` above.
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
        return Self{ .dynlib = d, .kpep_db_create = libPerfData.lookup(*const fn (?[*:0]const u8, **kpep_db) callconv(.C) i32, "kpep_db_create").?, .kpep_db_events_count = libPerfData.lookup(*const fn (*kpep_db, *usize) callconv(.C) i32, "kpep_db_events_count").?, .kpep_db_events = libPerfData.lookup(*const fn (*kpep_db, [*]*kpep_event, usize) callconv(.C) i32, "kpep_db_events").?, .kpep_config_create = libPerfData.lookup(*const fn (*kpep_db, **kpep_config) callconv(.C) i32, "kpep_config_create").?, .kpep_config_force_counters = libPerfData.lookup(*const fn (*kpep_config) callconv(.C) i32, "kpep_config_force_counters").?, .kpep_config_add_event = libPerfData.lookup(*const fn (*kpep_config, **kpep_event, u32, ?*u32) callconv(.C) i32, "kpep_config_add_event").?, .kpep_config_kpc_classes = libPerfData.lookup(*const fn (*kpep_config, *u32) callconv(.C) i32, "kpep_config_kpc_classes").?, .kpep_config_kpc_count = libPerfData.lookup(*const fn (*kpep_config, *usize) callconv(.C) i32, "kpep_config_kpc_count").?, .kpep_config_kpc_map = libPerfData.lookup(*const fn (*kpep_config, *usize, usize) callconv(.C) i32, "kpep_config_kpc_map").?, .kpep_config_kpc = libPerfData.lookup(*const fn (*kpep_config, *kpc_config, usize) callconv(.C) i32, "kpep_config_kpc").?, .kpep_db_event = libPerfData.lookup(*const fn (*kpep_db, [*:0]const u8, **kpep_event) callconv(.C) i32, "kpep_db_event").? };
    }
};
const perfLib = struct {
    const Self = @This();
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
        return Self{ .kpc_get_thread_counters = libPerf.lookup(*const fn (u32, u32, [*]u64) callconv(.C) i32, "kpc_get_thread_counters").?, .kpc_get_counter_count = libPerf.lookup(*const fn (u32) callconv(.C) u32, "kpc_get_counter_count").?, .kpc_pmu_version = libPerf.lookup(*const fn () callconv(.C) u32, "kpc_pmu_version").?, .kpc_force_all_ctrs_get = libPerf.lookup(*const fn (*i32) callconv(.C) i32, "kpc_force_all_ctrs_get").?, .kpc_force_all_ctrs_set = libPerf.lookup(*const fn (i32) callconv(.C) i32, "kpc_force_all_ctrs_set").?, .kpc_set_config = libPerf.lookup(*const fn (u32, *kpc_config) callconv(.C) i32, "kpc_set_config").?, .kpc_set_counting = libPerf.lookup(*const fn (u32) callconv(.C) i32, "kpc_set_counting").?, .kpc_set_thread_counting = libPerf.lookup(*const fn (u32) callconv(.C) i32, "kpc_set_thread_counting").? };
    }
};
/// The events we are interested in tracking;
const m2MacEvents = [_][]const u8{ "FIXED_CYCLES", "FIXED_INSTRUCTIONS", "INST_BRANCH", "BRANCH_MISPRED_NONSPEC" };
/// counter_map[i] contains index of register[i] where i is the event we are interested in tracking
/// event is counted sequentially in the order we express interest in tracking them (via add_event)
var counter_map = [_]usize{0} ** 32;
/// The actual register values for each perf counter
var regs = [_]u64{0} ** 32;
const performance_counters = struct {
    cycles: u64,
    instructions: u64,
    branches: u64,
    branch_misses: u64,
};
threadlocal var counters = [_]u64{0} ** 32;

pub fn main() !void {
    var libPerf = try std.DynLib.open("/System/Library/PrivateFrameworks/kperf.framework/kperf");
    var libPerfData = try std.DynLib.open("/System/Library/PrivateFrameworks/kperfdata.framework/kperfdata");
    defer libPerf.close();
    defer libPerfData.close();
    const perf_lib = perfLib.new(libPerf);
    const perf_doobi = perfDb.new(libPerfData);

    std.debug.print("found the dynamic lib we need\n", .{});

    var res: i32 = 0;
    if (perf_lib.kpc_force_all_ctrs_get(&res) != 0) {
        std.debug.print("cannot get counter access, maybe you have to run as root", .{});
    } else {
        std.debug.print("success, can run as root\n", .{});
    }
    std.debug.print("pmu version is {}\n", .{perf_lib.kpc_pmu_version()});
    var db: *kpep_db = undefined;
    if (perf_doobi.kpep_db_create(null, &db) != 0) {
        std.debug.print("unable to read the perf database", .{});
    }
    std.debug.print("loaded db {s} with marketing name {s}\n", .{ db.*.name, db.*.marketing_name });
    std.debug.print("fixed counter count {} config counter count {}\n", .{ db.*.fixed_counter_count, db.*.config_counter_count });
    std.debug.print("we can track events # {}\n", .{db.*.event_count});
    var events_count: usize = 0;
    if (perf_doobi.kpep_db_events_count(db, &events_count) != 0) {
        std.debug.print("unable to get event count\n", .{});
    }
    std.debug.print("we can track {} events\n", .{events_count});
    const events_buf = try std.heap.page_allocator.alloc(*kpep_event, events_count);
    if (perf_doobi.kpep_db_events(db, events_buf.ptr, @sizeOf(*kpep_event) * events_count) != 0) {
        std.debug.print("cant list out supported events \n", .{});
    }

    var config: *kpep_config = undefined;
    if (perf_doobi.kpep_config_create(db, &config) != 0) {
        @panic("cannot create config for setting up perf counters");
    }
    if (perf_doobi.kpep_config_force_counters(config) != 0) {
        @panic("unable to force counters");
    }

    var found_events = [_]?*kpep_event{null} ** m2MacEvents.len;
    for (m2MacEvents, 0..) |event, i| {
        var maybe_event: *kpep_event = undefined;
        if (perf_doobi.kpep_db_event(db, @as([*:0]const u8, @ptrCast(event)), &maybe_event) != 0) {
            std.debug.panic("unable to obtain event {s} to track", .{event});
        }
        found_events[i] = maybe_event;
        if (perf_doobi.kpep_config_add_event(config, &maybe_event, 0, null) != 0) {
            std.debug.panic("failed to add event {s} to config\n", .{event});
        }
    }
    var classes: u32 = 0;
    var reg_count: usize = 0;
    if (perf_doobi.kpep_config_kpc_classes(config, &classes) != 0) {
        @panic("failed to get kpc classes");
    }
    std.debug.print("classes is {x}\n", .{classes});
    if (perf_doobi.kpep_config_kpc_count(config, &reg_count) != 0) {
        @panic("could get register count");
    }
    std.debug.print("register count is {}\n", .{reg_count});

    if (perf_doobi.kpep_config_kpc_map(config, &counter_map[0], @sizeOf(usize) * counter_map.len) != 0) {
        @panic("failed to get counter map");
    }
    // some sort of register config?
    if (perf_doobi.kpep_config_kpc(config, &regs[0], @sizeOf(u64) * regs.len) != 0) {
        @panic("Failed get kpc registers");
    }

    // Try to acquire registers needed for our perf counting from the Power Manager
    if (perf_lib.kpc_force_all_ctrs_set(1) != 0) {
        @panic("Failed force all ctrs");
    }
    const KPC_CLASS_CONFIGURABLE_MASK = 2;
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
    var pc = thread_get_performance_counters(perf_lib, &counters, &counter_map);
    var kk = hashSliceAnd(&"old yeller had a big fat dog that would just sleep all the time".*, 16384);
    var pc2 = thread_get_performance_counters(perf_lib, &counters, &counter_map);

    std.debug.print("hashSliceAnd took {} cycles and {} instructions with res {}\n", .{ pc2.cycles - pc.cycles, pc2.instructions - pc.instructions, kk });

    pc = thread_get_performance_counters(perf_lib, &counters, &counter_map);
    kk = hashSliceAnd(&"old yeller had a big fat dog that would just sleep all the time".*, 16384);
    pc2 = thread_get_performance_counters(perf_lib, &counters, &counter_map);

    std.debug.print("hashSliceModule took {} cycles and {} instructions with res {}\n", .{ pc2.cycles - pc.cycles, pc2.instructions - pc.instructions, kk });
}

pub fn thread_get_performance_counters(plib: perfLib, cc: []u64, config_map: []u64) performance_counters {
    const lenu32: u32 = @truncate(cc.len);
    if (plib.kpc_get_thread_counters(0, lenu32, cc.ptr) != 0) {
        @panic("unable to get perf countes value");
    }
    return performance_counters{ .cycles = cc[config_map[0]], .instructions = cc[config_map[1]], .branches = cc[config_map[2]], .branch_misses = cc[config_map[3]] };
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
