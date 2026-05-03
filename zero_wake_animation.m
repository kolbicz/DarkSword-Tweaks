// This tweak removes the screen wake delay/fade and displays the Lock Screen immediately.

void zero_wake_animation(void)
{
    init_remote_call("SpringBoard", false);
    printf("[WAKE] zeroing wake animation\n");

    uint64_t selShared    = remote_sel("sharedInstance");
    uint64_t selClass     = remote_sel("class");
    uint64_t selFetchSet  = remote_sel("_animationSettingsForBacklightChangeSource:isWake:");
    printf("[WAKE] selectors registered\n");
    usleep(100000);

    uint64_t cls = remote_getClass("SBScreenWakeAnimationController");
    if (!cls) { printf("[WAKE] controller class not found\n"); goto done; }
    usleep(50000);

    uint64_t ctrl = remote_msg(cls, selShared, 0,0,0,0);
    if (!ctrl) goto done;
    printf("[WAKE] ctrl=0x%llx\n", ctrl);
    usleep(50000);

    // Fetch with isWake=1, source=0 (any works, they all return the same object)
    uint64_t outer = remote_msg(ctrl, selFetchSet, 0, 1, 0, 0);
    if (!outer) goto done;
    printf("[WAKE] outer settings=0x%llx\n", outer);
    usleep(50000);

    uint64_t outerCls = remote_msg(outer, selClass, 0,0,0,0);
    usleep(50000);

    // --- Outer SBFWakeAnimationSettings ---
    // (Re-zero the backlight fade in case re-init happened, plus crank speed multipliers.)
    poke_double_ivar(outer, outerCls, "_backlightFadeDuration",       0.0);
    poke_double_ivar(outer, outerCls, "_speedMultiplierForWake",      1000.0);
    poke_double_ivar(outer, outerCls, "_speedMultiplierForLiftToWake", 1000.0);

    // --- Walk to _contentWakeSettings (SBFAnimationSettings *) ---
    uint64_t nameMem = remote_alloc_str("_contentWakeSettings");
    uint64_t ivar = do_remote_call_stable(100, "class_getInstanceVariable",
                                           outerCls, nameMem, 0,0,0,0,0,0);
    do_remote_call_stable(5, "free", nameMem, 0,0,0,0,0,0,0);
    if (!ivar) { printf("[WAKE] _contentWakeSettings ivar not found\n"); goto done; }

    uint64_t off = do_remote_call_stable(100, "ivar_getOffset", ivar, 0,0,0,0,0,0,0);
    printf("[WAKE] _contentWakeSettings offset=0x%llx\n", off);

    uint64_t content = 0;
    remote_read(outer + off, &content, sizeof(content));
    printf("[WAKE] _contentWakeSettings = 0x%llx\n", content);
    if (!content) goto done;

    uint64_t contentCls = remote_msg(content, selClass, 0,0,0,0);
    usleep(50000);

    // --- Inner SBFAnimationSettings ---
    // Kill duration, crank speed. Also zero delay so it doesn't wait before snapping.
    poke_double_ivar(content, contentCls, "_duration", 0.0);
    poke_double_ivar(content, contentCls, "_speed",    1000.0);
    poke_double_ivar(content, contentCls, "_delay",    0.0);

    printf("[WAKE] done\n");

done:
    destroy_remote_call();
}