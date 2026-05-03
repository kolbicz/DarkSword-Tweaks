// Adds the double-tap gesture to the Home Screen and Lock Screen.
// This lets you lock the phone by double-tapping the screen.

void double_tap_to_lock(void)
{
    init_remote_call("SpringBoard", false);
    printf("[LOCK] installing double tap\n");
    usleep(100000);

    uint64_t clsSB  = remote_getClass("SpringBoard");
    uint64_t sb     = remote_msg(clsSB, remote_sel("sharedApplication"), 0,0,0,0);
    if (!sb) { printf("[LOCK] no SpringBoard instance\n"); goto done; }
    printf("[LOCK] sb=0x%llx\n", sb);

    uint64_t selLock = remote_sel("_simulateLockButtonPress");
    uint64_t selInit = remote_sel("initWithTarget:action:");
    uint64_t selTaps = remote_sel("setNumberOfTapsRequired:");
    uint64_t selAdd  = remote_sel("addGestureRecognizer:");
    uint64_t selAt   = remote_sel("objectAtIndex:");
    uint64_t clsGR   = remote_getClass("UITapGestureRecognizer");

    // ── 1. Homescreen root folder view ───────────────────────────────────
    uint64_t clsIC  = remote_getClass("SBIconController");
    uint64_t ctrl   = remote_msg(clsIC, remote_sel("sharedInstance"), 0,0,0,0);
    uint64_t mgr    = remote_msg(ctrl, remote_sel("iconManager"), 0,0,0,0);
    uint64_t rootFC = remote_msg(mgr, remote_sel("rootFolderController"), 0,0,0,0);
    uint64_t view   = remote_msg(rootFC, remote_sel("view"), 0,0,0,0);

    if (view) {
        uint64_t gr = remote_msg(clsGR, remote_sel("alloc"), 0,0,0,0);
        gr = remote_msg(gr, selInit, sb, selLock, 0, 0);
        remote_msg(gr, selTaps, 2, 0,0,0);
        remote_msg(view, selAdd, gr, 0,0,0);
        printf("[LOCK] installed on homescreen\n");
    }

    // ── 2. All windows — covers lockscreen, notification center, etc ──────
    uint64_t clsApp  = remote_getClass("UIApplication");
    uint64_t app     = remote_msg(clsApp, remote_sel("sharedApplication"), 0,0,0,0);
    uint64_t windows = app ? remote_msg(app, remote_sel("windows"), 0,0,0,0) : 0;
    uint64_t count   = windows ? remote_msg(windows, remote_sel("count"), 0,0,0,0) : 0;
    uint64_t lim     = count < 20 ? count : 20;
    printf("[LOCK] installing on %llu windows\n", lim);

    for (uint64_t i = 0; i < lim; i++) {
        uint64_t win = remote_msg(windows, selAt, i, 0,0,0);
        if (!win || win == view) continue; // skip homescreen (already done)
        uint64_t gr = remote_msg(clsGR, remote_sel("alloc"), 0,0,0,0);
        gr = remote_msg(gr, selInit, sb, selLock, 0, 0);
        remote_msg(gr, selTaps, 2, 0,0,0);
        remote_msg(win, selAdd, gr, 0,0,0);
    }
    
    printf("[LOCK] installed on all windows\n");

done:
    destroy_remote_call();
}