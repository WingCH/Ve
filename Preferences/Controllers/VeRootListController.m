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
#import "../../Manager/VEAIPolicy.h"
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
        NSUserDefaults *defaults = [[NSUserDefaults alloc] initWithSuiteName:kPreferencesIdentifier];
        NSString *provider = [VEAIPolicy providerFromDefaults:defaults];
        NSString *endpoint = [VEAIPolicy endpointForProvider:provider defaults:defaults];
        BOOL cloudflare = [provider isEqual:@"cloudflare"];
        BOOL needsAccount = [endpoint containsString:@"{account_id}"];
        NSMutableArray *visible = [NSMutableArray new];
        for (PSSpecifier *specifier in [self loadSpecifiersFromPlistName:@"Root" target:self]) {
            NSString *fieldProvider = [specifier propertyForKey:@"aiProvider"];
            if (fieldProvider && ![fieldProvider isEqual:provider]) continue;
            if ([[specifier propertyForKey:@"key"] isEqual:kPreferenceKeyAIAccountID] && !needsAccount) continue;
            if ([[specifier propertyForKey:@"id"] isEqual:@"ve.ai.connection"]) {
                [specifier setName:cloudflare ? @"Cloudflare Connection" : @"Jev / System One Connection"];
                NSString *footer = cloudflare
                    ? (needsAccount ? @"Cloudflare's REST API requires both an API token and an Account ID. Each provider has its own token and URL."
                                    : @"This URL does not use the Account ID field. Each provider has its own token and URL.")
                    : @"Jev uses an API token. No Cloudflare Account ID is needed. Each provider has its own token and URL.";
                [specifier setProperty:footer forKey:@"footerText"];
            }
            if ([[specifier propertyForKey:@"id"] isEqual:@"ve.ai.token"]) {
                [specifier setName:cloudflare ? @"Cloudflare API Token" : @"Jev API Token"];
            }
            [visible addObject:specifier];
        }
        _specifiers = visible;
	}

	return _specifiers;
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    // Endpoint edits can change whether the Account ID field is required.
    [self reloadSpecifiers];
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
            UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Invalid Value" message:[key isEqual:kPreferenceKeyAITimeout] ? @"Enter a timeout above 0 and at most 120 seconds." : @"Enter a threshold from 0.5 to 1." preferredStyle:UIAlertControllerStyleAlert];
            [alert addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil]];
            [self presentViewController:alert animated:YES completion:nil];
            [self reloadSpecifiers];
            return;
        }
        value = @(number);
    }
    [super setPreferenceValue:value specifier:specifier];
    if ([key isEqual:kPreferenceKeyAIProvider]) [self reloadSpecifiers];

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
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Clear Correction Examples" message:@"Delete all AI correction examples. Keep notification logs and notification rules." preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:nil]];
    [alert addAction:[UIAlertAction actionWithTitle:@"Clear" style:UIAlertActionStyleDestructive handler:^(UIAlertAction *action) {
        BOOL saved = [[VEAIStore sharedStore] clearCorrections];
        if (!saved) {
            UIAlertController *failure = [UIAlertController alertControllerWithTitle:@"Unable to Clear" message:@"Could not save correction examples. Try again later." preferredStyle:UIAlertControllerStyleAlert];
            [failure addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil]];
            [self presentViewController:failure animated:YES completion:nil];
        }
    }]];
    [self presentViewController:alert animated:YES completion:nil];
}
@end
