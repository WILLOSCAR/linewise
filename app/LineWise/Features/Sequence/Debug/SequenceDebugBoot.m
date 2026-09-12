#if DEBUG
// 仅调试：应用启动完成后，把控制权交给 Swift 侧的 LWSequenceDebugLauncher（按启动参数决定是否弹出顺序界面）。
// 用 ObjC 的 +load 是因为 Swift 没有自动执行的静态入口，而我们不能改 RootView / LineWiseApp。
#import <UIKit/UIKit.h>

@interface NSObject (LWSequenceDebugLauncherForwardDecl)
+ (void)installIfRequested;
@end

@interface LWSequenceDebugBoot : NSObject
@end

@implementation LWSequenceDebugBoot

+ (void)load {
    [[NSNotificationCenter defaultCenter] addObserverForName:UIApplicationDidFinishLaunchingNotification
                                                      object:nil
                                                       queue:[NSOperationQueue mainQueue]
                                                  usingBlock:^(NSNotification *note) {
        Class launcher = NSClassFromString(@"LWSequenceDebugLauncher");
        if (launcher && [launcher respondsToSelector:@selector(installIfRequested)]) {
            [launcher installIfRequested];
        }
    }];
}

@end
#endif
