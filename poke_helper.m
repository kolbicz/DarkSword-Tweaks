// Just some helper functions required by some of the tweaks.

static uint64_t resolve_ivar_target(uint64_t obj, uint64_t cls, const char *name)
{
    uint64_t nameMem = remote_alloc_str(name);
    uint64_t ivar = do_remote_call_stable(100, "class_getInstanceVariable",
                                           cls, nameMem, 0, 0, 0, 0, 0, 0);
    do_remote_call_stable(5, "free", nameMem, 0, 0, 0, 0, 0, 0, 0);
    if (!ivar) {
        printf("[POKE]   %s: ivar not found\n", name);
        return 0;
    }
    uint64_t offset = do_remote_call_stable(100, "ivar_getOffset",
                                             ivar, 0, 0, 0, 0, 0, 0, 0);
    if (!offset) {
        printf("[POKE]   %s: offset=0\n", name);
        return 0;
    }
    return obj + offset;
}

static bool poke_pointer_ivar(uint64_t obj, uint64_t cls, const char *name, uint64_t value) {
    uint64_t target = resolve_ivar_target(obj, cls, name);
    if (!target) return false;
    if (!remote_write(target, &value, 8)) return false;
    uint64_t r = 0;
    remote_read(target, &r, 8);
    printf("[POKE]   %-40s @ 0x%llx -> 0x%llx\n", name, target, r);
    usleep(50000);
    return true;
}

static bool poke_double_ivar(uint64_t obj, uint64_t cls, const char *name, double value) {
    uint64_t target = resolve_ivar_target(obj, cls, name);
    if (!target) return false;
    union { double d; uint64_t u; } v = { .d = value };
    if (!remote_write(target, &v.u, 8)) return false;
    union { uint64_t u; double d; } r = { .u = 0 };
    remote_read(target, &r.u, 8);
    printf("[POKE]   %-40s @ 0x%llx -> %f\n", name, target, r.d);
    usleep(50000);
    return true;
}

static bool poke_bool_ivar(uint64_t obj, uint64_t cls, const char *name, bool value) {
    uint64_t target = resolve_ivar_target(obj, cls, name);
    if (!target) return false;
    uint8_t v = value ? 1 : 0;
    if (!remote_write(target, &v, 1)) return false;
    uint8_t r = 0xFF;
    remote_read(target, &r, 1);
    printf("[POKE]   %-40s @ 0x%llx -> %u\n", name, target, (unsigned)r);
    usleep(50000);
    return true;
}