#if DEBUG
// 仅调试：应用启动完成后，把控制权交给 Swift 侧的 LWShareDebugLauncher（按启动参数渲染分享图 / 打开分享预览）。
// 用 ObjC 的 +load 是因为 Swift 没有自动执行的静态入口，而我们不能改 RootView / LineWiseApp。
#import <UIKit/UIKit.h>

@interface NSObject (LWShareDebugLauncherForwardDecl)
+ (void)installIfRequested;
@end

@interface LWShareDebugBoot : NSObject
@end

@implementation LWShareDebugBoot

+ (void)load {
    [[NSNotificationCenter defaultCenter] addObserverForName:UIApplicationDidFinishLaunchingNotification
                                                      object:nil
                                                       queue:[NSOperationQueue mainQueue]
                                                  usingBlock:^(NSNotification *note) {
        Class launcher = NSClassFromString(@"LWShareDebugLauncher");
        if (launcher && [launcher respondsToSelector:@selector(installIfRequested)]) {
            [launcher installIfRequested];
        }
    }];
}

@end
#endif
