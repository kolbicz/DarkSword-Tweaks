// This tweak removes the OTA daemons from disabled.plist.
// A reboot is required.

void enable_ota(void) {
    printf("[ota] === ENABLING OTA ===\n");

    const char *plistPath = "/var/db/com.apple.xpc.launchd/disabled.plist";

    if (init_remote_call("launchd", false) != 0) {
        printf("[ota] failed to init remote call\n");
        return;
    }

    uint64_t fileBuf = do_remote_call_stable(1000, "mmap",
        0, 65536, VM_PROT_READ | VM_PROT_WRITE,
        MAP_PRIVATE | MAP_ANON, (uint64_t)-1, 0, 0, 0);

    if (!fileBuf) {
        printf("[ota] mmap failed\n");
        destroy_remote_call();
        return;
    }

    remote_write(g_RC_trojanMem, plistPath, strlen(plistPath) + 1);
    uint64_t fd = do_remote_call_stable(1000, "open",
        g_RC_trojanMem, 0, 0, 0, 0, 0, 0, 0);

    NSMutableDictionary *plist = [NSMutableDictionary dictionary];

    if ((int64_t)fd >= 0) {
        uint64_t bytesRead = do_remote_call_stable(1000, "read",
            fd, fileBuf, 65536, 0, 0, 0, 0, 0);
        do_remote_call_stable(1000, "close", fd, 0, 0, 0, 0, 0, 0, 0);
        if ((int64_t)bytesRead > 0) {
            uint8_t *buf = malloc((size_t)bytesRead);
            remote_read(fileBuf, buf, bytesRead);
            NSData *data = [NSData dataWithBytes:buf length:(NSUInteger)bytesRead];
            free(buf);
            NSMutableDictionary *existing = [[NSPropertyListSerialization
                propertyListWithData:data
                options:NSPropertyListMutableContainersAndLeaves
                format:nil error:nil] mutableCopy];
            if (existing) plist = existing;
        }
    }

    NSArray *toReenable = @[
        @"com.apple.mobile.softwareupdated",
        @"com.apple.OTATaskingAgent",
        @"com.apple.softwareupdateservicesd",
        @"com.apple.mobile.NRDUpdated",
    ];

    int removed = 0;
    for (NSString *key in toReenable) {
        if (plist[key]) {
            [plist removeObjectForKey:key];
            printf("[ota] removed: %s\n", key.UTF8String);
            removed++;
        } else {
            printf("[ota] not present: %s\n", key.UTF8String);
        }
    }

    if (removed > 0) {
        NSData *outData = [NSPropertyListSerialization
            dataWithPropertyList:plist
            format:NSPropertyListXMLFormat_v1_0
            options:0 error:nil];

        remote_write(fileBuf, outData.bytes, outData.length);
        remote_write(g_RC_trojanMem, plistPath, strlen(plistPath) + 1);

        uint64_t wfd = do_remote_call_stable(1000, "open",
            g_RC_trojanMem,
            (uint64_t)(O_WRONLY | O_CREAT | O_TRUNC),
            0644, 0, 0, 0, 0, 0);

        if ((int64_t)wfd >= 0) {
            uint64_t totalWritten = 0;
            uint64_t remaining = outData.length;
            while (remaining > 0) {
                uint64_t written = do_remote_call_stable(1000, "write",
                    wfd, fileBuf + totalWritten, remaining, 0, 0, 0, 0, 0);
                if ((int64_t)written <= 0) break;
                totalWritten += written;
                remaining -= written;
            }
            do_remote_call_stable(1000, "close", wfd, 0, 0, 0, 0, 0, 0, 0);
            printf("[ota] disabled.plist written (%llu bytes) — reboot to apply\n", totalWritten);
        } else {
            printf("[ota] disabled.plist write failed\n");
        }
    } else {
        printf("[ota] nothing to remove\n");
    }

    do_remote_call_stable(1000, "munmap", fileBuf, 65536, 0, 0, 0, 0, 0, 0);
    destroy_remote_call();
    printf("[ota] === OTA ENABLED (reboot required) ===\n");
}