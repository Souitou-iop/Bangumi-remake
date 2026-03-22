#import "AppDelegate.h"

#import "Bangumi-Swift.h"

@implementation AppDelegate

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions
{
  self.window = [[UIWindow alloc] initWithFrame:UIScreen.mainScreen.bounds];
  self.window.backgroundColor = UIColor.systemGroupedBackgroundColor;
  self.window.rootViewController = [BangumiRootViewFactory makeRootViewController];
  [self.window makeKeyAndVisible];
  return YES;
}

@end
