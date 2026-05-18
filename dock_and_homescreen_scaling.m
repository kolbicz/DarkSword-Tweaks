// Allows custom scaling of Home Screen and Dock icons.
// Usage: homescreen_icon_scale(0.98);
// For the Dock: dock_icon_scale(0.98);

// Since we cannot respring, you may need to scroll through the Home Screen pages and enter Home Screen editing mode for the changes to apply.

typedef struct {
    double width;
    double height;
    double scale;
    double cornerRadius;
} RC_SBIconImageInfo;

void homescreen_icon_scale(double scale)
{
    if (scale <= 0.0 || scale > 2.0) {
        printf("[HSSCALE] scale %.2f out of range\n", scale);
        return;
    }

    init_remote_call("SpringBoard", false);
    printf("[HSSCALE] scaling root icons to %.2f\n", scale);

    uint64_t selShared       = remote_sel("sharedInstance");
    uint64_t selIconMgr      = remote_sel("iconManager");
    uint64_t selListProv     = remote_sel("listLayoutProvider");
    uint64_t selLayoutForLoc = remote_sel("layoutForIconLocation:");
    uint64_t selLayoutCfg    = remote_sel("layoutConfiguration");
    uint64_t selRootFolder   = remote_sel("rootFolderController");
    uint64_t selForceRelayout= remote_sel("layoutIconListsWithAnimationType:forceRelayout:");
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
    if (!prov) { printf("[HSSCALE] no listLayoutProvider\n"); goto done; }

    uint64_t locCStr = remote_alloc_str("SBIconLocationRoot");
    uint64_t cfstr = do_remote_call_stable(5, "CFStringCreateWithCString",
        0, locCStr, 0x08000100, 0,0,0,0,0);
    do_remote_call_stable(5, "free", locCStr, 0,0,0,0,0,0,0);
    if (!cfstr) goto done;

    uint64_t layout = remote_msg(prov, selLayoutForLoc, cfstr, 0,0,0);
    if (!layout) { printf("[HSSCALE] no layout\n"); goto done; }
    uint64_t cfg = remote_msg(layout, selLayoutCfg, 0,0,0,0);
    if (!cfg) { printf("[HSSCALE] no cfg\n"); goto done; }
    printf("[HSSCALE] root cfg=0x%llx\n", cfg);
    usleep(50000);

    RC_SBIconImageInfo info;
    info.width        = 60.0 * scale;
    info.height       = 60.0 * scale;
    info.scale        = 2.0;
    info.cornerRadius = 13.5 * scale;
    printf("[HSSCALE] new size: %.2fx%.2f scale=%.2f radius=%.2f\n",
           info.width, info.height, info.scale, info.cornerRadius);

    uint64_t clsInv = remote_getClass("NSInvocation");
    uint64_t sig = remote_msg(cfg, selSig, selSetIconInfo, 0, 0, 0);
    if (!sig) goto done;
    uint64_t inv = remote_msg(clsInv, selWithSig, sig, 0, 0, 0);
    if (!inv) goto done;
    remote_msg(inv, selSetTgt, cfg, 0, 0, 0);
    remote_msg(inv, selSetSel, selSetIconInfo, 0, 0, 0);

    uint64_t structMem = do_remote_call_stable(5, "calloc", 1, 32, 0,0,0,0,0,0);
    if (!structMem) goto done;
    remote_write(structMem, &info, sizeof(info));
    remote_msg(inv, selSetArg, structMem, 2, 0, 0);
    remote_msg(inv, selPerform, selInvoke, 0, 1, 0);
    printf("[HSSCALE] setIconImageInfo: dispatched\n");
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
                    printf("[HSSCALE] root relayout dispatched\n");
                }
            }
        }
    }

    printf("[HSSCALE] done\n");
done:
    destroy_remote_call();
}

void dock_icon_scale(double scale)
{
    if (scale <= 0.0 || scale > 2.0) {
        printf("[DOCKSCALE] scale %.2f out of range\n", scale);
        return;
    }

    init_remote_call("SpringBoard", false);
    printf("[DOCKSCALE] scaling dock icons to %.2f\n", scale);

    uint64_t selShared       = remote_sel("sharedInstance");
    uint64_t selIconMgr      = remote_sel("iconManager");
    uint64_t selDockView     = remote_sel("dockListView");
    uint64_t selLayout       = remote_sel("layout");
    uint64_t selLayoutCfg    = remote_sel("layoutConfiguration");
    uint64_t selSetIconInfo  = remote_sel("setIconImageInfo:");
    uint64_t selSetNeeds     = remote_sel("setNeedsLayout");
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

    uint64_t dock = remote_msg(mgr, selDockView, 0,0,0,0);
    if (!dock) dock = remote_msg(ctrl, selDockView, 0,0,0,0);
    if (!dock) { printf("[DOCKSCALE] no dock\n"); goto done; }
    printf("[DOCKSCALE] dock=0x%llx\n", dock);
    usleep(50000);

    uint64_t dockLayout = remote_msg(dock, selLayout, 0,0,0,0);
    if (!dockLayout) { printf("[DOCKSCALE] no dock layout\n"); goto done; }
    uint64_t dockCfg = remote_msg(dockLayout, selLayoutCfg, 0,0,0,0);
    if (!dockCfg) { printf("[DOCKSCALE] no dock cfg\n"); goto done; }
    printf("[DOCKSCALE] dock cfg=0x%llx\n", dockCfg);
    usleep(50000);

    RC_SBIconImageInfo info;
    info.width        = 60.0 * scale;
    info.height       = 60.0 * scale;
    info.scale        = 2.0;
    info.cornerRadius = 13.5 * scale;
    printf("[DOCKSCALE] new size: %.2fx%.2f scale=%.2f radius=%.2f\n",
           info.width, info.height, info.scale, info.cornerRadius);

    uint64_t clsInv = remote_getClass("NSInvocation");
    uint64_t sig = remote_msg(dockCfg, selSig, selSetIconInfo, 0, 0, 0);
    if (!sig) goto done;
    uint64_t inv = remote_msg(clsInv, selWithSig, sig, 0, 0, 0);
    if (!inv) goto done;
    remote_msg(inv, selSetTgt, dockCfg, 0, 0, 0);
    remote_msg(inv, selSetSel, selSetIconInfo, 0, 0, 0);

    uint64_t structMem = do_remote_call_stable(5, "calloc", 1, 32, 0,0,0,0,0,0);
    if (!structMem) goto done;
    remote_write(structMem, &info, sizeof(info));
    remote_msg(inv, selSetArg, structMem, 2, 0, 0);
    remote_msg(inv, selPerform, selInvoke, 0, 1, 0);
    printf("[DOCKSCALE] setIconImageInfo: dispatched\n");
    do_remote_call_stable(5, "free", structMem, 0,0,0,0,0,0,0);
    usleep(50000);

    remote_msg(dock, selPerform, selSetNeeds, 0, 0, 0);
    printf("[DOCKSCALE] setNeedsLayout dispatched\n");

    printf("[DOCKSCALE] done\n");
done:
    destroy_remote_call();
}