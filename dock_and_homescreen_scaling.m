// Allows custom scaling of Home Screen and Dock icons.
// Usage: homescreen_icon_scale(0.98);
// For the Dock: dock_icon_scale(0.98);

// Update 1: Changes are now applied immediately.

typedef struct {
    double width;
    double height;
    double scale;
    double cornerRadius;
} RC_SBIconImageInfo;

static uint64_t rc_safe_msg(uint64_t obj, const char *selname,
                            uint64_t a, uint64_t b, uint64_t c, uint64_t d)
{
    if (!obj) return 0;
    uint64_t sel = remote_sel(selname);
    uint64_t rs  = remote_sel("respondsToSelector:");
    if (!remote_msg(obj, rs, sel, 0,0,0)) return 0;
    return remote_msg(obj, sel, a, b, c, d);
}

// SBApplicationIcon only — widgets/folders assert on forced 60x60.
// All mutation on MAIN THREAD.
static void rc_refresh_icon_view(uint64_t iconView, uint64_t clsInv,
                                 const RC_SBIconImageInfo *info)
{
    if (!iconView) return;
    uint64_t appIconCls = remote_getClass("SBApplicationIcon");
    if (!appIconCls) return;
    uint64_t icon = rc_safe_msg(iconView, "icon", 0,0,0,0);
    if (!icon) return;
    if (!remote_msg(icon, remote_sel("isKindOfClass:"), appIconCls, 0,0,0)) return;

    uint64_t selSig     = remote_sel("methodSignatureForSelector:");
    uint64_t selWithSig = remote_sel("invocationWithMethodSignature:");
    uint64_t selSetTgt  = remote_sel("setTarget:");
    uint64_t selSetSel  = remote_sel("setSelector:");
    uint64_t selSetArg  = remote_sel("setArgument:atIndex:");
    uint64_t selInvoke  = remote_sel("invoke");
    uint64_t selPerform = remote_sel("performSelectorOnMainThread:withObject:waitUntilDone:");
    uint64_t selSetInfo = remote_sel("setIconImageInfo:");
    uint64_t selUpdate  = remote_sel("_updateAfterManualIconImageInfoChangeInvalidatingLayout:");

    // setIconImageInfo: (struct by value)
    uint64_t sig = remote_msg(iconView, selSig, selSetInfo, 0, 0, 0);
    if (sig) {
        uint64_t inv = remote_msg(clsInv, selWithSig, sig, 0, 0, 0);
        if (inv) {
            remote_msg(inv, selSetTgt, iconView, 0, 0, 0);
            remote_msg(inv, selSetSel, selSetInfo, 0, 0, 0);
            uint64_t mem = do_remote_call_stable(5, "calloc", 1, 32, 0,0,0,0,0,0);
            if (mem) {
                remote_write(mem, info, sizeof(*info));
                remote_msg(inv, selSetArg, mem, 2, 0, 0);
                remote_msg(inv, selPerform, selInvoke, 0, 1, 0);
                do_remote_call_stable(5, "free", mem, 0,0,0,0,0,0,0);
            }
        }
    }

    // _updateAfterManualIconImageInfoChangeInvalidatingLayout:YES
    uint64_t sigU = remote_msg(iconView, selSig, selUpdate, 0, 0, 0);
    if (sigU) {
        uint64_t invU = remote_msg(clsInv, selWithSig, sigU, 0, 0, 0);
        if (invU) {
            remote_msg(invU, selSetTgt, iconView, 0, 0, 0);
            remote_msg(invU, selSetSel, selUpdate, 0, 0, 0);
            uint64_t one = do_remote_call_stable(5, "calloc", 1, 8, 0,0,0,0,0,0);
            do_remote_call_stable(5, "memset", one, 1, 1, 0,0,0,0,0);
            remote_msg(invU, selSetArg, one, 2, 0, 0);
            remote_msg(invU, selPerform, selInvoke, 0, 1, 0);
            do_remote_call_stable(5, "free", one, 0,0,0,0,0,0,0);
        }
    }
}

// Iterate list view's existing subviews. iconViewForIcon: vivifies via
// CATransaction and aborts when driven off main thread — don't use it.
static int rc_refresh_list_view(uint64_t listView, uint64_t clsInv,
                                const RC_SBIconImageInfo *info)
{
    if (!listView) return 0;
    uint64_t clsIconView = remote_getClass("SBIconView");
    if (!clsIconView) return 0;

    uint64_t subs = remote_msg(listView, remote_sel("subviews"), 0,0,0,0);
    if (!subs) return 0;
    uint64_t n = remote_msg(subs, remote_sel("count"), 0,0,0,0);
    if (n > 512) n = 512;

    uint64_t selObjAt = remote_sel("objectAtIndex:");
    uint64_t selKind  = remote_sel("isKindOfClass:");
    int touched = 0;
    for (uint64_t i = 0; i < n; i++) {
        uint64_t v = remote_msg(subs, selObjAt, i, 0,0,0);
        if (!v) continue;
        if (!remote_msg(v, selKind, clsIconView, 0,0,0)) continue;
        rc_refresh_icon_view(v, clsInv, info);
        touched++;
        usleep(10000);
    }
    return touched;
}

static int rc_collect_list_views(uint64_t root, uint64_t clsListView,
                                 uint64_t *out, int cap)
{
    if (!root || !clsListView || cap <= 0) return 0;
    uint64_t selSub  = remote_sel("subviews");
    uint64_t selCnt  = remote_sel("count");
    uint64_t selObj  = remote_sel("objectAtIndex:");
    uint64_t selKind = remote_sel("isKindOfClass:");

    enum { QMAX = 4096 };
    static uint64_t q[QMAX];
    int head = 0, tail = 0, found = 0, visited = 0;
    q[tail++] = root;
    while (head < tail && visited < QMAX) {
        uint64_t v = q[head++];
        visited++;
        if (!v) continue;
        if (remote_msg(v, selKind, clsListView, 0,0,0)) {
            if (found < cap) out[found++] = v;
            continue;
        }
        uint64_t subs = remote_msg(v, selSub, 0,0,0,0);
        if (!subs) continue;
        uint64_t cn = remote_msg(subs, selCnt, 0,0,0,0);
        if (cn > 256) cn = 256;
        for (uint64_t i = 0; i < cn && tail < QMAX; i++) {
            uint64_t c = remote_msg(subs, selObj, i, 0,0,0);
            if (c) q[tail++] = c;
        }
    }
    return found;
}

static int rc_collect_from_windows(uint64_t clsListView,
                                   uint64_t *out, int cap)
{
    uint64_t clsApp = remote_getClass("UIApplication");
    if (!clsApp) return 0;
    uint64_t app = rc_safe_msg(clsApp, "sharedApplication", 0,0,0,0);
    if (!app) return 0;

    int n = 0;
    uint64_t wins = rc_safe_msg(app, "windows", 0,0,0,0);
    if (wins) {
        uint64_t wc = remote_msg(wins, remote_sel("count"), 0,0,0,0);
        if (wc > 32) wc = 32;
        for (uint64_t i = 0; i < wc && n < cap; i++) {
            uint64_t w = remote_msg(wins, remote_sel("objectAtIndex:"), i, 0,0,0);
            if (w) n += rc_collect_list_views(w, clsListView, out + n, cap - n);
        }
    }
    if (n == 0) {
        uint64_t kw = rc_safe_msg(app, "keyWindow", 0,0,0,0);
        if (kw) n += rc_collect_list_views(kw, clsListView, out + n, cap - n);
    }
    return n;
}

void homescreen_icon_scale(double scale)
{
    if (scale <= 0.0 || scale > 2.0) return;
    init_remote_call("SpringBoard", false);
    printf("[HSSCALE] scale=%.2f\n", scale);

    uint64_t selShared       = remote_sel("sharedInstance");
    uint64_t selIconMgr      = remote_sel("iconManager");
    uint64_t selListProv     = remote_sel("listLayoutProvider");
    uint64_t selLayoutForLoc = remote_sel("layoutForIconLocation:");
    uint64_t selLayoutCfg    = remote_sel("layoutConfiguration");
    uint64_t selSetIconInfo  = remote_sel("setIconImageInfo:");
    uint64_t selInvoke       = remote_sel("invoke");
    uint64_t selPerform      = remote_sel("performSelectorOnMainThread:withObject:waitUntilDone:");
    uint64_t selSig          = remote_sel("methodSignatureForSelector:");
    uint64_t selWithSig      = remote_sel("invocationWithMethodSignature:");
    uint64_t selSetTgt       = remote_sel("setTarget:");
    uint64_t selSetSel       = remote_sel("setSelector:");
    uint64_t selSetArg       = remote_sel("setArgument:atIndex:");
    usleep(100000);

    uint64_t cls = remote_getClass("SBIconController");
    if (!cls) goto done;
    uint64_t ctrl = remote_msg(cls, selShared, 0,0,0,0);
    if (!ctrl) goto done;
    uint64_t mgr = remote_msg(ctrl, selIconMgr, 0,0,0,0);
    if (!mgr) goto done;
    uint64_t prov = remote_msg(mgr, selListProv, 0,0,0,0);
    if (!prov) goto done;

    uint64_t locCStr = remote_alloc_str("SBIconLocationRoot");
    uint64_t cfstr = do_remote_call_stable(5, "CFStringCreateWithCString",
        0, locCStr, 0x08000100, 0,0,0,0,0);
    do_remote_call_stable(5, "free", locCStr, 0,0,0,0,0,0,0);
    if (!cfstr) goto done;

    uint64_t layout = remote_msg(prov, selLayoutForLoc, cfstr, 0,0,0);
    if (!layout) goto done;
    uint64_t cfg = remote_msg(layout, selLayoutCfg, 0,0,0,0);
    if (!cfg) goto done;

    RC_SBIconImageInfo info;
    info.width        = 60.0 * scale;
    info.height       = 60.0 * scale;
    info.scale        = 2.0;
    info.cornerRadius = 13.5 * scale;

    uint64_t clsInv = remote_getClass("NSInvocation");
    uint64_t sig = remote_msg(cfg, selSig, selSetIconInfo, 0, 0, 0);
    if (!sig) goto done;
    uint64_t inv = remote_msg(clsInv, selWithSig, sig, 0, 0, 0);
    if (!inv) goto done;
    remote_msg(inv, selSetTgt, cfg, 0, 0, 0);
    remote_msg(inv, selSetSel, selSetIconInfo, 0, 0, 0);

    uint64_t mem = do_remote_call_stable(5, "calloc", 1, 32, 0,0,0,0,0,0);
    if (!mem) goto done;
    remote_write(mem, &info, sizeof(info));
    remote_msg(inv, selSetArg, mem, 2, 0, 0);
    remote_msg(inv, selPerform, selInvoke, 0, 1, 0);
    do_remote_call_stable(5, "free", mem, 0,0,0,0,0,0,0);

    // Find live SBIconListViews — window BFS, fallback through mgr.rootFolderController.
    uint64_t clsListView = remote_getClass("SBIconListView");
    enum { LV_CAP = 64 };
    uint64_t lvs[LV_CAP];
    int nlv = rc_collect_from_windows(clsListView, lvs, LV_CAP);
    if (nlv == 0) {
        uint64_t rootFC = rc_safe_msg(mgr, "rootFolderController", 0,0,0,0);
        if (!rootFC) rootFC = rc_safe_msg(mgr, "_rootFolderController", 0,0,0,0);
        if (rootFC) {
            uint64_t rv = rc_safe_msg(rootFC, "view", 0,0,0,0);
            if (rv) nlv = rc_collect_list_views(rv, clsListView, lvs, LV_CAP);
        }
    }
    for (int i = 0; i < nlv; i++) {
        if (rc_safe_msg(lvs[i], "isDock", 0,0,0,0)) continue;  // dock handled separately
        rc_refresh_list_view(lvs[i], clsInv, &info);
    }

done:
    destroy_remote_call();
}

void dock_icon_scale(double scale)
{
    if (scale <= 0.0 || scale > 2.0) return;
    init_remote_call("SpringBoard", false);
    printf("[DOCKSCALE] scale=%.2f\n", scale);

    uint64_t selShared      = remote_sel("sharedInstance");
    uint64_t selIconMgr     = remote_sel("iconManager");
    uint64_t selSetIconInfo = remote_sel("setIconImageInfo:");
    uint64_t selInvoke      = remote_sel("invoke");
    uint64_t selPerform     = remote_sel("performSelectorOnMainThread:withObject:waitUntilDone:");
    uint64_t selSig         = remote_sel("methodSignatureForSelector:");
    uint64_t selWithSig     = remote_sel("invocationWithMethodSignature:");
    uint64_t selSetTgt      = remote_sel("setTarget:");
    uint64_t selSetSel      = remote_sel("setSelector:");
    uint64_t selSetArg      = remote_sel("setArgument:atIndex:");
    usleep(100000);

    uint64_t cls = remote_getClass("SBIconController");
    if (!cls) goto done;
    uint64_t ctrl = remote_msg(cls, selShared, 0,0,0,0);
    if (!ctrl) goto done;
    uint64_t mgr = remote_msg(ctrl, selIconMgr, 0,0,0,0);
    if (!mgr) goto done;

    uint64_t dock = rc_safe_msg(mgr, "dockListView", 0,0,0,0);
    if (!dock) dock = rc_safe_msg(ctrl, "dockListView", 0,0,0,0);
    if (!dock) goto done;

    uint64_t dockLayout = rc_safe_msg(dock, "layout", 0,0,0,0);
    uint64_t dockCfg = dockLayout ? rc_safe_msg(dockLayout, "layoutConfiguration", 0,0,0,0) : 0;

    RC_SBIconImageInfo info;
    info.width        = 60.0 * scale;
    info.height       = 60.0 * scale;
    info.scale        = 2.0;
    info.cornerRadius = 13.5 * scale;

    uint64_t clsInv = remote_getClass("NSInvocation");

    if (dockCfg) {
        uint64_t sig = remote_msg(dockCfg, selSig, selSetIconInfo, 0, 0, 0);
        if (sig) {
            uint64_t inv = remote_msg(clsInv, selWithSig, sig, 0, 0, 0);
            if (inv) {
                remote_msg(inv, selSetTgt, dockCfg, 0, 0, 0);
                remote_msg(inv, selSetSel, selSetIconInfo, 0, 0, 0);
                uint64_t mem = do_remote_call_stable(5, "calloc", 1, 32, 0,0,0,0,0,0);
                if (mem) {
                    remote_write(mem, &info, sizeof(info));
                    remote_msg(inv, selSetArg, mem, 2, 0, 0);
                    remote_msg(inv, selPerform, selInvoke, 0, 1, 0);
                    do_remote_call_stable(5, "free", mem, 0,0,0,0,0,0,0);
                }
            }
        }
    }

    int touched = rc_refresh_list_view(dock, clsInv, &info);
    if (touched == 0) {
        uint64_t clsListView = remote_getClass("SBIconListView");
        enum { LV_CAP = 64 };
        uint64_t lvs[LV_CAP];
        int nlv = rc_collect_from_windows(clsListView, lvs, LV_CAP);
        for (int i = 0; i < nlv; i++)
            if (rc_safe_msg(lvs[i], "isDock", 0,0,0,0))
                rc_refresh_list_view(lvs[i], clsInv, &info);
    }

done:
    destroy_remote_call();
}