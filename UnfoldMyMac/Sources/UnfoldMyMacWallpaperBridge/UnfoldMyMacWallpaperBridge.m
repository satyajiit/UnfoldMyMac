// The bridge target is header-only: it exists so the Swift extension target can see the
// reconstructed ObjC protocols without a bridging header (SwiftPM has no bridging-header
// setting). This translation unit is deliberately empty apart from the import, which keeps
// the header in the compile path so a malformed declaration fails the build here.
#import "include/UnfoldMyMacWallpaperBridge.h"
