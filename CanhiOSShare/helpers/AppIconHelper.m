#import "AppIconHelper.h"
#import <objc/runtime.h>
#import <objc/message.h>
#import <dlfcn.h>

static UIImage *iconFromData(NSData *data, CGFloat targetSize) {
    if (!data) return nil;
    UIImage *image = [UIImage imageWithData:data];
    if (!image) return nil;
    if (image.size.width <= targetSize && image.size.height <= targetSize) return image;
    UIGraphicsImageRendererFormat *format = [UIGraphicsImageRendererFormat defaultFormat];
    format.scale = image.scale;
    UIGraphicsImageRenderer *renderer = [[UIGraphicsImageRenderer alloc] initWithSize:CGSizeMake(targetSize, targetSize) format:format];
    return [renderer imageWithActions:^(UIGraphicsImageRendererContext *ctx) {
        [image drawInRect:CGRectMake(0, 0, targetSize, targetSize)];
    }];
}

static UIImage *iconImageFromProxy(id proxy) {
    // Try both int and NSUInteger cast since variant arg type varies by iOS version
    const NSUInteger variants[] = {2, 0, 1, 3, 4, 5, 6, 7, 15};
    NSUInteger variantCount = sizeof(variants) / sizeof(variants[0]);

    // iOS 16+: iconForVariant: returns UIImage directly
    SEL iconVariantSel = NSSelectorFromString(@"iconForVariant:");
    if ([proxy respondsToSelector:iconVariantSel]) {
        for (NSUInteger i = 0; i < variantCount; i++) {
            id img = ((id (*)(id, SEL, NSUInteger))objc_msgSend)(proxy, iconVariantSel, variants[i]);
            if ([img isKindOfClass:[UIImage class]]) return img;
        }
    }

    // Older path: iconDataForVariant: returns NSData
    SEL iconDataSel = NSSelectorFromString(@"iconDataForVariant:");
    if ([proxy respondsToSelector:iconDataSel]) {
        for (NSUInteger i = 0; i < variantCount; i++) {
            id data = ((id (*)(id, SEL, NSUInteger))objc_msgSend)(proxy, iconDataSel, variants[i]);
            if ([data isKindOfClass:[NSData class]] && [data length] > 0)
                return iconFromData(data, 60.0);
        }
    }

    // KVC: iconImage / icon / cachedIcon as UIImage
    for (NSString *key in @[@"iconImage", @"icon", @"cachedIcon", @"_iconImage"]) {
        @try {
            id img = [proxy valueForKey:key];
            if ([img isKindOfClass:[UIImage class]]) return img;
        } @catch (__unused NSException *e) {}
    }

    return nil;
}

// SpringBoardServices IPC: ask SpringBoard for the localized display name.
// SpringBoard caches all installed app names; the IPC is allowed from MHA sandbox.
static NSString *displayNameViaSBS(NSString *bundleID) {
    static void *sbsHandle = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sbsHandle = dlopen(
            "/System/Library/PrivateFrameworks/SpringBoardServices.framework/SpringBoardServices",
            RTLD_LAZY | RTLD_LOCAL
        );
    });
    if (!sbsHandle) return nil;

    // One-argument candidates (bundleID → NSString* name)
    const char *oneArgSymbols[] = {
        "SBSCopyDisplayNameForApplicationIdentifier",
        "SBSLocalizedApplicationNameForDisplayIdentifier",
        "SBSApplicationDisplayNameForIdentifier",
        "SBSCopyLocalizedNameForBundleIdentifier"
    };
    for (int i = 0; i < 4; i++) {
        typedef NSString *(*Fn1)(NSString *);
        Fn1 fn = (Fn1)dlsym(sbsHandle, oneArgSymbols[i]);
        if (!fn) continue;
        NSString *name = fn(bundleID);
        if ([name isKindOfClass:[NSString class]] && name.length > 0 &&
            ![name isEqualToString:bundleID]) return name;
    }

    // Two-argument candidates (bundleID, deploymentTarget → NSString*)
    const char *twoArgSymbols[] = {
        "SBSApplicationDisplayNameForDeploymentTarget",
        "SBSCopyApplicationDisplayNameForDeploymentTarget"
    };
    for (int i = 0; i < 2; i++) {
        typedef NSString *(*Fn2)(NSString *, NSInteger);
        Fn2 fn = (Fn2)dlsym(sbsHandle, twoArgSymbols[i]);
        if (!fn) continue;
        for (NSInteger target = 0; target <= 4; target++) {
            NSString *name = fn(bundleID, target);
            if ([name isKindOfClass:[NSString class]] && name.length > 0 &&
                ![name isEqualToString:bundleID]) return name;
        }
    }
    return nil;
}

static UIImage *iconFromBundleURL(NSURL *bundleURL) {
    if (!bundleURL) return nil;

    // Gather icon file names declared in Info.plist
    NSMutableArray<NSString *> *iconNames = [NSMutableArray array];
    NSURL *infoPlistURL = [bundleURL URLByAppendingPathComponent:@"Info.plist"];
    NSDictionary *infoPlist = [NSDictionary dictionaryWithContentsOfURL:infoPlistURL];
    if (infoPlist) {
        for (NSString *iconsKey in @[@"CFBundleIcons", @"CFBundleIcons~ipad"]) {
            NSDictionary *icons = infoPlist[iconsKey];
            if (![icons isKindOfClass:[NSDictionary class]]) continue;
            NSDictionary *primary = icons[@"CFBundlePrimaryIcon"];
            if (![primary isKindOfClass:[NSDictionary class]]) continue;
            id files = primary[@"CFBundleIconFiles"];
            if ([files isKindOfClass:[NSArray class]])  [iconNames addObjectsFromArray:files];
            else if ([files isKindOfClass:[NSString class]]) [iconNames addObject:files];
            id name = primary[@"CFBundleIconName"];
            if ([name isKindOfClass:[NSString class]] && [name length] > 0)
                [iconNames addObject:name];
        }
    }
    // Standard fallback names, largest first
    [iconNames addObjectsFromArray:@[
        @"AppIcon60x60", @"AppIcon76x76", @"AppIcon83.5x83.5",
        @"AppIcon", @"Icon-60", @"Icon-76", @"Icon"
    ]];

    NSArray<NSString *> *suffixes = @[@"@3x.png", @"@2x.png", @".png"];
    for (NSString *baseName in iconNames) {
        for (NSString *suffix in suffixes) {
            NSURL *iconURL = [bundleURL URLByAppendingPathComponent:
                [baseName stringByAppendingString:suffix]];
            NSData *data = [NSData dataWithContentsOfURL:iconURL];
            if (data.length > 0) {
                UIImage *img = [UIImage imageWithData:data];
                if (img) return img;
            }
        }
    }
    return nil;
}

static UIImage *iconViaSBSForBundleID(NSString *bundleID) {
    static void *sbsHandle = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sbsHandle = dlopen(
            "/System/Library/PrivateFrameworks/SpringBoardServices.framework/SpringBoardServices",
            RTLD_LAZY | RTLD_LOCAL
        );
    });
    if (!sbsHandle) return nil;

    // SBSCopyIconImagePNGDataForDisplayIdentifier — available since iOS 4
    typedef NSData *(*SBSIconFn)(NSString *);
    static SBSIconFn sbsFn = nil;
    static dispatch_once_t fnOnce;
    dispatch_once(&fnOnce, ^{
        sbsFn = (SBSIconFn)dlsym(sbsHandle, "SBSCopyIconImagePNGDataForDisplayIdentifier");
    });
    if (!sbsFn) return nil;
    NSData *pngData = sbsFn(bundleID);
    if (pngData.length > 0) return iconFromData(pngData, 60.0);
    return nil;
}

static NSData *iconDataFromProxy(id proxy) {
    UIImage *img = iconImageFromProxy(proxy);
    if (!img) return nil;
    return UIImagePNGRepresentation(img);
}

static NSString *stringForFirstKey(NSDictionary *info, NSArray<NSString *> *keys) {
    for (NSString *key in keys) {
        id value = info[key];
        if ([value isKindOfClass:[NSString class]] && [value length] > 0) return value;
    }
    return nil;
}

static NSString *pathForFirstKey(NSDictionary *info, NSArray<NSString *> *keys) {
    for (NSString *key in keys) {
        id value = info[key];
        if ([value isKindOfClass:[NSURL class]]) {
            NSString *path = [value path];
            if (path.length > 0) return path;
        }
        if ([value isKindOfClass:[NSString class]] && [value length] > 0) return value;
    }
    return nil;
}

static void addApplicationInfo(NSMutableDictionary *result, NSString *fallbackBundleID, NSDictionary *info) {
    NSString *bundleID = stringForFirstKey(info, @[
        @"CFBundleIdentifier", @"BundleIdentifier", @"ApplicationIdentifier", @"MCMMetadataIdentifier"
    ]);
    if (bundleID.length == 0) bundleID = fallbackBundleID;
    if (bundleID.length == 0) return;

    NSString *name = stringForFirstKey(info, @[
        @"CFBundleDisplayName", @"CFBundleName", @"LocalizedName", @"Name"
    ]);
    NSString *container = pathForFirstKey(info, @[
        @"Container", @"DataContainer", @"DataContainerURL", @"ContainerPath", @"SandboxPath"
    ]);
    NSString *version = stringForFirstKey(info, @[
        @"CFBundleShortVersionString", @"BundleShortVersionString"
    ]);

    NSMutableDictionary *entry = [NSMutableDictionary dictionary];
    entry[@"name"] = name.length > 0 ? name : bundleID;
    if (container.length > 0) entry[@"container"] = container;
    if (version.length > 0) entry[@"version"] = version;
    result[bundleID] = entry;
}

static void *mobileInstallationHandle(void) {
    static void *handle;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        handle = dlopen("/System/Library/PrivateFrameworks/MobileInstallation.framework/MobileInstallation", RTLD_LAZY | RTLD_LOCAL);
    });
    return handle;
}

static NSDictionary *appsFromMobileInstallation(void) {
    NSMutableDictionary *result = [NSMutableDictionary dictionary];
    void *frameworkHandle = mobileInstallationHandle();

    // Legacy path for older releases where the original symbol is still exported.
    void *lookupFn = dlsym(RTLD_DEFAULT, "MobileInstallationLookup");
    if (!lookupFn && frameworkHandle) {
        lookupFn = dlsym(frameworkHandle, "MobileInstallationLookup");
    }
    if (!lookupFn) return result;

    NSDictionary *apps = nil;
    NSArray *optionSets = @[
        @{@"ApplicationType": @"Any"},
        @{@"ApplicationType": @"User"},
        @{@"ApplicationType": @"System"},
        @{},
    ];
    for (NSDictionary *options in optionSets) {
        apps = ((NSDictionary *(*)(NSDictionary *, void *))lookupFn)(options, NULL);
        if (apps && [apps isKindOfClass:[NSDictionary class]] && apps.count > 0) break;
    }
    if (!apps || apps.count == 0) return result;

    for (NSString *bundleID in apps) {
        @autoreleasepool {
            id rawInfo = apps[bundleID];
            if (![rawInfo isKindOfClass:[NSDictionary class]]) continue;
            addApplicationInfo(result, bundleID, rawInfo);
        }
    }
    return result;
}

static NSDictionary *appsFromWorkspace(void) {
    NSMutableDictionary *result = [NSMutableDictionary dictionary];

    Class workspaceClass = NSClassFromString(@"LSApplicationWorkspace");
    if (!workspaceClass) return result;
    SEL defaultWorkspaceSel = NSSelectorFromString(@"defaultWorkspace");
    if (![workspaceClass respondsToSelector:defaultWorkspaceSel]) return result;
    id workspace = ((id (*)(id, SEL))objc_msgSend)(workspaceClass, defaultWorkspaceSel);
    if (!workspace) return result;
    // Filza uses allApplications (not allInstalledApplications) to get ALL apps including system.
    // Try allApplications first to match Filza's behavior, then fall back to allInstalledApplications.
    NSArray *apps = nil;
    for (NSString *selectorName in @[@"allApplications", @"allInstalledApplications"]) {
        SEL allAppsSel = NSSelectorFromString(selectorName);
        if (![workspace respondsToSelector:allAppsSel]) continue;
        id candidate = ((id (*)(id, SEL))objc_msgSend)(workspace, allAppsSel);
        if ([candidate isKindOfClass:[NSArray class]] && [candidate count] > 0) {
            apps = candidate;
            break;
        }
    }
    if (!apps || apps.count == 0) return result;

    for (id app in apps) {
        @autoreleasepool {
            NSString *bundleID = nil;
            for (NSString *idSel in @[@"applicationIdentifier", @"bundleIdentifier"]) {
                SEL s = NSSelectorFromString(idSel);
                if (![app respondsToSelector:s]) continue;
                id v = ((id (*)(id, SEL))objc_msgSend)(app, s);
                if ([v isKindOfClass:[NSString class]] && [v length] > 0) { bundleID = v; break; }
            }
            if (!bundleID) continue;

            // Try multiple name selectors; same order Filza uses internally
            NSString *name = nil;
            for (NSString *nameSel in @[@"localizedName", @"localizedShortName", @"displayName", @"name"]) {
                SEL s = NSSelectorFromString(nameSel);
                if (![app respondsToSelector:s]) continue;
                id v = ((id (*)(id, SEL))objc_msgSend)(app, s);
                if ([v isKindOfClass:[NSString class]] && [v length] > 0 &&
                    ![v isEqualToString:bundleID]) { name = v; break; }
            }
            // SBS IPC fallback: ask SpringBoard for the display name when LS proxy returned nothing useful
            if (!name || [name isEqualToString:bundleID]) {
                NSString *sbsName = displayNameViaSBS(bundleID);
                if (sbsName.length > 0) name = sbsName;
            }
            if (!name) name = bundleID;

            NSMutableDictionary *entry = [NSMutableDictionary dictionary];
            entry[@"name"] = name;
            for (NSString *selectorName in @[@"dataContainerURL", @"containerURL"]) {
                SEL containerSel = NSSelectorFromString(selectorName);
                if (![app respondsToSelector:containerSel]) continue;
                id containerValue = ((id (*)(id, SEL))objc_msgSend)(app, containerSel);
                NSString *containerPath = [containerValue isKindOfClass:[NSURL class]] ? [containerValue path] : containerValue;
                if ([containerPath isKindOfClass:[NSString class]] && containerPath.length > 0) {
                    entry[@"container"] = containerPath;
                    break;
                }
            }
            // Pre-cache the icon during the bulk scan so iconForBundleID() hits cache immediately
            UIImage *icon = iconImageFromProxy(app);
            if (!icon) {
                NSURL *bURL = nil;
                SEL buSel = NSSelectorFromString(@"bundleURL");
                if ([app respondsToSelector:buSel]) {
                    id v = ((id (*)(id, SEL))objc_msgSend)(app, buSel);
                    if ([v isKindOfClass:[NSURL class]]) bURL = v;
                }
                if (bURL) icon = iconFromBundleURL(bURL);
            }
            if (!icon) icon = iconViaSBSForBundleID(bundleID);
            if (icon) entry[@"icon"] = icon;
            result[bundleID] = entry;
        }
    }
    return result;
}

NSDictionary<NSString *, NSDictionary *> *installedAppInfo(void) {
    NSDictionary *wsApps = appsFromWorkspace();
    NSDictionary *miApps = appsFromMobileInstallation();

    if (wsApps.count == 0) return miApps.count > 0 ? miApps : @{};
    if (miApps.count == 0) return wsApps;

    // Workspace (WS) carries icons + container paths.
    // MobileInstallation (MI) carries accurate CFBundleDisplayName for every installed app.
    // Merge: start from WS, promote MI name whenever WS fell back to the bundle ID.
    NSMutableDictionary *merged = [NSMutableDictionary dictionaryWithDictionary:wsApps];
    for (NSString *bundleID in miApps) {
        NSDictionary *miEntry = miApps[bundleID];
        NSMutableDictionary *entry = merged[bundleID]
            ? [merged[bundleID] mutableCopy]
            : [NSMutableDictionary dictionary];
        NSString *wsName = entry[@"name"];
        NSString *miName = miEntry[@"name"];
        if (miName.length > 0 && ![miName isEqualToString:bundleID] &&
            (!wsName || [wsName isEqualToString:bundleID])) {
            entry[@"name"] = miName;
        }
        if (!entry[@"container"] && miEntry[@"container"]) entry[@"container"] = miEntry[@"container"];
        if (!entry[@"version"]   && miEntry[@"version"])   entry[@"version"]   = miEntry[@"version"];
        merged[bundleID] = entry;
    }
    return merged;
}

// Icon via LSApplicationProxy (per bundle ID)
UIImage *iconForBundleID(NSString *bundleID) {
    static NSCache<NSString *, UIImage *> *cache;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        cache = [[NSCache alloc] init];
        cache.countLimit = 512;
    });
    UIImage *cached = [cache objectForKey:bundleID];
    if (cached) return cached;

    Class proxyClass = NSClassFromString(@"LSApplicationProxy");
    if (!proxyClass) return nil;
    SEL appProxySel = NSSelectorFromString(@"applicationProxyForIdentifier:");
    if (![proxyClass respondsToSelector:appProxySel]) return nil;
    id proxy = ((id (*)(id, SEL, id))objc_msgSend)(proxyClass, appProxySel, bundleID);
    if (!proxy) return nil;
    UIImage *icon = iconImageFromProxy(proxy);
    if (!icon) {
        NSURL *bundleURL = nil;
        SEL bundleURLSel = NSSelectorFromString(@"bundleURL");
        if ([proxy respondsToSelector:bundleURLSel]) {
            id value = ((id (*)(id, SEL))objc_msgSend)(proxy, bundleURLSel);
            if ([value isKindOfClass:[NSURL class]]) bundleURL = value;
        }
        if (bundleURL) icon = iconFromBundleURL(bundleURL);
    }
    if (!icon) icon = iconViaSBSForBundleID(bundleID);
    if (icon) [cache setObject:icon forKey:bundleID];
    return icon;
}

// Name + icon for a single bundle ID via LSApplicationProxy
NSDictionary *appInfoForBundleID(NSString *bundleID) {
    NSMutableDictionary *result = [NSMutableDictionary dictionary];
    result[@"name"] = bundleID;

    Class proxyClass = NSClassFromString(@"LSApplicationProxy");
    if (!proxyClass) return result;
    SEL appProxySel = NSSelectorFromString(@"applicationProxyForIdentifier:");
    if (![proxyClass respondsToSelector:appProxySel]) return result;
    id proxy = ((id (*)(id, SEL, id))objc_msgSend)(proxyClass, appProxySel, bundleID);
    if (!proxy) return result;

    // Check if this proxy is for the bundleID we asked for (case-insensitive).
    // If neither selector responds, assume it's correct (we explicitly requested it).
    BOOL matchesRequestedIdentifier = YES;
    for (NSString *selectorName in @[@"applicationIdentifier", @"bundleIdentifier"]) {
        SEL identifierSel = NSSelectorFromString(selectorName);
        if (![proxy respondsToSelector:identifierSel]) continue;
        id value = ((id (*)(id, SEL))objc_msgSend)(proxy, identifierSel);
        if ([value isKindOfClass:[NSString class]] && [value length] > 0) {
            matchesRequestedIdentifier = ([value caseInsensitiveCompare:bundleID] == NSOrderedSame);
            break;
        }
    }
    if (!matchesRequestedIdentifier) {
        // Still try localizedName as a best-effort
        for (NSString *selectorName in @[@"localizedName", @"localizedShortName"]) {
            SEL nameSel = NSSelectorFromString(selectorName);
            if (![proxy respondsToSelector:nameSel]) continue;
            NSString *name = ((id (*)(id, SEL))objc_msgSend)(proxy, nameSel);
            if ([name isKindOfClass:[NSString class]] && name.length > 0 &&
                ![name isEqualToString:bundleID]) {
                result[@"name"] = name;
                break;
            }
        }
        return result;
    }
    result[@"found"] = @YES;

    NSURL *bundleURL = nil;
    SEL bundleURLSel = NSSelectorFromString(@"bundleURL");
    if ([proxy respondsToSelector:bundleURLSel]) {
        id value = ((id (*)(id, SEL))objc_msgSend)(proxy, bundleURLSel);
        if ([value isKindOfClass:[NSURL class]]) bundleURL = value;
    }

    // 1. Try proxy's localizedName first (fast LS-database lookup, no file I/O)
    for (NSString *selectorName in @[@"localizedName", @"localizedShortName"]) {
        SEL nameSel = NSSelectorFromString(selectorName);
        if (![proxy respondsToSelector:nameSel]) continue;
        NSString *name = ((id (*)(id, SEL))objc_msgSend)(proxy, nameSel);
        if ([name isKindOfClass:[NSString class]] && name.length > 0 &&
            ![name isEqualToString:bundleID]) {
            result[@"name"] = name;
            break;
        }
    }

    // 2. Bundle Info.plist (fallback if proxy name failed)
    if ([result[@"name"] isEqualToString:bundleID] && bundleURL) {
        NSBundle *applicationBundle = [NSBundle bundleWithURL:bundleURL];
        NSDictionary *localizedInfo = applicationBundle.localizedInfoDictionary;
        NSDictionary *bundleInfo    = applicationBundle.infoDictionary;
        NSString *bundleName = stringForFirstKey(localizedInfo, @[@"CFBundleDisplayName", @"CFBundleName"]);
        if (bundleName.length == 0)
            bundleName = stringForFirstKey(bundleInfo, @[@"CFBundleDisplayName", @"CFBundleName"]);
        if (bundleName.length > 0 && ![bundleName isEqualToString:bundleID])
            result[@"name"] = bundleName;
    }

    // 3. SpringBoardServices IPC fallback: ask SpringBoard for the display name.
    //    SpringBoard caches all installed app names internally; the IPC works from MHA sandbox.
    if ([result[@"name"] isEqualToString:bundleID]) {
        NSString *sbsName = displayNameViaSBS(bundleID);
        if (sbsName.length > 0 && ![sbsName isEqualToString:bundleID])
            result[@"name"] = sbsName;
    }

    // Version
    if (bundleURL) {
        NSBundle *appBundle = [NSBundle bundleWithURL:bundleURL];
        NSString *v = stringForFirstKey(appBundle.infoDictionary, @[@"CFBundleShortVersionString"]);
        if (v.length > 0) result[@"version"] = v;
    }
    if (!result[@"version"]) {
        SEL versionSel = NSSelectorFromString(@"shortVersionString");
        if ([proxy respondsToSelector:versionSel]) {
            NSString *version = ((id (*)(id, SEL))objc_msgSend)(proxy, versionSel);
            if ([version isKindOfClass:[NSString class]] && version.length > 0)
                result[@"version"] = version;
        }
    }

    // Container path
    for (NSString *selectorName in @[@"dataContainerURL", @"containerURL"]) {
        SEL containerSel = NSSelectorFromString(selectorName);
        if (![proxy respondsToSelector:containerSel]) continue;
        id value = ((id (*)(id, SEL))objc_msgSend)(proxy, containerSel);
        NSString *path = [value isKindOfClass:[NSURL class]] ? [value path] : value;
        if ([path isKindOfClass:[NSString class]] && path.length > 0) {
            result[@"container"] = path;
            break;
        }
    }

    // Icon: proxy variant → bundle PNG → SBS IPC
    UIImage *icon = iconImageFromProxy(proxy);
    if (!icon && bundleURL) icon = iconFromBundleURL(bundleURL);
    if (!icon) icon = iconViaSBSForBundleID(bundleID);
    if (icon) result[@"icon"] = icon;

    return result;
}

BOOL openApplicationForBundleID(NSString *bundleID) {
    if (bundleID.length == 0) return NO;
    Class workspaceClass = NSClassFromString(@"LSApplicationWorkspace");
    SEL defaultWorkspaceSelector = NSSelectorFromString(@"defaultWorkspace");
    if (!workspaceClass || ![workspaceClass respondsToSelector:defaultWorkspaceSelector]) {
        return NO;
    }
    id workspace = ((id (*)(id, SEL))objc_msgSend)(
        workspaceClass,
        defaultWorkspaceSelector
    );
    if (!workspace) return NO;
    SEL openSelector = NSSelectorFromString(@"openApplicationWithBundleID:");
    if (![workspace respondsToSelector:openSelector]) return NO;
    return ((BOOL (*)(id, SEL, id))objc_msgSend)(workspace, openSelector, bundleID);
}
