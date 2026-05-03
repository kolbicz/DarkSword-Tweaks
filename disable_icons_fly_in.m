// Removes the icon fly-in animation shown after unlocking the phone.

void disable_icons_fly_in(void)
{
    init_remote_call("SpringBoard", false);
    printf("[FLYIN] cranking spring to overdamped-instant\n");

    uint64_t selShared = remote_sel("sharedInstance");
    uint64_t selClass  = remote_sel("class");
    printf("[FLYIN] selectors registered\n");
    usleep(100000);

    uint64_t cls = remote_getClass("SBCoverSheetPresentationManager");
    if (!cls) { printf("[FLYIN] mgr class not found\n"); goto done; }
    usleep(50000);

    uint64_t mgr = remote_msg(cls, selShared, 0,0,0,0);
    if (!mgr) goto done;
    printf("[FLYIN] mgr=0x%llx\n", mgr);
    usleep(50000);

    uint64_t mgrCls = remote_msg(mgr, selClass, 0,0,0,0);
    usleep(50000);

    // Spring physics: very high tension + very high friction + max damping
    // => critically/over-damped, settles in one frame, no bounce.
    poke_double_ivar(mgr, mgrCls, "_iconFlyInTension",                1.0e6);
    poke_double_ivar(mgr, mgrCls, "_iconFlyInFriction",               1.0e6);
    poke_double_ivar(mgr, mgrCls, "_iconFlyInInteractiveResponseMin", 0.0001);
    poke_double_ivar(mgr, mgrCls, "_iconFlyInInteractiveResponseMax", 0.0001);
    poke_double_ivar(mgr, mgrCls, "_iconFlyInInteractiveDampingRatioMin", 1.0);
    poke_double_ivar(mgr, mgrCls, "_iconFlyInInteractiveDampingRatioMax", 1.0);

    printf("[FLYIN] done\n");

done:
    destroy_remote_call();
}