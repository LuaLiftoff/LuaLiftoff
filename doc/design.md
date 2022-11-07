# Design

This document discusses the different design decisions taken for this project.

## Lua Version

This project should stay up to date with the newest Lua versions.

## Value Format

The most important part is the question how to represent values. Lua uses a tagged value of the Form:

```C
struct TValue {
    union {
        lua_Integer int_value;
        lua_Number float_value;
        GCObject* gc_object;
        void* light_userdata;
    };
    uint8_t tag;
};
```

The disadvantage of this approach is that `sizeof(TValue) == 16` in 64 bit. This would give 7 byte garbage in arrays and the stack. In other objects other fields could be appended directly after the tag byte.

An different approach is the one taken from LuaJIT. They represent a tagged value as:

```C
union TValue {
    lua_Number float_value;
    uint64_t bit_magic_others;
}
```

This abuses the fact that float `NaN` values have some space for other uses. However, the problem is that 64 bit integer won't fit and it is not future proof for full 64 bit pointers, as it currently assumes that they are 48 bit.

Therefore we choose the easiest way possible:

```C
struct TValue {
    vm_pointer flag_a:1; // bit[0]
    vm_pointer flag_b:2; // bit[1]
    vm_pointer gc_object:remaining; // bits [2..]
};
```

Everything is a GC object. This ensures that only 64 bit is used. It even possible to use pointer compression on 64 bit platforms to reduce the size of a `TValue` to 32 bit. Furthermore, this allows to pass 64 bit integers and floats faster on 32 bit platforms.

The disadvantage of this approach is that we need to follow a pointer to find the type of the Value. However, other similar VMs such as v8 uses similar representation.

## GC Object Header

The GC object requires a unique header so that the type of the object can be determined.

We use the following header:

```C
struct GCObject {
    uint32_t hidden_class;
    uint8_t gc_flags;
    uint8_t other_flags;
    uint16_t owning_thread;
};
```

This allows to load and compare the hidden class with 2 instructions on x86 and x64 and likely other platforms, since the constant 32 bit hidden class can be embedded into the compare instruction.

To get the GC object of the hidden class the index of the hidden class can be used as offset into an array of hidden classes.

The `gc_glags` can hold information like mark, age, and if the object is moved.

The `other_flags` is currently unused.

The `owning_thread` can be used in multithreaded environments to indicate which thread created and therefore owns the object.

## Tables

Tables will have the following layout:

```C
struct Table {
    GCObject header;
    TValue array_part;
    TValue element_part;
    TValue hash_part;
};
```

The array part can either be an array or an integer hash map. This will allow for keys to be decided from the beginning if they live in the array or element part.

The element part is either an array or a hash map and contains only string keys. If it is an array then the index can be determined from the hidden class. This allows the JIT to emit a check if the object is of a specific hidden class and then a direct load from the known index index in the element array.

Every other key like float keys or tables will be found in the hash part.

The metatable will be found in the hidden class or the hidden class will be able to give the location for the metatable. The metatable is normally embedded into the hidden class to allow very fast accesses to member methods without following the metatable chain and checking every table.

It should be noted that removing of keys from the element part is it is an array is impossible, the value will only be set to `nil` and the key remains until the element part is changed to an hash map if it gets to full or an new key is introduced from an instruction that disabled hidden class creations, since it created to many and no hidden class transition with that key is found.

Flag `flag_a` and `flag_b` are used to determine the layout of the parts.

- `flag_a` tells weather this part was written to by a different thread.
- `flag_b` tells weather this part is segmented.

We do not use in object elements since Lua does not have classes the could give a basis for the object and objects created with `{}` will be very different.

## String

Strings will have the following layout:

```C
struct String {
    GCObject header;
    size_t length;
    TValue hash;
    char data[];
};
```

The hash is calculated on demand and is also used to point to the non moving version if the string is requested from c depending on `flag_a`. The hash can then be looked up in the non moving version. Dynamically created strings will not be interned directly. The GC might decide to deduplicate them.

## GC

Currently the GC is planed to be a parallel scavenging with mark-sweep and optional compacting GC. The following spaces are planned:

- Nursery: Young object will be allocated here. Every thread will have a dedicated nursery.
- Young: Objects in the nursery that survive one GC cycle will be copied here.
- Old: Objects from the young space will be copied here if they survive in the young space for one GC cycle.
- Large: Large objects that don't fit into a space will be allocated here.
- Non Moving: Object that should not move will be allocated here.

The nursery and young spaces are parallel scavenged. The other collections are concurrently marked and swept. Every GC cycle some areas from the old collection are chosen and objects from these areas are evacuated to others to free up the whole area. This is used to reduce fragmentation.

Objects that need to be allocated into the non moving space are FFI objects and escaping string. Strings will normally be allocated into the normal heap, however, if the char pointer is requested from c a copy is made into the non moving space and references are set so that after the next GC cycle everyone is using the string object in the non moving space. Since large strings are allocated into the non moving large space, these do not need to be copied.

The allocation strategy for the non moving space is not yet determined, since it should be fast to support FFI objects. However, it can fragments since no compaction can be done. In contrast allocation from the nursery is fast since it is only a pointer bump and a check that there was space.

## Multithreading

This Lua implementation should be able to run multiple threads. The reason is that the JIT should be fully written in Lua code and should run in parallel to the program to JIT methods. To accomplish this multithreading capabilities are required and can be exposed to the user.

## JIT

The JIT is fully written in Lua. The compiler part from the JIT will also be used to build the binary LuaLiftoff library, since it can compile written code. So the full LuaLiftoff project can be written in Lua.

## Calling Convention

To call JIT compiled functions, a call ABI needs to be established.

Since Lua functions can take a variable number of arguments and return a variable amount. This suggest to use the stack. This seems to be the best way, since the interpreter has all parameters already on the stack and the JIT code will inline small functions where register passing might be beneficial. To make the calling convention compatible with the c API, parameters are stored left to right prepended by the function object.

The following hidden parameters are also required:

- Thread
- Number of parameters
- Stack top
- Return address

these should be passed via registers and restored on function return.

## GC Barriers

Since the GC runs concurrently and has age boundaries barriers are required. This is accomplished with a write barrier that checks if the object written to is black or old and triggers in both cases. This should be quite cheap since the objects is likely in the cache since it was written to.
