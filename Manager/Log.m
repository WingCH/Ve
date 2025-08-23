//
//  Log.m
//  Vē
//
//  Created by Alexandra Aurora Göttlicher
//

#import "Log.h"
#import <objc/runtime.h>
#import "../PrivateHeaders.h"
#import "../Utils/DateUtil.h"

@implementation Log

// Helper method to get all properties from BBBulletin using runtime reflection
- (NSDictionary *)getAllPropertiesFromBulletin:(BBBulletin *)bulletin {
    NSMutableDictionary* allProperties = [[NSMutableDictionary alloc] init];
    
    Class bulletinClass = [bulletin class];
    unsigned int propertyCount = 0;
    objc_property_t* properties = class_copyPropertyList(bulletinClass, &propertyCount);
    
    for (unsigned int i = 0; i < propertyCount; i++) {
        objc_property_t property = properties[i];
        NSString* propertyName = [NSString stringWithUTF8String:property_getName(property)];
        
        @try {
            // Attempt to get the property value using KVC
            id value = [bulletin valueForKey:propertyName];
            
            if (value) {
                // Convert various types to JSON-serializable objects
                if ([value isKindOfClass:[NSString class]] || 
                    [value isKindOfClass:[NSNumber class]]) {
                    allProperties[propertyName] = value;
                } else if ([value isKindOfClass:[NSDate class]]) {
                    allProperties[propertyName] = [(NSDate*)value description];
                } else if ([value isKindOfClass:[NSArray class]]) {
                    // Try to convert array elements
                    NSMutableArray* arrayItems = [[NSMutableArray alloc] init];
                    for (id item in (NSArray*)value) {
                        if ([item isKindOfClass:[NSString class]] || 
                            [item isKindOfClass:[NSNumber class]]) {
                            [arrayItems addObject:item];
                        } else {
                            [arrayItems addObject:[item description]];
                        }
                    }
                    allProperties[propertyName] = arrayItems;
                } else if ([value isKindOfClass:[NSURL class]]) {
                    allProperties[propertyName] = [(NSURL*)value absoluteString];
                } else if ([value isKindOfClass:[NSTimeZone class]]) {
                    allProperties[propertyName] = [(NSTimeZone*)value name];
                } else {
                    // For other complex objects, just use description
                    allProperties[propertyName] = [value description];
                }
            } else {
                allProperties[propertyName] = [NSNull null];
            }
        } @catch (NSException* exception) {
            // Some properties might not be accessible via KVC
            allProperties[propertyName] = @"<inaccessible>";
        }
    }
    
    free(properties);
    return allProperties;
}

- (instancetype)initWithBulletin:(BBBulletin *)bulletin identifier:(NSUInteger)identifier {
    self = [super init];

    if (self) {
        [self setIdentifier:identifier];
        [self setBundleIdentifier:[bulletin sectionID] ?: @"com.apple.springboard"];
        [self setTitle:[bulletin title] ?: @""];
        [self setSubtitle:[bulletin subtitle] ?: @""];
        [self setContent:[bulletin message] ?: @""];
        [self setDate:[bulletin date] ?: [NSDate date]];
        [self setPublicationDate:[bulletin publicationDate]];
        [self setExpirationDate:[bulletin expirationDate]];
        
        // Identifiers
        [self setBulletinID:[bulletin bulletinID]];
        [self setBulletinVersionID:[bulletin bulletinVersionID]];
        [self setThreadID:[bulletin threadID]];
        [self setCategoryID:[bulletin categoryID]];
        
        // Behavior properties
        [self setClearable:[bulletin clearable]];
        [self setIgnoresQuietMode:[bulletin ignoresQuietMode]];
        [self setTurnsOnDisplay:[bulletin turnsOnDisplay]];
        [self setPlaySound:[bulletin playSound]];
        [self setHasPrivateContent:[bulletin hasPrivateContent]];
        
        // Summary and content
        [self setSummaryArgument:[bulletin summaryArgument]];
        [self setSummaryArgumentCount:[bulletin summaryArgumentCount]];
        
        // Time zone
        [self setTimeZone:[bulletin timeZone]];
        
        // Store all raw BBBulletin data using runtime reflection
        [self setRawBulletinData:[self getAllPropertiesFromBulletin:bulletin]];
    }

    return self;
}

- (instancetype)initWithIdentifier:(NSUInteger)identifier bundleIdentifier:(NSString *)bundleIdentifier title:(NSString *)title content:(NSString *)content andDate:(NSDate *)date {
    self = [super init];

    if (self) {
        [self setIdentifier:identifier];
        [self setBundleIdentifier:bundleIdentifier];
        [self setTitle:title];
        [self setContent:content];
        [self setDate:date];
    }

    return self;
}

+ (Log *)logFromDictionary:(NSDictionary *)dictionary {
    NSUInteger identifier = [dictionary[kLogKeyIdentifier] unsignedIntegerValue];
    NSString* bundleIdentifier = dictionary[kLogKeyBundleIdentifier];
    NSString* title = dictionary[kLogKeyTitle];
    NSString* subtitle = dictionary[kLogKeySubtitle];
    NSString* content = dictionary[kLogKeyContent];
    NSDate* date = [DateUtil getDateFromString:dictionary[kLogKeyDate] withFormat:kLogInternalDateFormat];
    NSDate* publicationDate = dictionary[kLogKeyPublicationDate] ? [DateUtil getDateFromString:dictionary[kLogKeyPublicationDate] withFormat:kLogInternalDateFormat] : nil;
    NSDate* expirationDate = dictionary[kLogKeyExpirationDate] ? [DateUtil getDateFromString:dictionary[kLogKeyExpirationDate] withFormat:kLogInternalDateFormat] : nil;
    
    Log* log = [[Log alloc] initWithIdentifier:identifier bundleIdentifier:bundleIdentifier title:title content:content andDate:date];
    
    // Set additional properties
    [log setSubtitle:subtitle];
    [log setPublicationDate:publicationDate];
    [log setExpirationDate:expirationDate];
    
    // Identifiers
    [log setBulletinID:dictionary[kLogKeyBulletinID]];
    [log setBulletinVersionID:dictionary[kLogKeyBulletinVersionID]];
    [log setThreadID:dictionary[kLogKeyThreadID]];
    [log setCategoryID:dictionary[kLogKeyCategoryID]];
    
    // Behavior properties
    [log setClearable:[dictionary[kLogKeyClearable] boolValue]];
    [log setIgnoresQuietMode:[dictionary[kLogKeyIgnoresQuietMode] boolValue]];
    [log setTurnsOnDisplay:[dictionary[kLogKeyTurnsOnDisplay] boolValue]];
    [log setPlaySound:[dictionary[kLogKeyPlaySound] boolValue]];
    [log setHasPrivateContent:[dictionary[kLogKeyHasPrivateContent] boolValue]];
    
    // Summary and content
    [log setSummaryArgument:dictionary[kLogKeySummaryArgument]];
    [log setSummaryArgumentCount:[dictionary[kLogKeySummaryArgumentCount] unsignedIntegerValue]];
    
    // Time zone
    NSString* timeZoneName = dictionary[kLogKeyTimeZone];
    if (timeZoneName) {
        [log setTimeZone:[NSTimeZone timeZoneWithName:timeZoneName]];
    }
    
    // Raw bulletin data
    NSDictionary* rawData = dictionary[kLogKeyRawBulletinData];
    if (rawData) {
        [log setRawBulletinData:rawData];
    }
    
    return log;
}

- (NSString *)getDisplayName {
    LSApplicationProxy* applicationProxy = [objc_getClass("LSApplicationProxy") applicationProxyForIdentifier:[self bundleIdentifier]];
    return [applicationProxy localizedName] ?: @"SpringBoard";
}
@end
