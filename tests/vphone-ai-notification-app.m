#import <UIKit/UIKit.h>
#import <UserNotifications/UserNotifications.h>

static NSString *const suite = @"codes.wingchan.ve-enhanced.preferences";
static NSString *document(NSString *name) {
    return [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES).firstObject stringByAppendingPathComponent:name];
}
static NSArray *changedKeys(void) {
    return @[@"Enabled", @"BarkForwardingEnabled", @"BarkDomain", @"BarkAPIKey", @"BarkEncryptionKey", @"BlockedSenders",
        @"AIEnabled", @"AIProvider", @"AIEndpointsByProvider", @"AITokensByProvider", @"AIAccountID", @"AIModel",
        @"AISystemOneModel", @"AIMode", @"AITimeout", @"AIThreshold", @"AIPrompt", @"AIPromptVersion"];
}
static void reload(void) {
    CFNotificationCenterPostNotification(CFNotificationCenterGetDarwinNotifyCenter(), CFSTR("codes.wingchan.ve-enhanced.preferences.reload"), NULL, NULL, YES);
}
static void saveReport(NSDictionary *report, NSString *name) {
    [[NSJSONSerialization dataWithJSONObject:report options:0 error:nil] writeToFile:document(name) atomically:YES];
}

@interface TestController : UIViewController
@property(nonatomic, strong) UILabel *status;
@end
@implementation TestController
- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = UIColor.systemBackgroundColor;
    self.status = [[UILabel alloc] initWithFrame:CGRectMake(20, 70, 390, 110)];
    self.status.numberOfLines = 5;
    self.status.text = @"Ve AI runtime fixture\n只使用合成通知及本機 HTTP 接收端。";
    [self.view addSubview:self.status];
    NSArray *titles = @[@"套用測試設定", @"發送合成通知", @"還原原有設定"];
    NSArray *actions = @[@"configure", @"send", @"restore"];
    for (NSUInteger i = 0; i < titles.count; i++) {
        UIButton *button = [UIButton buttonWithType:UIButtonTypeSystem];
        button.frame = CGRectMake(20, 200 + i * 80, 390, 60);
        [button setTitle:titles[i] forState:UIControlStateNormal];
        button.accessibilityIdentifier = [@"ve-ai-test-" stringByAppendingString:actions[i]];
        [button addTarget:self action:NSSelectorFromString(actions[i]) forControlEvents:UIControlEventTouchUpInside];
        [self.view addSubview:button];
    }
}
- (NSDictionary *)parameters {
    NSData *data = [NSData dataWithContentsOfFile:document(@"parameters.json")];
    return data ? [NSJSONSerialization JSONObjectWithData:data options:0 error:nil] : @{};
}
- (void)configure {
    NSUserDefaults *defaults = [[NSUserDefaults alloc] initWithSuiteName:suite];
    NSString *backup = document(@"prior-preferences.plist");
    if (![[NSFileManager defaultManager] fileExistsAtPath:backup]) {
        [[defaults persistentDomainForName:suite] ?: @{} writeToFile:backup atomically:YES];
    }
    NSDictionary *values = [self parameters][@"preferences"];
    for (NSString *key in changedKeys()) {
        if (values[key]) [defaults setObject:values[key] forKey:key];
    }
    BOOL saved = [defaults synchronize];
    reload();
    self.status.text = saved ? @"已套用合成測試設定。" : @"設定未能同步。";
    saveReport(@{@"saved": @(saved)}, @"configured.json");
}
- (void)send {
    NSDictionary *parameters = [self parameters];
    UNUserNotificationCenter *center = UNUserNotificationCenter.currentNotificationCenter;
    [center requestAuthorizationWithOptions:UNAuthorizationOptionAlert | UNAuthorizationOptionSound completionHandler:^(BOOL granted, NSError *error) {
        if (!granted) { saveReport(@{@"granted": @NO}, @"scheduled.json"); return; }
        UNMutableNotificationContent *content = [UNMutableNotificationContent new];
        content.title = parameters[@"title"] ?: @"Ve AI 合成通知";
        content.body = parameters[@"body"] ?: @"ve-ai-runtime:reminder";
        content.threadIdentifier = @"ve-ai-runtime";
        UNTimeIntervalNotificationTrigger *trigger = [UNTimeIntervalNotificationTrigger triggerWithTimeInterval:2 repeats:NO];
        UNNotificationRequest *request = [UNNotificationRequest requestWithIdentifier:[NSUUID UUID].UUIDString content:content trigger:trigger];
        [center addNotificationRequest:request withCompletionHandler:^(NSError *scheduleError) {
            saveReport(@{@"granted": @YES, @"scheduled": @(scheduleError == nil), @"body": content.body}, @"scheduled.json");
        }];
    }];
    self.status.text = @"兩秒後發送通知。請回到主畫面。";
}
- (void)restore {
    NSDictionary *prior = [NSDictionary dictionaryWithContentsOfFile:document(@"prior-preferences.plist")];
    if (!prior) { self.status.text = @"沒有原有設定備份。"; return; }
    NSUserDefaults *defaults = [[NSUserDefaults alloc] initWithSuiteName:suite];
    for (NSString *key in changedKeys()) {
        if (prior[key]) [defaults setObject:prior[key] forKey:key];
        else [defaults removeObjectForKey:key];
    }
    BOOL saved = [defaults synchronize];
    NSDictionary *current = [defaults persistentDomainForName:suite] ?: @{};
    BOOL matches = YES;
    for (NSString *key in changedKeys()) {
        if (prior[key] ? ![prior[key] isEqual:current[key]] : current[key] != nil) matches = NO;
    }
    reload();
    saveReport(@{@"saved": @(saved), @"matches_prior": @(matches)}, @"restored.json");
    self.status.text = matches ? @"原有設定已還原並讀回一致。" : @"還原設定仍有差異。";
}
@end

@interface SceneDelegate : UIResponder <UIWindowSceneDelegate>
@property(nonatomic, strong) UIWindow *window;
@end
@implementation SceneDelegate
- (void)scene:(UIScene *)scene willConnectToSession:(UISceneSession *)session options:(UISceneConnectionOptions *)options {
    self.window = [[UIWindow alloc] initWithWindowScene:(UIWindowScene *)scene];
    self.window.rootViewController = [TestController new];
    [self.window makeKeyAndVisible];
}
@end
@interface AppDelegate : UIResponder <UIApplicationDelegate>
@end
@implementation AppDelegate
- (UISceneConfiguration *)application:(UIApplication *)application configurationForConnectingSceneSession:(UISceneSession *)session options:(UISceneConnectionOptions *)options {
    UISceneConfiguration *configuration = [[UISceneConfiguration alloc] initWithName:@"Default" sessionRole:session.role];
    configuration.delegateClass = SceneDelegate.class;
    return configuration;
}
@end
int main(int argc, char *argv[]) {
    @autoreleasepool { return UIApplicationMain(argc, argv, nil, NSStringFromClass(AppDelegate.class)); }
}
