// Allows custom spacing for the Dock or Home Screen.
// Example: homescreen_spacing(20, 20, 50, 170); (Pro Max)
// For the Dock: dock_spacing(30);

// Since we cannot respring, you may need to scroll through the Home Screen pages and enter Home Screen editing mode for the changes to apply.

typedef struct {
    double top;
    double left;
    double bottom;
    double right;
} RC_UIEdgeInsets;

void dock_spacing(double extraHorizontalInset)
{
    init_remote_call("SpringBoard", false);
    printf("[DOCKSPACE] adding %.2f horizontal inset to dock\n", extraHorizontalInset);

    uint64_t selShared       = remote_sel("sharedInstance");
    uint64_t selIconMgr      = remote_sel("iconManager");
    uint64_t selDockView     = remote_sel("dockListView");
    uint64_t selLayout       = remote_sel("layout");
    uint64_t selLayoutCfg    = remote_sel("layoutConfiguration");
    uint64_t selSetInsets    = remote_sel("setPortraitLayoutInsets:");
    uint64_t selPortraitIns  = remote_sel("portraitLayoutInsets");
    uint64_t selSetNeeds     = remote_sel("setNeedsLayout");
    uint64_t selPerform      = remote_sel("performSelectorOnMainThread:withObject:waitUntilDone:");
    uint64_t selSig          = remote_sel("methodSignatureForSelector:");
    uint64_t selWithSig      = remote_sel("invocationWithMethodSignature:");
    uint64_t selSetTgt       = remote_sel("setTarget:");
    uint64_t selSetSel       = remote_sel("setSelector:");
    uint64_t selSetArg       = remote_sel("setArgument:atIndex:");
    uint64_t selInvoke       = remote_sel("invoke");
    usleep(100000);

    uint64_t cls = remote_getClass("SBIconController");
    if (!cls) goto done;
    uint64_t ctrl = remote_msg(cls, selShared, 0,0,0,0);
    if (!ctrl) goto done;
    uint64_t mgr = remote_msg(ctrl, selIconMgr, 0,0,0,0);
    if (!mgr) goto done;

    uint64_t dock = remote_msg(mgr, selDockView, 0,0,0,0);
    if (!dock) dock = remote_msg(ctrl, selDockView, 0,0,0,0);
    if (!dock) { printf("[DOCKSPACE] no dock\n"); goto done; }

    uint64_t dockLayout = remote_msg(dock, selLayout, 0,0,0,0);
    if (!dockLayout) goto done;
    uint64_t dockCfg = remote_msg(dockLayout, selLayoutCfg, 0,0,0,0);
    if (!dockCfg) goto done;
    printf("[DOCKSPACE] dock cfg=0x%llx\n", dockCfg);
    usleep(50000);

    // Build new insets — start from defaults, add extra horizontal
    // Typical iPhone dock portrait insets: small top/bottom, ~16-30 left/right
    // Read current insets via ivar would be ideal; simpler to set known values
    RC_UIEdgeInsets newInsets;
    newInsets.top    = 0.0;
    newInsets.left   = 16.0 + extraHorizontalInset;   // default + extra
    newInsets.bottom = 0.0;
    newInsets.right  = 16.0 + extraHorizontalInset;
    printf("[DOCKSPACE] new insets: top=%.2f left=%.2f bottom=%.2f right=%.2f\n",
           newInsets.top, newInsets.left, newInsets.bottom, newInsets.right);

    uint64_t clsInv = remote_getClass("NSInvocation");
    uint64_t sig = remote_msg(dockCfg, selSig, selSetInsets, 0, 0, 0);
    if (!sig) { printf("[DOCKSPACE] no sig\n"); goto done; }
    uint64_t inv = remote_msg(clsInv, selWithSig, sig, 0, 0, 0);
    if (!inv) goto done;

    remote_msg(inv, selSetTgt, dockCfg, 0, 0, 0);
    remote_msg(inv, selSetSel, selSetInsets, 0, 0, 0);

    uint64_t structMem = do_remote_call_stable(5, "calloc", 1, 32, 0,0,0,0,0,0);
    if (!structMem) goto done;
    remote_write(structMem, &newInsets, sizeof(newInsets));
    remote_msg(inv, selSetArg, structMem, 2, 0, 0);
    remote_msg(inv, selPerform, selInvoke, 0, 1, 0);
    printf("[DOCKSPACE] setPortraitLayoutInsets: dispatched\n");
    do_remote_call_stable(5, "free", structMem, 0,0,0,0,0,0,0);
    usleep(50000);

    // Force dock relayout
    remote_msg(dock, selPerform, selSetNeeds, 0, 0, 0);
    printf("[DOCKSPACE] setNeedsLayout dispatched\n");

done:
    destroy_remote_call();
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
    uint64_t selRootFolder   = remote_sel("rootFolderController");
    uint64_t selForceRelayout= remote_sel("layoutIconListsWithAnimationType:forceRelayout:");
    uint64_t selPerform      = remote_sel("performSelectorOnMainThread:withObject:waitUntilDone:");
    uint64_t selSig          = remote_sel("methodSignatureForSelector:");
    uint64_t selWithSig      = remote_sel("invocationWithMethodSignature:");
    uint64_t selSetTgt       = remote_sel("setTarget:");
    uint64_t selSetSel       = remote_sel("setSelector:");
    uint64_t selSetArg       = remote_sel("setArgument:atIndex:");
    uint64_t selInvoke       = remote_sel("invoke");
    usleep(100000);

    uint64_t cls = remote_getClass("SBIconController");
    if (!cls) goto done;
    uint64_t ctrl = remote_msg(cls, selShared, 0,0,0,0);
    if (!ctrl) goto done;
    uint64_t mgr = remote_msg(ctrl, selIconMgr, 0,0,0,0);
    if (!mgr) goto done;
    uint64_t prov = remote_msg(mgr, selListProv, 0,0,0,0);
    if (!prov) { printf("[HSSPACE] no listLayoutProvider\n"); goto done; }

    uint64_t locCStr = remote_alloc_str("SBIconLocationRoot");
    uint64_t cfstr = do_remote_call_stable(5, "CFStringCreateWithCString",
        0, locCStr, 0x08000100, 0,0,0,0,0);
    do_remote_call_stable(5, "free", locCStr, 0,0,0,0,0,0,0);
    if (!cfstr) goto done;

    uint64_t layout = remote_msg(prov, selLayoutForLoc, cfstr, 0,0,0);
    if (!layout) { printf("[HSSPACE] no layout\n"); goto done; }
    uint64_t cfg = remote_msg(layout, selLayoutCfg, 0,0,0,0);
    if (!cfg) { printf("[HSSPACE] no cfg\n"); goto done; }
    printf("[HSSPACE] root cfg=0x%llx\n", cfg);
    usleep(50000);

    // Defaults for iPhone 16 Pro Max homescreen, plus per-edge deltas
    RC_UIEdgeInsets newInsets;
    newInsets.top    = 60.0  + extraTop;
    newInsets.left   = 27.0  + extraLeft;
    newInsets.bottom = 100.0 + extraBottom;
    newInsets.right  = 27.0  + extraRight;
    printf("[HSSPACE] new insets: top=%.2f left=%.2f bottom=%.2f right=%.2f\n",
           newInsets.top, newInsets.left, newInsets.bottom, newInsets.right);

    uint64_t clsInv = remote_getClass("NSInvocation");
    uint64_t sig = remote_msg(cfg, selSig, selSetInsets, 0, 0, 0);
    if (!sig) goto done;
    uint64_t inv = remote_msg(clsInv, selWithSig, sig, 0, 0, 0);
    if (!inv) goto done;
    remote_msg(inv, selSetTgt, cfg, 0, 0, 0);
    remote_msg(inv, selSetSel, selSetInsets, 0, 0, 0);

    uint64_t structMem = do_remote_call_stable(5, "calloc", 1, 32, 0,0,0,0,0,0);
    if (!structMem) goto done;
    remote_write(structMem, &newInsets, sizeof(newInsets));
    remote_msg(inv, selSetArg, structMem, 2, 0, 0);
    remote_msg(inv, selPerform, selInvoke, 0, 1, 0);
    printf("[HSSPACE] setPortraitLayoutInsets: dispatched\n");
    do_remote_call_stable(5, "free", structMem, 0,0,0,0,0,0,0);
    usleep(50000);

    // Force root relayout
    {
        uint64_t rootFolder = remote_msg(mgr, selRootFolder, 0,0,0,0);
        if (rootFolder) {
            uint64_t sigR = remote_msg(rootFolder, selSig, selForceRelayout, 0,0,0);
            if (sigR) {
                uint64_t invR = remote_msg(clsInv, selWithSig, sigR, 0,0,0);
                if (invR) {
                    remote_msg(invR, selSetTgt, rootFolder, 0,0,0);
                    remote_msg(invR, selSetSel, selForceRelayout, 0,0,0);

                    uint64_t zeroMem = do_remote_call_stable(5, "calloc", 1, 8, 0,0,0,0,0,0);
                    uint64_t oneMem  = do_remote_call_stable(5, "calloc", 1, 8, 0,0,0,0,0,0);
                    do_remote_call_stable(5, "memset", oneMem, 1, 1, 0,0,0,0,0);

                    remote_msg(invR, selSetArg, zeroMem, 2, 0,0);
                    remote_msg(invR, selSetArg, oneMem,  3, 0,0);
                    remote_msg(invR, selPerform, selInvoke, 0, 1, 0);

                    do_remote_call_stable(5, "free", zeroMem, 0,0,0,0,0,0,0);
                    do_remote_call_stable(5, "free", oneMem,  0,0,0,0,0,0,0);
                    printf("[HSSPACE] relayout dispatched\n");
                }
            }
        }
    }

    printf("[HSSPACE] done\n");
done:
    destroy_remote_call();
}