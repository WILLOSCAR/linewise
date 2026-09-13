#if DEBUG
// 仅调试：应用启动完成后，把控制权交给 Swift 侧的 LWLineDetailDebugLauncher（按启动参数决定是否直接盖出线路页相关界面）。
// 与 Sequence 的调试入口同一套路：Swift 没有自动执行的静态入口，而我们不能改 RootView / LineWiseApp。
#import <UIKit/UIKit.h>

@interface NSObject (LWLineDetailDebugLauncherForwardDecl)
+ (void)installIfRequested;
@end

@interface LWLineDetailDebugBoot : NSObject
@end

@implementation LWLineDetailDebugBoot

+ (void)load {
    [[NSNotificationCenter defaultCenter] addObserverForName:UIApplicationDidFinishLaunchingNotification
                                                      object:nil
                                                       queue:[NSOperationQueue mainQueue]
                                                  usingBlock:^(NSNotification *note) {
        Class launcher = NSClassFromString(@"LWLineDetailDebugLauncher");
        if (launcher && [launcher respondsToSelector:@selector(installIfRequested)]) {
            [launcher installIfRequested];
        }
    }];
}

@end
#endif
