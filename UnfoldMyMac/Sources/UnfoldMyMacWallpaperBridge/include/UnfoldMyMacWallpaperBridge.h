//
//  UnfoldMyMacWallpaperBridge.h
//
//  Hand-written declarations for the private wallpaper extension contract macOS 26 uses.
//
//  None of this is public API. `WallpaperExtensionKit.framework` ships in PrivateFrameworks
//  with no headers, modulemap or .swiftinterface, so the NSXPC protocols below were
//  reconstructed from the selectors Apple's own Wallpaper*Extension bundles export. The
//  concrete XPC payload classes are NOT declared here: they are resolved at runtime with
//  `objc_getClass` after `dlopen`, so a macOS release that renames them fails closed at the
//  call site instead of failing to link.
//
//  Layout adapted from Phosphene (https://github.com/kageroumado/phosphene), MIT licensed.
//  See NOTICE.
//

#import <Foundation/Foundation.h>
#import <objc/runtime.h>
#import <QuartzCore/QuartzCore.h>
#import <bsm/libbsm.h>

NS_ASSUME_NONNULL_BEGIN

#pragma mark - Caller identity

/// The connecting peer's audit token. Private on NSXPCConnection; used to verify that the
/// process talking to us really is WallpaperAgent before we export anything.
@interface NSXPCConnection (UnfoldMyMacCallerIdentity)
@property (nonatomic, readonly) audit_token_t auditToken;
@end

#pragma mark - Private CAContext

/// A remote CAContext hands a layer tree to the WindowServer by id. The wallpaper host
/// composites that tree directly, which is what lets a CAMetalLayer rendered inside a
/// sandboxed extension appear as the real desktop and lock screen wallpaper.
@interface CAContext : NSObject
@property (readonly) unsigned int contextId;
@property (retain, nullable) CALayer *layer;
/// Nullable and typed so Swift gets `CAContext?` back rather than an untyped `Any`: a failure to
/// create the context has to be visible to the caller, not cast away.
+ (nullable instancetype)remoteContext;
+ (nullable instancetype)remoteContextWithOptions:(nullable NSDictionary<NSString *, id> *)options;
@end

#pragma mark - Extension -> host

@protocol UnfoldMyMacWallpaperHostProxy <NSObject>
- (void)pingWithId:(id _Nullable)anId;
- (void)updateSettingsViewModels:(id _Nullable)models reply:(void (^)(NSError * _Nullable))reply;
- (void)requestReadOnlyAccessTo:(id _Nullable)url reply:(void (^)(id _Nullable))reply;
- (void)invalidateSnapshotsWithReply:(void (^)(NSError * _Nullable))reply;
@end

#pragma mark - Host -> extension

@protocol UnfoldMyMacWallpaperExtensionXPC <NSObject>

// Lifecycle
- (void)acquireWithId:(id _Nullable)anId request:(id _Nullable)request reply:(void (^)(id _Nullable, NSError * _Nullable))reply;
- (void)updateWithId:(id _Nullable)anId request:(id _Nullable)request reply:(void (^)(NSError * _Nullable))reply;
- (void)invalidateWithId:(id _Nullable)anId reply:(void (^)(NSError * _Nullable))reply;
- (void)snapshotWithId:(id _Nullable)anId reply:(void (^)(id _Nullable, NSError * _Nullable))reply;

// Settings
- (void)provideSettingsViewModelsWithContentTypes:(id _Nullable)types reply:(void (^)(id _Nullable, NSError * _Nullable))reply;

// Choices
- (void)addChoiceRequestWithChoiceRequest:(id _Nullable)request onBehalfOfProcess:(id _Nullable)process reply:(void (^)(id _Nullable, NSError * _Nullable))reply;
- (void)removeChoiceRequestWithChoiceRequest:(id _Nullable)request reply:(void (^)(NSError * _Nullable))reply;
- (void)selectedChoicesDidChangeFor:(id _Nullable)anId reply:(void (^)(NSError * _Nullable))reply;
- (void)invokeContextMenuActionWithMenuItemID:(id _Nullable)menuItemID groupItemID:(id _Nullable)groupItemID reply:(void (^)(NSError * _Nullable))reply;

// Downloads — every bundled scene is present on disk, so these answer immediately.
- (void)isChoiceDownloadedWith:(id _Nullable)choiceID reply:(void (^)(BOOL, NSError * _Nullable))reply;
- (id _Nullable)downloadWithChoiceID:(id _Nullable)choiceID reply:(void (^)(NSError * _Nullable))reply;
- (void)pauseDownloadFor:(id _Nullable)choiceID reply:(void (^)(NSError * _Nullable))reply;
- (void)cancelDownloadFor:(id _Nullable)choiceID reply:(void (^)(NSError * _Nullable))reply;
- (void)resumeDownloadFor:(id _Nullable)choiceID reply:(void (^)(NSError * _Nullable))reply;
- (void)removeDownloadFor:(id _Nullable)choiceID reply:(void (^)(NSError * _Nullable))reply;

// Migration
- (void)migrateSelectedChoiceFor:(id _Nullable)anId reply:(void (^)(id _Nullable, NSError * _Nullable))reply;
- (void)migrateFrom:(id _Nullable)from to:(id _Nullable)to reply:(void (^)(NSError * _Nullable))reply;

// Shuffle
- (void)skipShuffledContentWithId:(id _Nullable)anId reply:(void (^)(NSError * _Nullable))reply;
- (void)canSkipShuffledContentWithId:(id _Nullable)anId reply:(void (^)(BOOL, NSError * _Nullable))reply;

// Debug & notifications
- (void)handleDebugRequestFor:(id _Nullable)request reply:(void (^)(id _Nullable, NSError * _Nullable))reply;
- (void)handleNotificationWithNamed:(id _Nullable)name reply:(void (^)(NSError * _Nullable))reply;

@end

NS_ASSUME_NONNULL_END
