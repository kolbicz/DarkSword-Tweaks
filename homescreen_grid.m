// Allows a custom grid layout on the Home Screen
// This may glitch if you have the default widgets on the Home Screen

// Update 1: The maximum number of icons is now properly honored

void homescreen_grid(int hs_cols, int hs_rows)
{
    init_remote_call("SpringBoard", false);
    printf("[HSGRID] cols=%d rows=%d\n", hs_cols, hs_rows);

    uint64_t selShared       = remote_sel("sharedInstance");
    uint64_t selIconMgr      = remote_sel("iconManager");
    uint64_t selListProv     = remote_sel("listLayoutProvider");
    uint64_t selLayoutForLoc = remote_sel("layoutForIconLocation:");
    uint64_t selLayoutCfg    = remote_sel("layoutConfiguration");
    uint64_t selSetCols      = remote_sel("setNumberOfPortraitColumns:");
    uint64_t selSetRows      = remote_sel("setNumberOfPortraitRows:");
    uint64_t selRootFolder   = remote_sel("rootFolderController");
    uint64_t selFolder       = remote_sel("folder");
    uint64_t selLists        = remote_sel("lists");
    uint64_t selCount        = remote_sel("count");
    uint64_t selObjAtIdx     = remote_sel("objectAtIndex:");
    uint64_t selSetGridSize  = remote_sel("setGridSize:");
    uint64_t selForceRelayout= remote_sel("layoutIconListsWithAnimationType:forceRelayout:");
    uint64_t selInvoke       = remote_sel("invoke");
    uint64_t selPerform      = remote_sel("performSelectorOnMainThread:withObject:waitUntilDone:");
    usleep(100000);

    uint64_t cls = remote_getClass("SBIconController");
    if (!cls) { printf("[HSGRID] no SBIconController\n"); goto done; }
    uint64_t ctrl = remote_msg(cls, selShared, 0,0,0,0);
    if (!ctrl) goto done;
    uint64_t mgr = remote_msg(ctrl, selIconMgr, 0,0,0,0);
    if (!mgr) goto done;
    uint64_t prov = remote_msg(mgr, selListProv, 0,0,0,0);
    if (!prov) goto done;

    // ─── 1. Update layout configuration (visual layout) ───
    uint64_t locCStr = remote_alloc_str("SBIconLocationRoot");
    uint64_t cfstr = do_remote_call_stable(5, "CFStringCreateWithCString",
        0, locCStr, 0x08000100, 0,0,0,0,0);
    do_remote_call_stable(5, "free", locCStr, 0,0,0,0,0,0,0);
    if (!cfstr) goto done;

    uint64_t layout = remote_msg(prov, selLayoutForLoc, cfstr, 0,0,0);
    if (!layout) goto done;
    uint64_t cfg = remote_msg(layout, selLayoutCfg, 0,0,0,0);
    if (!cfg) goto done;
    printf("[HSGRID] cfg=0x%llx\n", cfg);
    usleep(50000);

    remote_msg(cfg, selSetCols, (uint64_t)hs_cols, 0,0,0);
    printf("[HSGRID] cols -> %d\n", hs_cols);
    usleep(50000);

    remote_msg(cfg, selSetRows, (uint64_t)hs_rows, 0,0,0);
    printf("[HSGRID] rows -> %d\n", hs_rows);
    usleep(50000);

    // ─── 2. Update gridSize on each page's list model ───
    // gridSize encoding: low 16 bits = cols, high 16 bits = rows (same as five_icon_dock)
    uint64_t rootFolderCtrl = remote_msg(mgr, selRootFolder, 0,0,0,0);
    if (!rootFolderCtrl) { printf("[HSGRID] no rootFolderController\n"); goto skipModel; }

    uint64_t rootFolder = remote_msg(rootFolderCtrl, selFolder, 0,0,0,0);
    if (!rootFolder) { printf("[HSGRID] no rootFolder\n"); goto skipModel; }

    uint64_t lists = remote_msg(rootFolder, selLists, 0,0,0,0);
    if (!lists) { printf("[HSGRID] no lists\n"); goto skipModel; }

    uint64_t pageCount = remote_msg(lists, selCount, 0,0,0,0);
    printf("[HSGRID] %llu home screen pages\n", pageCount);
    if (pageCount > 64) pageCount = 64;

    uint64_t newGrid = ((uint64_t)hs_rows << 16) | (uint64_t)hs_cols;
    printf("[HSGRID] new gridSize per page = 0x%llx\n", newGrid);

    for (uint64_t i = 0; i < pageCount; i++) {
        uint64_t listModel = remote_msg(lists, selObjAtIdx, i, 0,0,0);
        if (!listModel) continue;
        remote_msg(listModel, selSetGridSize, newGrid, 0,0,0);
        printf("[HSGRID]   page[%llu]=0x%llx gridSize -> 0x%llx\n", i, listModel, newGrid);
        usleep(20000);
    }
skipModel:

    // ─── 3. Force relayout ───
    {
        uint64_t clsInv  = remote_getClass("NSInvocation");
        uint64_t selSig  = remote_sel("methodSignatureForSelector:");
        uint64_t selWithSig = remote_sel("invocationWithMethodSignature:");
        uint64_t selSetTgt  = remote_sel("setTarget:");
        uint64_t selSetSel  = remote_sel("setSelector:");
        uint64_t selSetArg  = remote_sel("setArgument:atIndex:");

        uint64_t sig = remote_msg(rootFolderCtrl, selSig, selForceRelayout, 0,0,0);
        if (sig) {
            uint64_t inv = remote_msg(clsInv, selWithSig, sig, 0,0,0);
            if (inv) {
                remote_msg(inv, selSetTgt, rootFolderCtrl, 0,0,0);
                remote_msg(inv, selSetSel, selForceRelayout, 0,0,0);

                uint64_t zeroMem = do_remote_call_stable(5, "calloc", 1, 8, 0,0,0,0,0,0);
                uint64_t oneMem  = do_remote_call_stable(5, "calloc", 1, 8, 0,0,0,0,0,0);
                do_remote_call_stable(5, "memset", oneMem, 1, 1, 0,0,0,0,0);

                remote_msg(inv, selSetArg, zeroMem, 2, 0,0);
                remote_msg(inv, selSetArg, oneMem,  3, 0,0);
                remote_msg(inv, selPerform, selInvoke, 0, 1, 0);
                printf("[HSGRID] forced relayout dispatched\n");

                do_remote_call_stable(5, "free", zeroMem, 0,0,0,0,0,0,0);
                do_remote_call_stable(5, "free", oneMem,  0,0,0,0,0,0,0);
            }
        }
    }

    printf("[HSGRID] done\n");

done:
    destroy_remote_call();
}