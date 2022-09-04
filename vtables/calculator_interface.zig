// All Zig files are essential structs. @This gives us a `type` for this struct
const Calculator = @This();
// A type-erase pointer to the implementation
ptr: *anyopaque,
// A VTable is how we dispatch the operating the interface provides
// to the implementing struct
vtable: *const VTable, //const* as we MUST NOT modify the value of this pointer
pub const VTable = struct { add: addProto, sub: subProto, mul: mulProto, div: divProto };

// Our interface provides the following functions (aka THE CONTRACT)
// First arg is an explicit pointer to the concrete type
// implementing the interface

pub fn add(s: *Calculator, x: i32, y: i32) i32 {
    return s.vtable.add(s.ptr, x, y);
}
pub fn sub(s: *Calculator, x: i32, y: i32) i32 {
    return s.vtable.sub(s.ptr, x, y);
}
pub fn mul(s: *Calculator, x: i32, y: i32) i32 {
    return s.vtable.mul(s.ptr, x, y);
}
pub fn div(s: *Calculator, x: f32, y: f32) f32 {
    return s.vtable.div(s.ptr, x, y);
}

// These are the fns provided by the implementation, that will satisify
// the fns in the interface
// These fns have the same signature as our interface fns
// except the ptr arg is type-erased
const addProto = *const fn (ptr: *anyopaque, i32, i32) i32;
const subProto = *const fn (ptr: *anyopaque, i32, i32) i32;
const mulProto = *const fn (ptr: *anyopaque, i32, i32) i32;
const divProto = *const fn (ptr: *anyopaque, f32, f32) f32;

//comptime is the key, as it lets us know
//the signature of the implementing function at compile time
pub fn init(optr: *anyopaque, comptime addI: addProto, comptime subI: subProto, comptime mulI: mulProto, comptime divI: divProto) Calculator {

    // A clever trick. addI or subI will have a type-signature of fn(c: *ConcreteType, ..args)
    // our interface has a type-erased `ptr` that we need to send to addI or subI
    // we sort of `wrap` addI or subI to allow passing this type erased pointer without a
    // compile error (of type mismatch)
    const gen = struct {
        pub fn addProtoImpl(ptr: *anyopaque, x: i32, y: i32) i32 {
            return @call(.{}, addI, .{ ptr, x, y });
        }
        pub fn subProtoImpl(ptr: *anyopaque, x: i32, y: i32) i32 {
            return @call(.{}, subI, .{ ptr, x, y });
        }
        pub fn mulProtoImpl(ptr: *anyopaque, x: i32, y: i32) i32 {
            return @call(.{}, mulI, .{ ptr, x, y });
        }
        pub fn divProtoImpl(ptr: *anyopaque, x: f32, y: f32) f32 {
            return @call(.{}, divI, .{ ptr, x, y });
        }
        // All `fns` are part of the `.text` section of the binary
        // so for each implementation , we know where exactly to `jmp`
        // for each implementation
        // vtable is not allocated on the heap, but is part of `.text` or `.rodata`
        // (as it is a const inside the struct)
        // we can therefore safely return pointers to this struct from within any fn
        const vtable = VTable{
            .add = addProtoImpl,
            .sub = subProtoImpl,
            .mul = mulProtoImpl,
            .div = divProtoImpl,
        };
    };
    return .{ .ptr = optr, .vtable = &gen.vtable };
}

//Curious , does this blow up, as `vtable` is on the stack and I return a pointer to something on the stack ?
//Ans: No, because the compiler is smart enough to know that comptime parmeters must come from `.text` or `.rodata`,
//or are immediate, so it returns a pointer to `.text` or `.rodata`
pub fn initStack(ptr: *anyopaque, comptime addI: addProto, comptime subI: subProto, comptime mulI: mulProto, comptime divI: divProto) Calculator {
    // This doesn't seem to be allocated on the stack, but rather, `.rodata`. Hmm
    // https://onlinedisassembler.com/odaweb/suZB0XjG/0
    const vtable = VTable{
        .add = addI,
        .sub = subI,
        .mul = mulI,
        .div = divI,
    };

    return .{ .ptr = ptr, .vtable = &vtable };
}
