//
//  VeDetailListController.m
//  Vē
//
//  Created by Alexandra Aurora Göttlicher
//

#import "VeDetailListController.h"
#import <objc/runtime.h>
#import <Preferences/PSSpecifier.h>
#import "../../../Manager/LogManager.h"
#import "../../../Manager/Log.h"
#import "VeAttachmentListController.h"
#import "../Controllers/Cells/VeDetailCell.h"
#import "../Controllers/Cells/VeAttachmentCell.h"
#import "../../../Utils/DateUtil.h"
#import "../../../Preferences/PreferenceKeys.h"
#import "../../../Preferences/NotificationKeys.h"

@implementation VeDetailListController
/**
 * Sets up the controller's view.
 */
- (void)viewDidLoad {
    [super viewDidLoad];

    load_preferences();

    [self setLog:[[self specifier] propertyForKey:@"log"]];
    [self loadSpecifiers];
}

/**
 * Sets up the remove button.
 *
 * The remove button needs to be set up after the view has loaded.
 * Otherwise the default "Edit" button will override it.
 *
 * @param animated
 */
- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];

    [self setRemoveButton:[[UIButton alloc] init]];
    [[self removeButton] setImage:[[UIImage systemImageNamed:@"minus.circle"] imageWithConfiguration:[UIImageSymbolConfiguration configurationWithPointSize:23 weight:UIImageSymbolWeightRegular]] forState:UIControlStateNormal];
    [[self removeButton] setTintColor:[UIColor systemRedColor]];

    [self createRemoveButtonMenu];

    [self setItem:[[UIBarButtonItem alloc] initWithCustomView:[self removeButton]]];
    [[self navigationItem] setRightBarButtonItem:[self item]];
}

/**
 * Sets up the specifiers.
 *
 * The specifiers need to be loaded after the preferences have been.
 *
 * @return The specifiers.
 */
- (NSArray *)specifiers {
    _specifiers = [[NSMutableArray alloc] init];
	return _specifiers;
}

/**
 * Loads the specifiers
 */
- (void)loadSpecifiers {
    NSMutableArray* specifiers = [[NSMutableArray alloc] init];
    NSString* displayName = [[self log] getDisplayName];

    PSSpecifier* detailsSpecifier = [PSSpecifier groupSpecifierWithName:@"Details"];
    [detailsSpecifier setProperty:@"Tap on any cell to copy its contents." forKey:@"footerText"];
    [specifiers addObject:detailsSpecifier];

    PSSpecifier* bundleIDSpecifier = [PSSpecifier preferenceSpecifierNamed:nil target:self set:nil get:nil detail:nil cell:PSButtonCell edit:nil];
    [bundleIDSpecifier setProperty:[VeDetailCell class] forKey:@"cellClass"];
    [bundleIDSpecifier setButtonAction:@selector(copyContent:)];
    [bundleIDSpecifier setProperty:@"Bundle Identifier" forKey:@"title"];
    [bundleIDSpecifier setProperty:[[self log] bundleIdentifier] forKey:@"content"];
    [specifiers addObject:bundleIDSpecifier];

    PSSpecifier* displayNameSpecifier = [PSSpecifier preferenceSpecifierNamed:nil target:self set:nil get:nil detail:nil cell:PSButtonCell edit:nil];
    [displayNameSpecifier setProperty:[VeDetailCell class] forKey:@"cellClass"];
    [displayNameSpecifier setButtonAction:@selector(copyContent:)];
    [displayNameSpecifier setProperty:@"Application" forKey:@"title"];
    [displayNameSpecifier setProperty:displayName forKey:@"content"];
    [specifiers addObject:displayNameSpecifier];

    if (![[[self log] title] isEqualToString:@""]) {
        PSSpecifier* titleSpecifier = [PSSpecifier preferenceSpecifierNamed:nil target:self set:nil get:nil detail:nil cell:PSButtonCell edit:nil];
        [titleSpecifier setProperty:[VeDetailCell class] forKey:@"cellClass"];
        [titleSpecifier setButtonAction:@selector(copyContent:)];
        [titleSpecifier setProperty:@"Title" forKey:@"title"];
        [titleSpecifier setProperty:[[self log] title] forKey:@"content"];
        [specifiers addObject:titleSpecifier];
    }
    
    if ([[self log] subtitle] && ![[[self log] subtitle] isEqualToString:@""]) {
        PSSpecifier* subtitleSpecifier = [PSSpecifier preferenceSpecifierNamed:nil target:self set:nil get:nil detail:nil cell:PSButtonCell edit:nil];
        [subtitleSpecifier setProperty:[VeDetailCell class] forKey:@"cellClass"];
        [subtitleSpecifier setButtonAction:@selector(copyContent:)];
        [subtitleSpecifier setProperty:@"Subtitle" forKey:@"title"];
        [subtitleSpecifier setProperty:[[self log] subtitle] forKey:@"content"];
        [specifiers addObject:subtitleSpecifier];
    }

    if (![[[self log] content] isEqualToString:@""]) {
        PSSpecifier* contentSpecifier = [PSSpecifier preferenceSpecifierNamed:nil target:self set:nil get:nil detail:nil cell:PSButtonCell edit:nil];
        [contentSpecifier setProperty:[VeDetailCell class] forKey:@"cellClass"];
        [contentSpecifier setButtonAction:@selector(copyContent:)];
        [contentSpecifier setProperty:@"Message" forKey:@"title"];
        [contentSpecifier setProperty:[[self log] content] forKey:@"content"];
        [specifiers addObject:contentSpecifier];
    }

    PSSpecifier* dateSpecifier = [PSSpecifier preferenceSpecifierNamed:nil target:self set:nil get:nil detail:nil cell:PSButtonCell edit:nil];
    [dateSpecifier setProperty:[VeDetailCell class] forKey:@"cellClass"];
    [dateSpecifier setButtonAction:@selector(copyContent:)];
    [dateSpecifier setProperty:@"Date" forKey:@"title"];

    if (pfUseAmericanDateFormat) {
        [dateSpecifier setProperty:[DateUtil getStringFromDate:[[self log] date] withFormat:@"MM.dd.yyyy hh:mm:ss a"] forKey:@"content"];
    } else {
        [dateSpecifier setProperty:[DateUtil getStringFromDate:[[self log] date] withFormat:@"dd.MM.yyyy HH:mm:ss"] forKey:@"content"];
    }

    [specifiers addObject:dateSpecifier];
    
    // Technical Details section
    BOOL hasTechnicalDetails = [[self log] bulletinID] || [[self log] threadID] || [[self log] categoryID] || 
                              [[self log] summaryArgument] || [self hasInterestingBehaviorProperties];
    
    if (hasTechnicalDetails) {
        PSSpecifier* technicalSpecifier = [PSSpecifier groupSpecifierWithName:@"Technical Details"];
        [technicalSpecifier setProperty:@"Advanced notification properties for debugging." forKey:@"footerText"];
        [specifiers addObject:technicalSpecifier];
        
        if ([[self log] bulletinID]) {
            PSSpecifier* bulletinIDSpecifier = [PSSpecifier preferenceSpecifierNamed:nil target:self set:nil get:nil detail:nil cell:PSButtonCell edit:nil];
            [bulletinIDSpecifier setProperty:[VeDetailCell class] forKey:@"cellClass"];
            [bulletinIDSpecifier setButtonAction:@selector(copyContent:)];
            [bulletinIDSpecifier setProperty:@"Bulletin ID" forKey:@"title"];
            [bulletinIDSpecifier setProperty:[[self log] bulletinID] forKey:@"content"];
            [specifiers addObject:bulletinIDSpecifier];
        }
        
        if ([[self log] threadID]) {
            PSSpecifier* threadIDSpecifier = [PSSpecifier preferenceSpecifierNamed:nil target:self set:nil get:nil detail:nil cell:PSButtonCell edit:nil];
            [threadIDSpecifier setProperty:[VeDetailCell class] forKey:@"cellClass"];
            [threadIDSpecifier setButtonAction:@selector(copyContent:)];
            [threadIDSpecifier setProperty:@"Thread ID" forKey:@"title"];
            [threadIDSpecifier setProperty:[[self log] threadID] forKey:@"content"];
            [specifiers addObject:threadIDSpecifier];
        }
        
        if ([[self log] categoryID]) {
            PSSpecifier* categoryIDSpecifier = [PSSpecifier preferenceSpecifierNamed:nil target:self set:nil get:nil detail:nil cell:PSButtonCell edit:nil];
            [categoryIDSpecifier setProperty:[VeDetailCell class] forKey:@"cellClass"];
            [categoryIDSpecifier setButtonAction:@selector(copyContent:)];
            [categoryIDSpecifier setProperty:@"Category ID" forKey:@"title"];
            [categoryIDSpecifier setProperty:[[self log] categoryID] forKey:@"content"];
            [specifiers addObject:categoryIDSpecifier];
        }
        
        if ([[self log] summaryArgument]) {
            PSSpecifier* summarySpecifier = [PSSpecifier preferenceSpecifierNamed:nil target:self set:nil get:nil detail:nil cell:PSButtonCell edit:nil];
            [summarySpecifier setProperty:[VeDetailCell class] forKey:@"cellClass"];
            [summarySpecifier setButtonAction:@selector(copyContent:)];
            [summarySpecifier setProperty:@"Summary Argument" forKey:@"title"];
            [summarySpecifier setProperty:[[self log] summaryArgument] forKey:@"content"];
            [specifiers addObject:summarySpecifier];
        }
        
        // Behavior properties section
        NSMutableArray* behaviorItems = [@[] mutableCopy];
        if ([[self log] clearable]) [behaviorItems addObject:@"Clearable"];
        if ([[self log] ignoresQuietMode]) [behaviorItems addObject:@"Ignores Quiet Mode"];
        if ([[self log] turnsOnDisplay]) [behaviorItems addObject:@"Turns On Display"];
        if ([[self log] playSound]) [behaviorItems addObject:@"Plays Sound"];
        if ([[self log] hasPrivateContent]) [behaviorItems addObject:@"Has Private Content"];
        
        if ([behaviorItems count] > 0) {
            PSSpecifier* behaviorSpecifier = [PSSpecifier preferenceSpecifierNamed:nil target:self set:nil get:nil detail:nil cell:PSButtonCell edit:nil];
            [behaviorSpecifier setProperty:[VeDetailCell class] forKey:@"cellClass"];
            [behaviorSpecifier setButtonAction:@selector(copyContent:)];
            [behaviorSpecifier setProperty:@"Behavior Flags" forKey:@"title"];
            [behaviorSpecifier setProperty:[behaviorItems componentsJoinedByString:@", "] forKey:@"content"];
            [specifiers addObject:behaviorSpecifier];
        }
        
        // Time zone if different from system
        if ([[self log] timeZone] && ![[[self log] timeZone] isEqualToTimeZone:[NSTimeZone systemTimeZone]]) {
            PSSpecifier* timezoneSpecifier = [PSSpecifier preferenceSpecifierNamed:nil target:self set:nil get:nil detail:nil cell:PSButtonCell edit:nil];
            [timezoneSpecifier setProperty:[VeDetailCell class] forKey:@"cellClass"];
            [timezoneSpecifier setButtonAction:@selector(copyContent:)];
            [timezoneSpecifier setProperty:@"Time Zone" forKey:@"title"];
            [timezoneSpecifier setProperty:[[[self log] timeZone] name] forKey:@"content"];
            [specifiers addObject:timezoneSpecifier];
        }
    }

    NSArray* attachments = [[LogManager sharedInstance] getAttachmentsForLog:[self log]];
    if ([attachments count] > 0) {
        [specifiers addObject:[PSSpecifier groupSpecifierWithName:@"Attachments"]];

        for (UIImage* image in attachments) {
            PSSpecifier* attachmentSpecifier = [PSSpecifier preferenceSpecifierNamed:nil target:self set:nil get:nil detail:nil cell:PSButtonCell edit:nil];
            [attachmentSpecifier setProperty:[VeAttachmentCell class] forKey:@"cellClass"];
            [attachmentSpecifier setButtonAction:@selector(presentAttachment:)];
            [attachmentSpecifier setProperty:@(YES) forKey:@"enabled"];
            [attachmentSpecifier setProperty:@(70) forKey:@"height"];
            [attachmentSpecifier setProperty:image forKey:@"image"];
            [specifiers addObject:attachmentSpecifier];
        }
    }

    if (![displayName isEqualToString:@"SpringBoard"]) {
        [specifiers addObject:[PSSpecifier emptyGroupSpecifier]];

        PSSpecifier* openSpecifier = [PSSpecifier preferenceSpecifierNamed:[@"Open " stringByAppendingString:displayName] target:self set:nil get:nil detail:nil cell:PSButtonCell edit:nil];
        [openSpecifier setButtonAction:@selector(openApplication)];
        [specifiers addObject:openSpecifier];
    }
    
    // Raw Data section for debugging
    [specifiers addObject:[PSSpecifier emptyGroupSpecifier]];
    
    PSSpecifier* rawDataSpecifier = [PSSpecifier preferenceSpecifierNamed:@"View Raw Data" target:self set:nil get:nil detail:nil cell:PSButtonCell edit:nil];
    [rawDataSpecifier setButtonAction:@selector(showRawData)];
    [specifiers addObject:rawDataSpecifier];

    [self insertContiguousSpecifiers:specifiers atIndex:0];
}

/**
 * Prevents the specifiers from reloading on resume.
 *
 * @return Whether to reload the specifiers on resume.
 */
- (BOOL)shouldReloadSpecifiersOnResume {
    return NO;
}

/**
 * Creates the remove button's menu.
 */
- (void)createRemoveButtonMenu {
    NSMutableArray* actions = [[NSMutableArray alloc] init];

    UIAction* removeAction = [UIAction actionWithTitle:@"Remove" image:nil identifier:nil handler:^(__kindof UIAction* _Nonnull action) {
        [[LogManager sharedInstance] removeLog:[self log]];
        [[self parentController] performSelector:@selector(reloadSpecifiers)];
        [[self navigationController] popViewControllerAnimated:YES];
    }];
    [actions addObject:removeAction];

    if ([pfBlockedSenders containsObject:[[self log] bundleIdentifier]]) {
        UIAction* unblockAction = [UIAction actionWithTitle:@"Unblock Sender" image:nil identifier:nil handler:^(__kindof UIAction* _Nonnull action) {
            [pfBlockedSenders removeObject:[[self log] bundleIdentifier]];
            [preferences setObject:pfBlockedSenders forKey:kPreferenceKeyBlockedSenders];
            CFNotificationCenterPostNotification(CFNotificationCenterGetDarwinNotifyCenter(), (CFStringRef)kNotificationKeyPreferencesReload, nil, nil, YES);
            // Recreate the menu to remove the "Block Sender" action.
            [self createRemoveButtonMenu];
        }];
        [actions addObject:unblockAction];
    } else {
        UIAction* blockAction = [UIAction actionWithTitle:@"Block Sender" image:nil identifier:nil handler:^(__kindof UIAction* _Nonnull action) {
            [pfBlockedSenders addObject:[[self log] bundleIdentifier]];
            [preferences setObject:pfBlockedSenders forKey:kPreferenceKeyBlockedSenders];
            CFNotificationCenterPostNotification(CFNotificationCenterGetDarwinNotifyCenter(), (CFStringRef)kNotificationKeyPreferencesReload, nil, nil, YES);
            // Recreate the menu to remove the "Block Sender" action.
            [self createRemoveButtonMenu];
        }];
        [actions addObject:blockAction];
    }

    UIMenu* menu = [UIMenu menuWithTitle:@"" children:actions];

    [[self removeButton] setMenu:menu];
    [[self removeButton] setShowsMenuAsPrimaryAction:YES];
}

/**
 * Copies the specifier's content to the clipboard.
 *
 * @param specifier The specifier from which to copy the content from.
 */
- (void)copyContent:(PSSpecifier *)specifier {
    [[UIPasteboard generalPasteboard] setString:[specifier propertyForKey:@"content"]];
}

/**
 * Presents an attachment modally.
 *
 * @param specifier The specifier from which to take the attachment from.
 */
- (void)presentAttachment:(PSSpecifier *)specifier {
    VeAttachmentListController* attachmentListController = [[VeAttachmentListController alloc] init];
    [attachmentListController setImage:[specifier propertyForKey:@"image"]];
    [self presentViewController:attachmentListController animated:YES completion:nil];
}

/**
 * Opens the log's sender application.
 */
- (void)openApplication {
    [[objc_getClass("LSApplicationWorkspace") defaultWorkspace] openApplicationWithBundleID:[[self log] bundleIdentifier]];
}

- (void)showRawData {
    Log* log = [self log];
    
    // Get the raw BBBulletin data if available
    NSDictionary* rawBulletinData = [log rawBulletinData];
    NSString* jsonString = @"No raw BBBulletin data available";
    NSString* alertTitle = @"Raw BBBulletin Data";
    
    if (rawBulletinData && [rawBulletinData count] > 0) {
        // Convert raw BBBulletin data to JSON string
        NSError* error = nil;
        NSData* jsonData = [NSJSONSerialization dataWithJSONObject:rawBulletinData 
                                                           options:NSJSONWritingPrettyPrinted | NSJSONWritingSortedKeys 
                                                             error:&error];
        
        if (!error && jsonData) {
            jsonString = [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];
        } else {
            jsonString = [NSString stringWithFormat:@"Error serializing raw data: %@", error.localizedDescription];
        }
        
        // Add metadata about the data
        NSString* metadata = [NSString stringWithFormat:@"Properties found: %lu\nClass: BBBulletin\n\n", (unsigned long)[rawBulletinData count]];
        jsonString = [metadata stringByAppendingString:jsonString];
    } else {
        alertTitle = @"Raw Data Not Available";
        jsonString = @"Raw BBBulletin data is not available for this notification. This might be an older log entry created before the raw data collection was implemented.";
    }
    
    // Show in an alert with copy functionality
    UIAlertController* alert = [UIAlertController alertControllerWithTitle:alertTitle
                                                                   message:jsonString 
                                                            preferredStyle:UIAlertControllerStyleAlert];
    
    if (rawBulletinData && [rawBulletinData count] > 0) {
        UIAlertAction* copyAction = [UIAlertAction actionWithTitle:@"Copy Raw JSON" 
                                                             style:UIAlertActionStyleDefault 
                                                           handler:^(UIAlertAction* action) {
            [[UIPasteboard generalPasteboard] setString:jsonString];
        }];
        [alert addAction:copyAction];
    }
    
    UIAlertAction* cancelAction = [UIAlertAction actionWithTitle:@"Close" 
                                                           style:UIAlertActionStyleCancel 
                                                         handler:nil];
    [alert addAction:cancelAction];
    
    // Set message text to be monospaced for better readability
    if (@available(iOS 13.0, *)) {
        [alert setValue:[[NSAttributedString alloc] initWithString:jsonString 
                                                        attributes:@{NSFontAttributeName: [UIFont monospacedSystemFontOfSize:11 weight:UIFontWeightRegular]}] 
                 forKey:@"attributedMessage"];
    }
    
    [self presentViewController:alert animated:YES completion:nil];
}

/**
 * Loads the user's preferences.
 */
- (BOOL)hasInterestingBehaviorProperties {
    Log* log = [self log];
    // Check if any behavior properties are set to interesting values
    return ![log clearable] || [log ignoresQuietMode] || [log turnsOnDisplay] || 
           [log playSound] || [log hasPrivateContent];
}

static void load_preferences() {
    preferences = [[NSUserDefaults alloc] initWithSuiteName:kPreferencesIdentifier];

    [preferences registerDefaults:@{
        kPreferenceKeyUseAmericanDateFormat: kPreferenceKeyUseAmericanDateFormat,
        kPreferenceKeyBlockedSenders: kPreferenceKeyBlockedSendersDefaultValue()
    }];

    pfUseAmericanDateFormat = [[preferences objectForKey:kPreferenceKeyUseAmericanDateFormat] boolValue];
    pfBlockedSenders = [[preferences objectForKey:kPreferenceKeyBlockedSenders] mutableCopy];
}
@end
