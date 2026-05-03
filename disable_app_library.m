// This tweak disables the last Home Screen page, also known as the App Library.
// It may glitch until you swipe the Home Screen a few times.

void disable_app_library(void)
{
    init_remote_call("SpringBoard", false);
    printf("[APPLIB] disabling app library\n");

    uint64_t selShared   = remote_sel("sharedInstance");
    uint64_t selClass    = remote_sel("class");
    uint64_t selIconMgr  = remote_sel("iconManager");
    uint64_t selRootFC   = remote_sel("rootFolderController");
    uint64_t selRootView = remote_sel("rootFolderView");
    uint64_t selArray    = remote_sel("array");
    printf("[APPLIB] selectors registered\n");
    usleep(100000);

    uint64_t clsNSArray = remote_getClass("NSArray");
    uint64_t emptyArr   = remote_msg(clsNSArray, selArray, 0,0,0,0);
    if (!emptyArr) { printf("[APPLIB] [NSArray array] failed\n"); goto done; }
    printf("[APPLIB] emptyArr=0x%llx\n", emptyArr);
    usleep(50000);

    uint64_t clsIC = remote_getClass("SBIconController");
    if (!clsIC) goto done;
    uint64_t ctrl = remote_msg(clsIC, selShared, 0,0,0,0);
    if (!ctrl) goto done;
    usleep(50000);

    uint64_t mgr = remote_msg(ctrl, selIconMgr, 0,0,0,0);
    if (!mgr) goto done;
    usleep(50000);

    uint64_t rootFC = remote_msg(mgr, selRootFC, 0,0,0,0);
    if (!rootFC) goto done;
    printf("[APPLIB] rootFC=0x%llx\n", rootFC);
    usleep(50000);

    uint64_t rootFCCls = remote_msg(rootFC, selClass, 0,0,0,0);
    usleep(50000);

    poke_pointer_ivar(rootFC, rootFCCls, "_trailingCustomViewControllers", emptyArr);

    uint64_t rootView = remote_msg(rootFC, selRootView, 0,0,0,0);
    if (rootView) {
        printf("[APPLIB] rootView=0x%llx\n", rootView);
        usleep(50000);
        uint64_t rootViewCls = remote_msg(rootView, selClass, 0,0,0,0);
        usleep(50000);
        poke_pointer_ivar(rootView, rootViewCls, "_trailingCustomViewControllers", emptyArr);
    } else {
        printf("[APPLIB] rootFolderView nil — may not yet be loaded\n");
    }

    printf("[APPLIB] done\n");

done:
    destroy_remote_call();
}