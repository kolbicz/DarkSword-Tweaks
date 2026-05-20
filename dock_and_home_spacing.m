// Allows custom spacing for the Dock or Home Screen.
// Example: homescreen_spacing(20, 20, 50, 170); (Pro Max)
// For the Dock: dock_spacing(30);

// Update 1: Changes are now applied immediately.

typedef struct {
    double top;
    double left;
    double bottom;
    double right;
} RC_UIEdgeInsets;

static uint64_t rc_safe_msg(uint64_t obj, const char *selname,
                            uint64_t a, uint64_t b, uint64_t c, uint64_t d)
{
    if (!obj) return 0;
    uint64_t sel = remote_sel(selname);
    uint64_t rs  = remote_sel("respondsToSelector:");
    if (!remote_msg(obj, rs, sel, 0,0,0)) return 0;
    return remote_msg(obj, sel, a, b, c, d);
}

static void rc_force_manager_relayout(uint64_t mgr, uint64_t clsInv)
{
    if (!mgr) return;

    uint64_t selSig     = remote_sel("methodSignatureForSelector:");
    uint64_t selWithSig = remote_sel("invocationWithMethodSignature:");
    uint64_t selSetTgt  = remote_sel("setTarget:");
    uint64_t selSetSel  = remote_sel("setSelector:");
    uint64_t selSetArg  = remote_sel("setArgument:atIndex:");
    uint64_t selInvoke  = remote_sel("invoke");
    uint64_t selPerform = remote_sel("performSelectorOnMainThread:withObject:waitUntilDone:");

    // setNeedsRelayout:YES
    {
        uint64_t selSNR = remote_sel("setNeedsRelayout:");
        uint64_t sig = remote_msg(mgr, selSig, selSNR, 0,0,0);
        if (sig) {
            uint64_t inv = remote_msg(clsInv, selWithSig, sig, 0,0,0);
            if (inv) {
                remote_msg(inv, selSetTgt, mgr, 0,0,0);
                remote_msg(inv, selSetSel, selSNR, 0,0,0);
                uint64_t one = do_remote_call_stable(5, "calloc", 1, 8, 0,0,0,0,0,0);
                do_remote_call_stable(5, "memset", one, 1, 1, 0,0,0,0,0);
                remote_msg(inv, selSetArg, one, 2, 0, 0);
                remote_msg(inv, selPerform, selInvoke, 0, 1, 0);
                do_remote_call_stable(5, "free", one, 0,0,0,0,0,0,0);
            }
        }
    }

    // relayout (guarded: performSelectorOnMainThread: would abort if unknown)
    {
        uint64_t selR = remote_sel("relayout");
        if (remote_msg(mgr, remote_sel("respondsToSelector:"), selR, 0,0,0))
            remote_msg(mgr, selPerform, selR, 0, 1, 0);
    }

    // layoutIconListsWithAnimationType:0 forceRelayout:YES
    {
        uint64_t selLI = remote_sel("layoutIconListsWithAnimationType:forceRelayout:");
        uint64_t sig = remote_msg(mgr, selSig, selLI, 0,0,0);
        if (sig) {
            uint64_t inv = remote_msg(clsInv, selWithSig, sig, 0,0,0);
            if (inv) {
                remote_msg(inv, selSetTgt, mgr, 0,0,0);
                remote_msg(inv, selSetSel, selLI, 0,0,0);
                uint64_t typeMem  = do_remote_call_stable(5, "calloc", 1, 8, 0,0,0,0,0,0);
                uint64_t forceMem = do_remote_call_stable(5, "calloc", 1, 8, 0,0,0,0,0,0);
                do_remote_call_stable(5, "memset", forceMem, 1, 1, 0,0,0,0,0);
                remote_msg(inv, selSetArg, typeMem,  2, 0, 0);
                remote_msg(inv, selSetArg, forceMem, 3, 0, 0);
                remote_msg(inv, selPerform, selInvoke, 0, 1, 0);
                do_remote_call_stable(5, "free", typeMem,  0,0,0,0,0,0,0);
                do_remote_call_stable(5, "free", forceMem, 0,0,0,0,0,0,0);
            }
        }
    }
}

void homescreen_spacing(double extraLeft, double extraRight,
                         double extraTop, double extraBottom)
{
    init_remote_call("SpringBoard", false);
    printf("[HSSPACE] left=%.2f right=%.2f top=%.2f bottom=%.2f\n",
           extraLeft, extraRight, extraTop, extraBottom);

    uint64_t selShared       = remote_sel("sharedInstance");
    uint64_t selIconMgr      = remote_sel("iconManager");
    uint64_t selListProv     = remote_sel("listLayoutProvider");
    uint64_t selLayoutForLoc = remote_sel("layoutForIconLocation:");
    uint64_t selLayoutCfg    = remote_sel("layoutConfiguration");
    uint64_t selSetInsets    = remote_sel("setPortraitLayoutInsets:");
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

    RC_UIEdgeInsets newInsets;
    newInsets.top    = 60.0  + extraTop;
    newInsets.left   = 27.0  + extraLeft;
    newInsets.bottom = 100.0 + extraBottom;
    newInsets.right  = 27.0  + extraRight;

    uint64_t clsInv = remote_getClass("NSInvocation");
    uint64_t sig = remote_msg(cfg, selSig, selSetInsets, 0, 0, 0);
    if (!sig) goto done;
    uint64_t inv = remote_msg(clsInv, selWithSig, sig, 0, 0, 0);
    if (!inv) goto done;
    remote_msg(inv, selSetTgt, cfg, 0, 0, 0);
    remote_msg(inv, selSetSel, selSetInsets, 0, 0, 0);

    uint64_t mem = do_remote_call_stable(5, "calloc", 1, 32, 0,0,0,0,0,0);
    if (!mem) goto done;
    remote_write(mem, &newInsets, sizeof(newInsets));
    remote_msg(inv, selSetArg, mem, 2, 0, 0);
    remote_msg(inv, selPerform, selInvoke, 0, 1, 0);
    do_remote_call_stable(5, "free", mem, 0,0,0,0,0,0,0);

    rc_force_manager_relayout(mgr, clsInv);

done:
    destroy_remote_call();
}

void dock_spacing(double extraHorizontalInset)
{
    init_remote_call("SpringBoard", false);
    printf("[DOCKSPACE] adding %.2f horizontal inset\n", extraHorizontalInset);

    uint64_t selShared    = remote_sel("sharedInstance");
    uint64_t selIconMgr   = remote_sel("iconManager");
    uint64_t selSetInsets = remote_sel("setPortraitLayoutInsets:");
    uint64_t selInvoke    = remote_sel("invoke");
    uint64_t selPerform   = remote_sel("performSelectorOnMainThread:withObject:waitUntilDone:");
    uint64_t selSig       = remote_sel("methodSignatureForSelector:");
    uint64_t selWithSig   = remote_sel("invocationWithMethodSignature:");
    uint64_t selSetTgt    = remote_sel("setTarget:");
    uint64_t selSetSel    = remote_sel("setSelector:");
    uint64_t selSetArg    = remote_sel("setArgument:atIndex:");
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
    if (!dockCfg) goto done;

    RC_UIEdgeInsets newInsets;
    newInsets.top    = 0.0;
    newInsets.left   = 16.0 + extraHorizontalInset;
    newInsets.bottom = 0.0;
    newInsets.right  = 16.0 + extraHorizontalInset;

    uint64_t clsInv = remote_getClass("NSInvocation");
    uint64_t sig = remote_msg(dockCfg, selSig, selSetInsets, 0, 0, 0);
    if (!sig) goto done;
    uint64_t inv = remote_msg(clsInv, selWithSig, sig, 0, 0, 0);
    if (!inv) goto done;
    remote_msg(inv, selSetTgt, dockCfg, 0, 0, 0);
    remote_msg(inv, selSetSel, selSetInsets, 0, 0, 0);

    uint64_t mem = do_remote_call_stable(5, "calloc", 1, 32, 0,0,0,0,0,0);
    if (!mem) goto done;
    remote_write(mem, &newInsets, sizeof(newInsets));
    remote_msg(inv, selSetArg, mem, 2, 0, 0);
    remote_msg(inv, selPerform, selInvoke, 0, 1, 0);
    do_remote_call_stable(5, "free", mem, 0,0,0,0,0,0,0);

    rc_force_manager_relayout(mgr, clsInv);

done:
    destroy_remote_call();
}