const std = @import("std");

const plist_data_ptr = opaque {};
const event_map_ptr = opaque {};
const c_str = [*:0]const u8;

const kpep_event = extern struct { name: c_str, description: c_str, errata: c_str, alias: c_str, fallback: c_str, mask: u32, number: u8, umask: u8, reserved: u8, is_fixed: u8 };

const kpep_db = extern struct { name: [*:0]const u8, cpu_id: [*:0]const u8, marketing_name: [*:0]const u8, plist_data: *plist_data_ptr, event_map: *event_map_ptr, event_arr: *kpep_event, fixed_event_arr: [*]*kpep_event, alias_map: *opaque {}, reserved_1: usize, reserved_2: usize, reserved_3: usize, event_count: usize, alias_count: usize, fixed_counter_count: usize, config_counter_count: usize, power_counter_count: usize, architecture: u32, fixed_counter_bits: u32, config_counter_bits: u32, power_counter_bits: u32 };

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

    const kpep_create_db = libPerfData.lookup(*const fn (?[*:0]const u8, **kpep_db) callconv(.C) i32, "kpep_db_create").?;
    const kpep_db_events_count = libPerfData.lookup(*const fn (*kpep_db, *usize) callconv(.C) i32, "kpep_db_events_count").?;
    const kpep_db_events = libPerfData.lookup(*const fn (*kpep_db, [*]*kpep_event, usize) callconv(.C) i32, "kpep_db_events").?;
    var db: *kpep_db = undefined;
    if (kpep_create_db(null, &db) != 0) {
        std.debug.print("unable to read the perf database", .{});
    }
    std.debug.print("loaded db {s} with marketing name {s}\n", .{ db.*.name, db.*.marketing_name });
    std.debug.print("fixed counter count {} config counter count {}\n", .{ db.*.fixed_counter_count, db.*.config_counter_count });
    std.debug.print("we can track events # {}\n", .{db.*.event_count});
    var events_count: usize = 0;
    if (kpep_db_events_count(db, &events_count) != 0) {
        std.debug.print("unable to get event count\n", .{});
    }
    std.debug.print("we can track {} events\n", .{events_count});
    const events_buf = try std.heap.page_allocator.alloc(*kpep_event, events_count);
    if (kpep_db_events(db, events_buf.ptr, @sizeOf(*kpep_event) * events_count) != 0) {
        std.debug.print("cant list out supported events \n", .{});
    }
    var i: usize = 0;
    while (i < events_count) : (i += 1) {
        std.debug.print("event name {s}\n", .{events_buf[i].*.name});
    }
}
