//
//  VeRootListController.m
//  Vē
//
//  Created by Alexandra Aurora Göttlicher
//

#include "VeRootListController.h"
#import <Preferences/PSSpecifier.h>
#import <LocalAuthentication/LocalAuthentication.h>
#import <rootless.h>
#import "../PreferenceKeys.h"
#import "../NotificationKeys.h"
#import "../../Manager/LogManager.h"

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
    [super setPreferenceValue:value specifier:specifier];

    if ([[specifier propertyForKey:@"key"] isEqualToString:kPreferenceKeyEnabled]) {
		[self promptToRespring];
    }

	if ([[specifier propertyForKey:@"key"] isEqualToString:kPreferenceKeyUseBiometricProtection]) {
		LAContext* laContext = [[LAContext alloc] init];
        [laContext evaluatePolicy:LAPolicyDeviceOwnerAuthentication localizedReason:@"Vē needs to make sure you're permitted to toggle biometric protection." reply:^(BOOL success, NSError* _Nullable error) {
            dispatch_async(dispatch_get_main_queue(), ^{
                if (!success) {
					NSUserDefaults* userDefaults = [[NSUserDefaults alloc] initWithSuiteName:kPreferencesIdentifier];
					[userDefaults setBool:![[userDefaults objectForKey:kPreferenceKeyUseBiometricProtection] boolValue] forKey:kPreferenceKeyUseBiometricProtection];
                    [self reloadSpecifiers];
                }
            });
        }];
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
	[task setLaunchPath:ROOT_PATH_NS(@"/usr/bin/killall")];
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
                                                                        message:@"This will permanently delete ALL notification logs and attachments. This action cannot be undone.\n\nAre you sure you want to continue?" 
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
                                                                          message:@"All notification logs and attachments have been permanently deleted." 
                                                                   preferredStyle:UIAlertControllerStyleAlert];
    
    UIAlertAction* okAction = [UIAlertAction actionWithTitle:@"OK" 
                                                       style:UIAlertActionStyleDefault 
                                                     handler:nil];
    
    [successAlert addAction:okAction];
    [self presentViewController:successAlert animated:YES completion:nil];
}
@end
