#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

/// Returns a dictionary mapping bundleID -> @{ @"name": NSString, @"icon": UIImage }.
/// Uses the private LSApplicationWorkspace API (stable across iOS 14+).
NSDictionary<NSString *, NSDictionary *> *installedAppInfo(void);

/// Fetches an icon for a single bundle ID via LSApplicationProxy.
UIImage *iconForBundleID(NSString *bundleID);

/// Returns @{ @"name": NSString, @"icon": UIImage } for a single bundle ID.
NSDictionary *appInfoForBundleID(NSString *bundleID);

/// Opens an installed app using LaunchServices. Returns NO when the private
/// selector is unavailable or the requested bundle cannot be opened.
BOOL openApplicationForBundleID(NSString *bundleID);

/// Returns the .app bundle path for a bundle ID via SpringBoardServices IPC.
/// Works without enumerating /var/containers/Bundle/Application (sandbox-blocked on iOS 18).
/// Returns nil if SBS is unavailable or the app is not known to SpringBoard.
NSString *_Nullable bundlePathViaSBS(NSString *bundleID);

NS_ASSUME_NONNULL_END
