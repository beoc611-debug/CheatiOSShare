#ifndef AppLauncher_h
#define AppLauncher_h

#import <Foundation/Foundation.h>

/// Launches another installed app by bundle ID via the private LSApplicationWorkspace API — the
/// standard, most reliable way to jump into another app on a jailbroken/exploited device, since
/// it works regardless of whether that app registered a URL scheme. Returns YES only if the
/// private API itself reported success; the caller should fall back to a URL scheme open (if one
/// is known) when this returns NO.
BOOL AppLauncherOpenBundleID(NSString *bundleID);

#endif /* AppLauncher_h */
