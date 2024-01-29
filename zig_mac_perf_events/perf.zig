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
    kpep_create_db: *const fn (?[*:0]const u8, **kpep_db) callconv(.C) i32,
    kpep_db_events_count: *const fn (*kpep_db, *usize) callconv(.C) i32,
    kpep_db_events: *const fn (*kpep_db, [*]*kpep_event, usize) callconv(.C) i32,
    kpep_config_create: *const fn (*kpep_db, **kpep_config) callconv(.C) i32,
    kpep_config_force_counters: *const fn (*kpep_config) callconv(.C) i32,
    kpep_config_add_event: *const fn (*kpep_config, **kpep_event, u32, *u32) callconv(.C) i32,
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
        return Self{ .dynlib = d, .kpep_create_db = libPerfData.lookup(*const fn (?[*:0]const u8, **kpep_db) callconv(.C) i32, "kpep_db_create").?, .kpep_db_events_count = libPerfData.lookup(*const fn (*kpep_db, *usize) callconv(.C) i32, "kpep_db_events_count").?, .kpep_db_events = libPerfData.lookup(*const fn (*kpep_db, [*]*kpep_event, usize) callconv(.C) i32, "kpep_db_events").?, .kpep_config_create = libPerfData.lookup(*const fn (*kpep_db, **kpep_config) callconv(.C) i32, "kpep_config_create").?, .kpep_config_force_counters = libPerfData.lookup(*const fn (*kpep_config) callconv(.C) i32, "kpep_config_force_counters").?, .kpep_config_add_event = libPerfData.lookup(*const fn (*kpep_config, **kpep_event, u32, *u32) callconv(.C) i32, "kpep_config_add_event").?, .kpep_config_kpc_classes = libPerfData.lookup(*const fn (*kpep_config, *u32) callconv(.C) i32, "kpep_config_kpc_classes").?, .kpep_config_kpc_count = libPerfData.lookup(*const fn (*kpep_config, *usize) callconv(.C) i32, "kpep_config_kpc_count").?, .kpep_config_kpc_map = libPerfData.lookup(*const fn (*kpep_config, *usize, usize) callconv(.C) i32, "kpep_config_kpc_map").?, .kpep_config_kpc = libPerfData.lookup(*const fn (*kpep_config, *kpc_config, usize) callconv(.C) i32, "kpep_config_kpc").? };
    }
};
const perLib = struct {
    const Self = @This();

    /// acquire or release counters. param 1 = acquire, 0 = release
    kpc_force_all_ctrs_set: *const fn (i32) callconv(.C) i32,

    kpc_set_config: *const fn (u32, *kpc_config) callconv(.C) i32,

    /// Set PMC classes to enable counting.
    kpc_set_counting: *const fn (u32) callconv(.C) i32,

    /// Set PMC classes to enable counting for current thread.
    kpc_set_thread_counting: *const fn (u32) callconv(.C) i32,

    pub fn new(d: std.DynLib) Self {
        var libPerf = d;
        return Self{ .kpc_force_all_ctrs_set = libPerf.lookup(*const fn (i32) callconv(.C) i32, "kpc_force_all_ctrs_set").?, .kpc_set_config = libPerf.lookup(*const fn (u32, *kpc_config) callconv(.C) i32, "kpc_set_config").?, .kpc_set_counting = libPerf.lookup(*const fn (u32) callconv(.C) i32, "kpc_set_counting").?, .kpc_set_thread_counting = libPerf.lookup(*const fn (u32) callconv(.C) i32, "kpc_set_thread_counting").? };
    }
};
pub fn main() !void {
    var libPerf = try std.DynLib.open("/System/Library/PrivateFrameworks/kperf.framework/kperf");
    var libPerfData = try std.DynLib.open("/System/Library/PrivateFrameworks/kperfdata.framework/kperfdata");
    defer libPerf.close();
    defer libPerfData.close();

    std.debug.print("found the dynamic lib we need\n", .{});

    const prot_kpc_force_all_ctrs_get = *const fn (*i32) callconv(.C) i32;
    const kpc_force_all_ctrs_get = libPerf.lookup(prot_kpc_force_all_ctrs_get, "kpc_force_all_ctrs_get").?;
    const kpc_pmu_version = libPerf.lookup(*const fn () callconv(.C) u32, "kpc_pmu_version").?;
    var res: i32 = 0;
    if (kpc_force_all_ctrs_get(&res) != 0) {
        std.debug.print("cannot get counter access, maybe you have to run as root", .{});
    } else {
        std.debug.print("success, can run as root\n", .{});
    }
    std.debug.print("pmu version is {}\n", .{kpc_pmu_version()});

    // const kpep_create_db = libPerfData.lookup(*const fn (?[*:0]const u8, **kpep_db) callconv(.C) i32, "kpep_db_create").?;
    // const kpep_db_events_count = libPerfData.lookup(*const fn (*kpep_db, *usize) callconv(.C) i32, "kpep_db_events_count").?;
    // const kpep_db_events = libPerfData.lookup(*const fn (*kpep_db, [*]*kpep_event, usize) callconv(.C) i32, "kpep_db_events").?;
    const perf_doobi = perfDb.new(libPerfData);
    var db: *kpep_db = undefined;
    if (perf_doobi.kpep_create_db(null, &db) != 0) {
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

    var config: ?kpep_config = null;
    if (perf_doobi.kpep_config_create(db, &config) != 0) {
        @panic("cannot create config for setting up perf counters");
    }
    if (perf_doobi.kpep_config_force_counters(&config) != 0) {
        @panic("unable to force counters");
    }
}
