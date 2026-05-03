// This tweak disables the screen backlight fade animation.
// It turns off the screen immediately when you lock the phone.

void zero_backlight_fade(void)
{
    init_remote_call("SpringBoard", false);
    printf("[BLF] zeroing backlight fade durations\n");

    uint64_t selShared    = remote_sel("sharedInstance");
    uint64_t selClass     = remote_sel("class");
    uint64_t selFetchSet  = remote_sel("_animationSettingsForBacklightChangeSource:isWake:");
    printf("[BLF] selectors registered\n");
    usleep(100000);

    uint64_t cls = remote_getClass("SBScreenWakeAnimationController");
    if (!cls) { printf("[BLF] controller class not found\n"); goto done; }
    usleep(50000);

    uint64_t ctrl = remote_msg(cls, selShared, 0,0,0,0);
    if (!ctrl) { printf("[BLF] sharedInstance failed\n"); goto done; }
    printf("[BLF] ctrl=0x%llx\n", ctrl);
    usleep(50000);

    // Enumerate (source, isWake). Track unique settings objects so we only
    // resolve the ivar offset once per distinct class.
    uint64_t seen[16] = {0};
    int seenCount = 0;

    uint64_t settingsCls = 0;
    uint64_t ivarOffset  = 0;

    for (int src = 0; src <= 3; src++) {
        for (int isWake = 0; isWake <= 1; isWake++) {
            uint64_t settings = remote_msg(ctrl, selFetchSet,
                                           (uint64_t)src, (uint64_t)isWake, 0, 0);
            usleep(50000);

            if (!settings) {
                printf("[BLF] src=%d wake=%d -> nil\n", src, isWake);
                continue;
            }

            // Dedupe
            bool dup = false;
            for (int i = 0; i < seenCount; i++) if (seen[i] == settings) { dup = true; break; }
            if (dup) {
                printf("[BLF] src=%d wake=%d -> 0x%llx (already poked)\n", src, isWake, settings);
                continue;
            }
            if (seenCount < 16) seen[seenCount++] = settings;
            printf("[BLF] src=%d wake=%d settings=0x%llx\n", src, isWake, settings);

            // Resolve the ivar once per class (all these should be the same class)
            if (!ivarOffset) {
                settingsCls = remote_msg(settings, selClass, 0,0,0,0);
                usleep(50000);

                uint64_t nameMem = remote_alloc_str("_backlightFadeDuration");
                uint64_t ivar = do_remote_call_stable(100, "class_getInstanceVariable",
                                                      settingsCls, nameMem, 0,0,0,0,0,0);
                do_remote_call_stable(5, "free", nameMem, 0,0,0,0,0,0,0);
                if (!ivar) { printf("[BLF] ivar not found on class\n"); goto done; }
                ivarOffset = do_remote_call_stable(100, "ivar_getOffset",
                                                    ivar, 0,0,0,0,0,0,0);
                if (!ivarOffset) { printf("[BLF] ivar offset=0\n"); goto done; }
                printf("[BLF] _backlightFadeDuration offset=0x%llx\n", ivarOffset);
            }

            // Poke zero into this settings instance
            union { double d; uint64_t u; } v = { .d = 0.0 };
            uint64_t target = settings + ivarOffset;
            if (!remote_write(target, &v.u, sizeof(v.u))) {
                printf("[BLF] write failed @ 0x%llx\n", target);
                continue;
            }

            union { uint64_t u; double d; } r = { .u = 0 };
            remote_read(target, &r.u, sizeof(r.u));
            printf("[BLF]   0x%llx -> %f\n", target, r.d);
            usleep(50000);
        }
    }

    printf("[BLF] poked %d distinct settings object(s)\n", seenCount);
    printf("[BLF] done\n");

done:
    destroy_remote_call();
}