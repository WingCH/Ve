//
//  LogManager.m
//  Vē
//
//  Created by Alexandra Aurora Göttlicher
//

#import "LogManager.h"
#import "Log.h"
#import "VEAIStore.h"
#import "../Utils/ImageUtil.h"
#import "../Utils/JailbreakPath.h"
#import "../Utils/NotificationIdentity.h"
#import "../Utils/StringUtil.h"
#import "../Utils/DateUtil.h"
#import "../Preferences/NotificationKeys.h"
#import "../Preferences/PreferenceKeys.h"
#import "../PrivateHeaders.h"

@implementation LogManager
/**
 * Returns the logs file path.
 */
+ (NSString *)logsPath {
    return VEJailbreakRootPath(@"/var/mobile/Library/codes.wingchan.ve-enhanced/logs.json");
}

/**
 * Returns the logs attachment directory path.
 */
+ (NSString *)logsAttachmentPath {
    return VEJailbreakRootPath(@"/var/mobile/Library/codes.wingchan.ve-enhanced/attachments/");
}

/**
 * Creates the shared instance.
 */
+ (instancetype)sharedInstance {
    static LogManager* sharedInstance;
    static dispatch_once_t onceToken;

    dispatch_once(&onceToken, ^{
        sharedInstance = [LogManager alloc];
        sharedInstance->_fileManager = [NSFileManager defaultManager];
    });

    return sharedInstance;
}

/**
 * Creates the manager using the shared instance.
 */
- (instancetype)init {
    return [LogManager sharedInstance];
}

- (BOOL)addLogForBulletin:(BBBulletin *)bulletin {
    return [self addLogForBulletin:bulletin recordID:NULL];
}

- (BOOL)addLogForBulletin:(BBBulletin *)bulletin recordID:(NSString **)recordID {
    if (recordID) *recordID = nil;
    __block NSString *savedRecordID;
    NSNumber *saved = [[VEAIStore sharedStore] performLocked:^id {
        NSMutableDictionary* json = [self getJson];
        if (!json) return @NO;
        NSUInteger lastIdentifier = [self getLastIdentifierFromJson:json];
        NSMutableArray* logs = [self getLogsFromJson:json];

        NSUInteger identifier = lastIdentifier + 1;
        Log* log = [[Log alloc] initWithBulletin:bulletin identifier:identifier];

        NSMutableDictionary* logDict = [@{
            kLogKeyIdentifier: @(identifier),
            kLogKeyRecordID: [NSUUID UUID].UUIDString,
            kLogKeyBundleIdentifier: [log bundleIdentifier],
            kLogKeyTitle: [log title],
            kLogKeyContent: [log content],
            kLogKeyDate: [DateUtil getStringFromDate:[log date] withFormat:kLogInternalDateFormat]
        } mutableCopy];

        // Add new properties if they exist
        if ([log subtitle] && ![[log subtitle] isEqualToString:@""]) {
            logDict[kLogKeySubtitle] = [log subtitle];
        }

        if ([log publicationDate]) {
            logDict[kLogKeyPublicationDate] = [DateUtil getStringFromDate:[log publicationDate] withFormat:kLogInternalDateFormat];
        }

        if ([log expirationDate]) {
            logDict[kLogKeyExpirationDate] = [DateUtil getStringFromDate:[log expirationDate] withFormat:kLogInternalDateFormat];
        }

        // Identifiers
        if ([log bulletinID]) logDict[kLogKeyBulletinID] = [log bulletinID];
        if ([log bulletinVersionID]) logDict[kLogKeyBulletinVersionID] = [log bulletinVersionID];
        if ([log threadID]) logDict[kLogKeyThreadID] = [log threadID];
        if ([log categoryID]) logDict[kLogKeyCategoryID] = [log categoryID];

        // Behavior properties - always save these as they have default boolean values
        logDict[kLogKeyClearable] = @([log clearable]);
        logDict[kLogKeyIgnoresQuietMode] = @([log ignoresQuietMode]);
        logDict[kLogKeyTurnsOnDisplay] = @([log turnsOnDisplay]);
        logDict[kLogKeyPlaySound] = @([log playSound]);
        logDict[kLogKeyHasPrivateContent] = @([log hasPrivateContent]);

        // Summary and content
        if ([log summaryArgument]) logDict[kLogKeySummaryArgument] = [log summaryArgument];
        if ([log summaryArgumentCount] > 0) logDict[kLogKeySummaryArgumentCount] = @([log summaryArgumentCount]);

        // Time zone
        if ([log timeZone]) logDict[kLogKeyTimeZone] = [[log timeZone] name];

        // Raw bulletin data for debugging
        if ([log rawBulletinData]) logDict[kLogKeyRawBulletinData] = [log rawBulletinData];

        // BBServer republishes retained notifications after a reboot or respring.
        // Let the caller suppress forwarding an unchanged, previously saved log.
        if ([self isNotificationAlreadyLogged:logDict inLogs:logs]) {
            return @NO;
        }

        [logs insertObject:logDict atIndex:0];

        if ([self saveLocalAttachments]) {
            [self saveLocalAttachmentsForLog:log fromBulletin:bulletin];
        }

        if ([self saveRemoteAttachments]) {
            dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
                [self saveRemoteAttachmentsForLog:log];
            });
        }

        // Remove the oldest logs if the logs count exceeds the set limit.
        while ([logs count] > [self logLimit]) {
            [logs removeLastObject];
        }

        json[kLogsKeyLogs] = logs;
        json[kLogsKeyLastIdentifier] = @(identifier);

        BOOL written = [self setJsonFromDictionary:json];
        if (written) savedRecordID = logDict[kLogKeyRecordID];

        // if ([self automaticallyDeleteLogs]) {
        //     [self removeOverdueLogsFromLogs:logs];
        // }
        return @(written);
    }];
    if (recordID) *recordID = savedRecordID;
    if (saved.boolValue) [[VEAIStore sharedStore] postChange];
    return saved.boolValue;
}

- (void)removeLog:(Log *)log {
    [[VEAIStore sharedStore] performLocked:^id {
    NSMutableDictionary* json = [self getJson];
    NSMutableArray* logs = [self getLogsFromJson:json];

    for (NSDictionary* dictionary in logs) {
        if (log.recordID.length && [log.recordID isEqual:dictionary[kLogKeyRecordID]]) {
            [logs removeObject:dictionary];
            break;
        }
    }

    json[kLogsKeyLogs] = logs;

    [self setJsonFromDictionary:json];
    return nil;
    }];
    [[VEAIStore sharedStore] postChange];
}

- (Log *)logForRecordID:(NSString *)recordID {
    NSDictionary *dictionary = [[VEAIStore sharedStore] notificationForRecordID:recordID];
    return dictionary ? [Log logFromDictionary:dictionary] : nil;
}

- (void)removeOverdueLogsFromLogs:(NSMutableArray *)logs {
    [[VEAIStore sharedStore] performLocked:^id {
    NSMutableDictionary* json = [self getJson];
    NSDate* now = [NSDate date];
    NSDate* lastHouseholdDate = [DateUtil getDateFromString:[self getLastHousekeepingDateFromJson:json] withFormat:kLogInternalDateFormat];

    if ([DateUtil isDate:lastHouseholdDate inDate:now]) {
        return nil;
    }
    json[kLogsKeyLastHousekeepingDate] = [DateUtil getStringFromDate:now withFormat:kLogInternalDateFormat];
    [self setJsonFromDictionary:json];

    for (Log* log in logs) {
        if ([DateUtil isDate:[log date] olderThanDays:7]) {
            [self removeLog:log];
        }
    }
    return nil;
    }];
}

- (void)saveLocalAttachmentsForLog:(Log *)log fromBulletin:(BBBulletin *)bulletin {
    NSURL* attachmentsURL = [[[bulletin primaryAttachment] URL] URLByDeletingLastPathComponent];
    NSString* attachmentsDirectoryPath = [[attachmentsURL absoluteString] stringByReplacingOccurrencesOfString:@"file://" withString:@""];
    NSArray* attachmentsDirectoryContents = [_fileManager contentsOfDirectoryAtPath:attachmentsDirectoryPath error:nil];

    for (NSUInteger i = 0; i < [attachmentsDirectoryContents count]; i++) {
        NSString* fileName = attachmentsDirectoryContents[i];
        NSString* filePath = [NSString stringWithFormat:@"%@%@", attachmentsDirectoryPath, fileName];
        UIImage* image = [UIImage imageWithContentsOfFile:filePath];

        if (image) {
            [self saveAttachmentImage:image forLog:log];
        }
    }
}

- (void)saveRemoteAttachmentsForLog:(Log *)log {
    NSDataDetector* dataDetector = [NSDataDetector dataDetectorWithTypes:NSTextCheckingTypeLink error:nil];
    NSMutableArray* matches = [[NSMutableArray alloc] init];

    for (NSString* string in @[[log title], [log content]]) {
        NSArray* newMatches = [dataDetector matchesInString:string options:0 range:NSMakeRange(0, [string length])];
        [matches addObjectsFromArray:newMatches];
    }

    for (NSTextCheckingResult* match in matches) {
        UIImage* image = [UIImage imageWithData:[NSData dataWithContentsOfURL:[match URL]]];
        if (image) {
            [self saveAttachmentImage:image forLog:log];
        }
    }
}

- (void)saveAttachmentImage:(UIImage *)image forLog:(Log *)log {
    NSString* directoryPath = [NSString stringWithFormat:@"%@%lu/", [LogManager logsAttachmentPath], [log identifier]];
    if (![_fileManager fileExistsAtPath:directoryPath]) {
        [_fileManager createDirectoryAtPath:directoryPath withIntermediateDirectories:YES attributes:nil error:nil];
    }

    if ([ImageUtil imageHasAlpha:image]) {
        NSData* attachmentData = UIImagePNGRepresentation(image);
        [attachmentData writeToFile:[NSString stringWithFormat:@"%@%@.png", directoryPath, [StringUtil getRandomStringWithLength:32]] atomically:YES];
    } else {
        NSData* attachmentData = UIImageJPEGRepresentation(image, 1);
        [attachmentData writeToFile:[NSString stringWithFormat:@"%@%@.jpg", directoryPath, [StringUtil getRandomStringWithLength:32]] atomically:YES];
    }
}

- (NSArray *)getAttachmentsForLog:(Log *)log {
    NSString* directoryPath = [NSString stringWithFormat:@"%@%lu/", [LogManager logsAttachmentPath], [log identifier]];
    NSArray* directoryContents = [_fileManager contentsOfDirectoryAtPath:directoryPath error:nil];

    NSMutableArray* attachments = [[NSMutableArray alloc] init];
    for (NSUInteger i = 0; i < [directoryContents count]; i++) {
        NSString* fileName = directoryContents[i];
        NSString* filePath = [NSString stringWithFormat:@"%@%@", directoryPath, fileName];
        [attachments addObject:[UIImage imageWithContentsOfFile:filePath]];
    }

    return attachments;
}

- (BOOL)isNotificationAlreadyLogged:(NSDictionary *)notification inLogs:(NSArray *)logs {
    for (NSDictionary* existingLogDictionary in logs) {
        if (VEIsSameLoggedNotification(notification, existingLogDictionary)) {
            return YES;
        }
    }

    return NO;
}

- (BOOL)isBulletinIDAlreadyExists:(NSString *)bulletinID {
    if (!bulletinID || [bulletinID isEqualToString:@""]) {
        return NO;
    }
    
    NSMutableDictionary* json = [self getJson];
    NSMutableArray* logs = [self getLogsFromJson:json];
    
    for (NSDictionary* existingLogDictionary in logs) {
        NSString* existingBulletinID = existingLogDictionary[kLogKeyBulletinID];
        if (existingBulletinID && [existingBulletinID isEqualToString:bulletinID]) {
            return YES;
        }
    }
    
    return NO;
}

- (NSMutableArray *)getLogsFromJson:(NSMutableDictionary *)json {
    return json[kLogsKeyLogs] ?: [[NSMutableArray alloc] init];
}

- (NSUInteger)getLastIdentifierFromJson:(NSMutableDictionary *)json {
    return [json[kLogsKeyLastIdentifier] ?: @(0) unsignedIntegerValue];
}

- (NSString *)getLastHousekeepingDateFromJson:(NSMutableDictionary *)json {
    NSString* dateString = json[kLogsKeyLastHousekeepingDate];

    if (!dateString) {
        dateString = [DateUtil getStringFromDate:[NSDate date] withFormat:kLogInternalDateFormat];
        json[kLogsKeyLastHousekeepingDate] = dateString;
        [self setJsonFromDictionary:json];
    }

    return dateString;
}

/**
 * Returns a dictionary from the json containing the logs.
 *
 * @return The dictionary.
 */
- (NSMutableDictionary *)getJson {
    return [[VEAIStore sharedStore] performLocked:^id {
    [self ensureResourcesExist];
    NSMutableDictionary *json = [[VEAIStore sharedStore] readJSON:@"logs.json"];
    if (!json) return nil;
    BOOL migrated = NO;
    for (NSMutableDictionary *log in json[kLogsKeyLogs]) {
        if (![log[kLogKeyRecordID] length]) {
            log[kLogKeyRecordID] = [NSUUID UUID].UUIDString;
            migrated = YES;
        }
    }
    if (migrated && ![self setJsonFromDictionary:json]) return nil;
    NSDictionary *examples = [[VEAIStore sharedStore] readJSON:@"corrections.json"][@"examples"];
    for (NSMutableDictionary *log in json[kLogsKeyLogs]) {
        NSDictionary *correction = examples[log[kLogKeyRecordID]];
        if (correction) log[kLogKeyCorrection] = correction;
        else [log removeObjectForKey:kLogKeyCorrection];
    }
    return json;
    }];
}

/**
 * Saves the dictionary contents to the json file.
 *
 * @param dictionary The dictionary from which to save the contents from.
 */
- (BOOL)setJsonFromDictionary:(NSMutableDictionary *)dictionary {
    return [[VEAIStore sharedStore] writeJSON:dictionary name:@"logs.json"];
}

/**
 * Creates the json and path for the attachments.
 */
- (void)removeAllLogs {
    [[VEAIStore sharedStore] performLocked:^id {
    if (![self setJsonFromDictionary:[@{kLogsKeyLogs: @[], kLogsKeyLastIdentifier: @0} mutableCopy]]) return nil;
    [[VEAIStore sharedStore] clearCorrections];
    
    // Remove all attachment directories
    if ([_fileManager fileExistsAtPath:[LogManager logsAttachmentPath]]) {
        [_fileManager removeItemAtPath:[LogManager logsAttachmentPath] error:nil];
    }
    
    // Recreate empty structure
    [self ensureResourcesExist];
    
    NSLog(@"[Ve] All logs and attachments have been cleared");
    return nil;
    }];
    [[VEAIStore sharedStore] postChange];
}

- (void)ensureResourcesExist {
    BOOL isDirectory;
    if (![_fileManager fileExistsAtPath:[LogManager logsAttachmentPath] isDirectory:&isDirectory]) {
        [_fileManager createDirectoryAtPath:[LogManager logsAttachmentPath] withIntermediateDirectories:YES attributes:nil error:nil];
    }

    if (![_fileManager fileExistsAtPath:[LogManager logsPath]]) {
        NSData* jsonData = [NSJSONSerialization dataWithJSONObject:[[NSMutableDictionary alloc] init] options:NSJSONWritingPrettyPrinted error:nil];
        [jsonData writeToFile:[LogManager logsPath] options:NSDataWritingAtomic error:nil];
    }
}
@end
