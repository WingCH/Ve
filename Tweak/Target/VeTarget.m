//
//  VeTarget.m
//  Vē
//
//  Created by Alexandra Aurora Göttlicher
//

#import "VeTarget.h"
#import <substrate.h>
#import <Preferences/PSListController.h>
#import <Preferences/PSSpecifier.h>
#import "Controllers/VeLogsListController.h"
#import "../../Preferences/PreferenceKeys.h"
#import "../../Preferences/NotificationKeys.h"
#import "../../Utils/JailbreakPath.h"

static void insertVeEntries(PSListController *controller) {
    if ([controller specifierForID:@"ve.notification.logs"]) return;
    PSSpecifier *group = [PSSpecifier emptyGroupSpecifier];
    [group setProperty:@"Ve 通知紀錄、AI 判斷與轉發設定。" forKey:@"footerText"];
    PSSpecifier *logs = [PSSpecifier preferenceSpecifierNamed:@"Notification Logs" target:controller set:nil get:nil detail:[VeLogsListController class] cell:PSLinkCell edit:nil];
    [logs setProperty:@"ve.notification.logs" forKey:@"id"];
    NSMutableArray *entries = [NSMutableArray arrayWithObjects:group, logs, nil];
    NSBundle *bundle = [NSBundle bundleWithPath:VEJailbreakRootPath(@"/Library/PreferenceBundles/VEEnhancedPreferences.bundle")];
    if ([bundle load]) {
        Class root = NSClassFromString(@"VeRootListController");
        if (root) {
            PSSpecifier *settings = [PSSpecifier preferenceSpecifierNamed:@"VE Enhanced 設定" target:controller set:nil get:nil detail:root cell:PSLinkCell edit:nil];
            [settings setProperty:@"ve.notification.settings" forKey:@"id"];
            [entries addObject:settings];
        }
    }
    [controller insertContiguousSpecifiers:entries atIndex:0];
}

// Observe an already-loaded controller, without depending on a legacy root ID.
static void (*original_list_viewDidAppear)(PSListController *, SEL, BOOL);
static void list_viewDidAppear(PSListController *self, SEL command, BOOL animated) {
    original_list_viewDidAppear(self, command, animated);
    if ([self isKindOfClass:NSClassFromString(@"BulletinBoardController")]) insertVeEntries(self);
}
static void load_preferences(void) {
    preferences = [[NSUserDefaults alloc] initWithSuiteName:kPreferencesIdentifier];
    [preferences registerDefaults:@{kPreferenceKeyEnabled: @(kPreferenceKeyEnabledDefaultValue)}];
    pfEnabled = [preferences boolForKey:kPreferenceKeyEnabled];
}
static void logs_changed(CFNotificationCenterRef center, void *observer, CFStringRef name, const void *object, CFDictionaryRef userInfo) {
    dispatch_async(dispatch_get_main_queue(), ^{
        [[NSNotificationCenter defaultCenter] postNotificationName:kNotificationKeyLogsChanged object:nil];
    });
}
__attribute__((constructor)) static void initialize(void) {
    load_preferences();
    if (!pfEnabled) return;
    Class list = NSClassFromString(@"PSListController");
    if (list && [list instancesRespondToSelector:@selector(viewDidAppear:)]) {
        MSHookMessageEx(list, @selector(viewDidAppear:), (IMP)list_viewDidAppear, (IMP *)&original_list_viewDidAppear);
    }
    CFNotificationCenterAddObserver(CFNotificationCenterGetDarwinNotifyCenter(), NULL, (CFNotificationCallback)load_preferences, (__bridge CFStringRef)kNotificationKeyPreferencesReload, NULL, CFNotificationSuspensionBehaviorDeliverImmediately);
    CFNotificationCenterAddObserver(CFNotificationCenterGetDarwinNotifyCenter(), NULL, logs_changed, (__bridge CFStringRef)kNotificationKeyLogsChanged, NULL, CFNotificationSuspensionBehaviorDeliverImmediately);
}
