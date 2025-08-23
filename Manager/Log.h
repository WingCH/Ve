//
//  Log.h
//  Vē
//
//  Created by Alexandra Aurora Göttlicher
//

#import <Foundation/Foundation.h>

static NSString* const kLogsKeyLogs = @"logs";
static NSString* const kLogsKeyLastIdentifier = @"last_identifier";
static NSString* const kLogsKeyLastHousekeepingDate = @"last_housekeeping_date";
static NSString* const kLogKeyIdentifier = @"identifier";
static NSString* const kLogKeyBundleIdentifier = @"bundle_identifier";
static NSString* const kLogKeyTitle = @"title";
static NSString* const kLogKeySubtitle = @"subtitle";
static NSString* const kLogKeyContent = @"content";
static NSString* const kLogKeyDate = @"date";
static NSString* const kLogKeyPublicationDate = @"publication_date";
static NSString* const kLogKeyExpirationDate = @"expiration_date";
static NSString* const kLogKeyBulletinID = @"bulletin_id";
static NSString* const kLogKeyBulletinVersionID = @"bulletin_version_id";
static NSString* const kLogKeyThreadID = @"thread_id";
static NSString* const kLogKeyCategoryID = @"category_id";
static NSString* const kLogKeyClearable = @"clearable";
static NSString* const kLogKeyIgnoresQuietMode = @"ignores_quiet_mode";
static NSString* const kLogKeyTurnsOnDisplay = @"turns_on_display";
static NSString* const kLogKeyPlaySound = @"play_sound";
static NSString* const kLogKeyHasPrivateContent = @"has_private_content";
static NSString* const kLogKeySummaryArgument = @"summary_argument";
static NSString* const kLogKeySummaryArgumentCount = @"summary_argument_count";
static NSString* const kLogKeyTimeZone = @"time_zone";
static NSString* const kLogKeyRawBulletinData = @"raw_bulletin_data";
static NSString* const kLogInternalDateFormat = @"yyyy-MM-dd'T'HH:mm:ss.SSS";

@interface Log : NSObject
// Basic properties
@property(nonatomic, assign)NSUInteger identifier;
@property(nonatomic)NSString* bundleIdentifier;
@property(nonatomic)NSString* title;
@property(nonatomic)NSString* subtitle;
@property(nonatomic)NSString* content;
@property(nonatomic)NSDate* date;
@property(nonatomic)NSDate* publicationDate;
@property(nonatomic)NSDate* expirationDate;

// Identifiers
@property(nonatomic)NSString* bulletinID;
@property(nonatomic)NSString* bulletinVersionID;
@property(nonatomic)NSString* threadID;
@property(nonatomic)NSString* categoryID;

// Behavior properties
@property(nonatomic, assign)BOOL clearable;
@property(nonatomic, assign)BOOL ignoresQuietMode;
@property(nonatomic, assign)BOOL turnsOnDisplay;
@property(nonatomic, assign)BOOL playSound;
@property(nonatomic, assign)BOOL hasPrivateContent;

// Summary and content
@property(nonatomic)NSString* summaryArgument;
@property(nonatomic, assign)NSUInteger summaryArgumentCount;

// Time zone
@property(nonatomic)NSTimeZone* timeZone;

// Raw BBBulletin data for debugging
@property(nonatomic)NSDictionary* rawBulletinData;

- (instancetype)initWithBulletin:(id)bulletin identifier:(NSUInteger)identifier;
- (instancetype)initWithIdentifier:(NSUInteger)identifier bundleIdentifier:(NSString *)bundleIdentifier title:(NSString *)title content:(NSString *)content andDate:(NSDate *)date;
+ (Log *)logFromDictionary:(NSDictionary *)dictionary;
- (NSString *)getDisplayName;
@end
