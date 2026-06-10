// Overrides the default 1.0 animation coefficient for faster SpringBoard animations
// Usage: override_drag_coefficient(0.25);
// iOS 17:     direct write (function has no gating, just stores into the global)
// iOS 18+/26: write value + sentinel; rev-counter gating was introduced in 18.0b3

// Update 1: Performance and logic optimizations.
// Update 2: iOS 17 support  detect absence of gating vars and skip sentinel write.

#include <dlfcn.h>
#include <stdint.h>
#include <stdbool.h>
#include <stdio.h>
#include <string.h>

typedef struct {
    uint64_t g, revVar, revOnce;
    uint32_t valOff, revOff;
    bool gated, isFloat;
} drag_t;

static uint64_t strip_fp(void *p)
{
    uint64_t v = (uint64_t)p;
    if (v >> 47) {
#if defined(__has_builtin) && __has_builtin(__builtin_ptrauth_strip)
        v = (uint64_t)__builtin_ptrauth_strip((void *)v, 0);
#else
        __asm__ volatile("xpaci %0" : "+r"(v));
#endif
    }
    return v;
}

static bool find_drag(drag_t *o)
{
    void *fp = dlsym(RTLD_DEFAULT, "_SetUIAnimationDragCoefficient");
    if (!fp) {
        void *h = dlopen("/System/Library/PrivateFrameworks/UIKitCore.framework/UIKitCore", RTLD_LAZY);
        if (h) fp = dlsym(h, "_SetUIAnimationDragCoefficient");
        if (!fp) { printf("[ANIM] dlsym failed\n"); return false; }
    }
    uint64_t pc = strip_fp(fp);
    const uint32_t *c = (const uint32_t *)pc;
    for (int i = 0; i < 4; i++)
        if ((c[i] & 0xfc000000) == 0x14000000) {
            pc += (uint64_t)i*4 + (int64_t)((int32_t)(c[i]<<6)>>4);
            c = (const uint32_t *)pc; break;
        }

    uint64_t pg[32]={0}, pv[32]={0}, g=0, rV=0, rO=0;
    uint32_t vOff=0, rOff=0;
    bool isFloat = false;

    for (int i = 0; i < 80; i++) {
        uint32_t in=c[i]; int rd=in&31, rn=(in>>5)&31;
        uint64_t ipc=pc+(uint64_t)i*4;
        if (in==0xd65f03c0 || in==0xd65f0bff || in==0xd65f0fff) break;

        if ((in&0x9f000000)==0x90000000) {                          // ADRP
            int64_t lo=(in>>29)&3, hi=(in>>5)&0x7ffff;
            int64_t off=((hi<<2)|lo)<<12; off=(off<<31)>>31;
            pg[rd]=(ipc&~0xfffULL)+off; pv[rd]=0;
            printf("[ANIM] +%d ADRP x%d=0x%llx\n", i*4, rd, (unsigned long long)pg[rd]);
        } else if ((in&0xff800000)==0x91000000 && pg[rn]) {         // ADD imm
            pv[rd]=pg[rn]+((in>>10)&0xfff);
            printf("[ANIM] +%d ADD x%d=0x%llx\n", i*4, rd, (unsigned long long)pv[rd]);
        } else if ((in&0xffc00000)==0xf9400000 && pg[rn] && !rO) {
            rO = pg[rn] + (((in>>10)&0xfff)<<3);
            printf("[ANIM] +%d LDR Xt -> rO=0x%llx\n", i*4, (unsigned long long)rO);
        } else if ((in&0xffc00000)==0xb9400000 && pg[rn] && !rV) {
            rV = pg[rn] + (((in>>10)&0xfff)<<2);
            printf("[ANIM] +%d LDR Wt -> rV=0x%llx\n", i*4, (unsigned long long)rV);
        } else if ((in&0xff800000)==0xfd000000 && !g) {              // STR Dt -> double (iOS 18+)
            uint64_t base = pv[rn] ? pv[rn] : pg[rn];
            if (base) {
                g=base; vOff=((in>>10)&0xfff)<<3; isFloat=false;
                printf("[ANIM] +%d STR Dt -> g=0x%llx vOff=0x%x (double)\n",
                       i*4, (unsigned long long)g, vOff);
            }
        } else if ((in&0xffc00000)==0xbd000000 && !g) {              // STR St -> float (iOS 17)
            uint64_t base = pv[rn] ? pv[rn] : pg[rn];
            if (base) {
                g=base; vOff=((in>>10)&0xfff)<<2; isFloat=true;
                printf("[ANIM] +%d STR St -> g=0x%llx vOff=0x%x (float)\n",
                       i*4, (unsigned long long)g, vOff);
            }
        } else if ((in&0xff800000)==0xb9000000 && g && pv[rn]==g) {
            rOff = ((in>>10)&0xfff)<<2;
            printf("[ANIM] +%d STR Wt -> rOff=0x%x\n", i*4, rOff);
            break;
        }
    }

    if (!g) { printf("[ANIM] FAIL: no STR Dt/St matched\n"); return false; }
    bool gated = (rV && rO && (rO == rV + 8 || rV == rO + 8));
    o->g=g; o->revVar=rV; o->revOnce=rO;
    o->valOff = (gated && !vOff) ? 8 : vOff;
    o->revOff = rOff; o->gated = gated; o->isFloat = isFloat;
    printf("[ANIM] result: g=0x%llx vOff=0x%x gated=%d isFloat=%d\n",
           (unsigned long long)g, o->valOff, gated, isFloat);
    return true;
}

void override_drag_coefficient(double v)
{
    drag_t d;
    if (!find_drag(&d)) { printf("[ANIM] find_drag failed\n"); return; }
    init_remote_call("SpringBoard", false);

    if (d.gated) {                                  // iOS 18+/26: rev + sentinel + double
        union { double dv; uint64_t u; } b = { .dv = v };
        uint32_t rv = 0;
        remote_read(d.revVar, &rv, 4);
        if ((int)rv < 1) { uint32_t one = 1; remote_write(d.revVar, &one, 4); rv = 1; }
        uint32_t sentinel = 0x7fffffff;
        remote_write(d.g + d.revOff, &sentinel, 4);
        remote_write(d.g + d.valOff, &b.u, 8);

        double chk=0; uint32_t sr=0;
        remote_read(d.g + d.valOff, &chk, 8);
        remote_read(d.g + d.revOff, &sr, 4);
        printf("[ANIM] gated g=0x%llx revVar=%u value=%.4f slotRev=0x%x\n",
               (unsigned long long)d.g, rv, chk, sr);
    } else if (d.isFloat) {                         // iOS 17: 32-bit float, no gating
        float f = (float)v;
        remote_write(d.g + d.valOff, &f, 4);
        float chk = 0;
        remote_read(d.g + d.valOff, &chk, 4);
        printf("[ANIM] f32 g=0x%llx+0x%x value=%.4f\n",
               (unsigned long long)d.g, d.valOff, (double)chk);
    } else {                                        // ungated double (theoretical)
        union { double dv; uint64_t u; } b = { .dv = v };
        remote_write(d.g + d.valOff, &b.u, 8);
        double chk = 0;
        remote_read(d.g + d.valOff, &chk, 8);
        printf("[ANIM] f64 g=0x%llx+0x%x value=%.4f\n",
               (unsigned long long)d.g, d.valOff, chk);
    }

    destroy_remote_call();
}