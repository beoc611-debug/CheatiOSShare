#import "AppLauncher.h"

// LSApplicationWorkspace is a private LaunchServices class, so there's no header to import for
// it — it's resolved by name at runtime instead, the same way every jailbreak-adjacent tweak
// that launches other apps does it. NSInvocation (not plain performSelector:) is used to call
// -openApplicationWithBundleID: because that method returns BOOL, not an object, and
// performSelector:'s return value is only well-defined for object/void-returning methods.
BOOL AppLauncherOpenBundleID(NSString *bundleID) {
    if (bundleID.length == 0) return NO;

    Class workspaceClass = NSClassFromString(@"LSApplicationWorkspace");
    if (!workspaceClass) return NO;

    SEL defaultWorkspaceSelector = NSSelectorFromString(@"defaultWorkspace");
    if (![workspaceClass respondsToSelector:defaultWorkspaceSelector]) return NO;

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
    id workspace = [workspaceClass performSelector:defaultWorkspaceSelector];
#pragma clang diagnostic pop
    if (!workspace) return NO;

    SEL openSelector = NSSelectorFromString(@"openApplicationWithBundleID:");
    if (![workspace respondsToSelector:openSelector]) return NO;

    NSMethodSignature *signature = [workspace methodSignatureForSelector:openSelector];
    NSInvocation *invocation = [NSInvocation invocationWithMethodSignature:signature];
    invocation.selector = openSelector;
    invocation.target = workspace;
    [invocation setArgument:&bundleID atIndex:2];
    [invocation invoke];

    BOOL result = NO;
    [invocation getReturnValue:&result];
    return result;
}
