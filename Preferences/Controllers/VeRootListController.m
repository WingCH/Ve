//
//  VeRootListController.m
//  Vē
//
//  Created by Alexandra Aurora Göttlicher
//

#include "VeRootListController.h"
#import <Preferences/PSSpecifier.h>
#import "../PreferenceKeys.h"
#import "../NotificationKeys.h"
#import "../../Manager/LogManager.h"
#import "../../Manager/VEAIStore.h"
#import <math.h>
#import "../../Utils/JailbreakPath.h"

@implementation VeRootListController
/**
 * Loads the root specifiers.
 *
 * @return The specifiers.
 */
- (NSArray *)specifiers {
	if (!_specifiers) {
		_specifiers = [self loadSpecifiersFromPlistName:@"Root" target:self];
	}

	return _specifiers;
}

/**
 * Handles preference changes.
 *
 * @param value The new value for the changed option.
 * @param specifier The specifier that was interacted with.
 */
- (void)setPreferenceValue:(id)value specifier:(PSSpecifier *)specifier {
    NSString *key = [specifier propertyForKey:@"key"];
    if ([key isEqual:kPreferenceKeyAITimeout] || [key isEqual:kPreferenceKeyAIThreshold]) {
        NSScanner *scanner = [NSScanner scannerWithString:[value description]];
        double number;
        BOOL valid = [scanner scanDouble:&number] && scanner.isAtEnd && isfinite(number);
        valid = valid && ([key isEqual:kPreferenceKeyAITimeout] ? (number > 0 && number <= 120) : (number >= 0.5 && number <= 1));
        if (!valid) {
            UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"數值無效" message:[key isEqual:kPreferenceKeyAITimeout] ? @"請輸入大於 0、最多 120 的秒數。" : @"請輸入 0.5 至 1 的門檻。" preferredStyle:UIAlertControllerStyleAlert];
            [alert addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil]];
            [self presentViewController:alert animated:YES completion:nil];
            [self reloadSpecifiers];
            return;
        }
        value = @(number);
    }
    [super setPreferenceValue:value specifier:specifier];

    if ([[specifier propertyForKey:@"key"] isEqualToString:kPreferenceKeyEnabled]) {
		[self promptToRespring];
    }
}

/**
 * Prompts the user to respring to apply changes.
 */
- (void)promptToRespring {
    UIAlertController* resetAlert = [UIAlertController alertControllerWithTitle:@"Vē" message:@"This option requires a respring to apply. Do you want to respring now?" preferredStyle:UIAlertControllerStyleAlert];

    UIAlertAction* yesAction = [UIAlertAction actionWithTitle:@"Yes" style:UIAlertActionStyleDestructive handler:^(UIAlertAction * action) {
        [self respring];
	}];

	UIAlertAction* noAction = [UIAlertAction actionWithTitle:@"No" style:UIAlertActionStyleCancel handler:nil];

	[resetAlert addAction:yesAction];
	[resetAlert addAction:noAction];

	[self presentViewController:resetAlert animated:YES completion:nil];
}

/**
 * Resprings the device.
 */
- (void)respring {
	NSTask* task = [[NSTask alloc] init];
	[task setLaunchPath:VEJailbreakRootPath(@"/usr/bin/killall")];
	[task setArguments:@[@"backboardd"]];
	[task launch];
}

/**
 * Prompts the user to reset their preferences.
 */
- (void)resetPrompt {
    UIAlertController* resetAlert = [UIAlertController alertControllerWithTitle:@"Vē" message:@"Are you sure you want to reset your preferences?" preferredStyle:UIAlertControllerStyleAlert];

    UIAlertAction* yesAction = [UIAlertAction actionWithTitle:@"Yes" style:UIAlertActionStyleDestructive handler:^(UIAlertAction * action) {
        [self resetPreferences];
	}];

	UIAlertAction* noAction = [UIAlertAction actionWithTitle:@"No" style:UIAlertActionStyleCancel handler:nil];

	[resetAlert addAction:yesAction];
	[resetAlert addAction:noAction];

	[self presentViewController:resetAlert animated:YES completion:nil];
}

/**
 * Resets the preferences.
 */
- (void)resetPreferences {
	NSUserDefaults* userDefaults = [[NSUserDefaults alloc] initWithSuiteName:kPreferencesIdentifier];
	for (NSString* key in [userDefaults dictionaryRepresentation]) {
		[userDefaults removeObjectForKey:key];
	}

	[self reloadSpecifiers];
	CFNotificationCenterPostNotification(CFNotificationCenterGetDarwinNotifyCenter(), (CFStringRef)kNotificationKeyPreferencesReload, nil, nil, YES);
}

/**
 * Prompts the user to reset all logs and data.
 */
- (void)resetAllDataPrompt {
    UIAlertController* resetAlert = [UIAlertController alertControllerWithTitle:@"Reset All Data" 
                                                                        message:@"This will permanently delete ALL notification logs, attachments and AI correction examples. This action cannot be undone.\n\nAre you sure you want to continue?"
                                                                 preferredStyle:UIAlertControllerStyleAlert];

    UIAlertAction* yesAction = [UIAlertAction actionWithTitle:@"Delete All" 
                                                        style:UIAlertActionStyleDestructive 
                                                      handler:^(UIAlertAction * action) {
        [self resetAllData];
	}];

	UIAlertAction* noAction = [UIAlertAction actionWithTitle:@"Cancel" 
                                                       style:UIAlertActionStyleCancel 
                                                     handler:nil];

	[resetAlert addAction:yesAction];
	[resetAlert addAction:noAction];

	[self presentViewController:resetAlert animated:YES completion:nil];
}

/**
 * Resets all logs and data.
 */
- (void)resetAllData {
    [[LogManager sharedInstance] removeAllLogs];
    
    // Show success message
    UIAlertController* successAlert = [UIAlertController alertControllerWithTitle:@"Success" 
                                                                          message:@"All notification logs, attachments and AI correction examples have been permanently deleted."
                                                                   preferredStyle:UIAlertControllerStyleAlert];
    
    UIAlertAction* okAction = [UIAlertAction actionWithTitle:@"OK" 
                                                       style:UIAlertActionStyleDefault 
                                                     handler:nil];
    
    [successAlert addAction:okAction];
    [self presentViewController:successAlert animated:YES completion:nil];
}

- (void)clearAICorrectionsPrompt {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"清除修正例子" message:@"刪除全部 AI 修正例子，保留通知紀錄與判斷規則。" preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil]];
    [alert addAction:[UIAlertAction actionWithTitle:@"清除" style:UIAlertActionStyleDestructive handler:^(UIAlertAction *action) {
        BOOL saved = [[VEAIStore sharedStore] clearCorrections];
        if (!saved) {
            UIAlertController *failure = [UIAlertController alertControllerWithTitle:@"未能清除" message:@"無法寫入修正例子，請稍後重試。" preferredStyle:UIAlertControllerStyleAlert];
            [failure addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil]];
            [self presentViewController:failure animated:YES completion:nil];
        }
    }]];
    [self presentViewController:alert animated:YES completion:nil];
}
@end
