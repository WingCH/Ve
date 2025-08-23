//
//  BarkManager.h
//  Vē
//
//  Created by Alexandra Aurora Göttlicher
//

#import <Foundation/Foundation.h>
#import "../PrivateHeaders.h"

typedef NS_ENUM(NSInteger, BarkNotificationLevel) {
    BarkNotificationLevelActive = 0,    // Default level
    BarkNotificationLevelTimeSensitive,
    BarkNotificationLevelPassive
};

@interface BarkManager : NSObject

+ (instancetype)sharedInstance;

// Main entry point - called by VeCore.m
- (void)forwardNotificationWithTitle:(NSString *)title
                            subtitle:(NSString *)subtitle
                                body:(NSString *)body
                    bundleIdentifier:(NSString *)bundleIdentifier
                               level:(BarkNotificationLevel)level
                            threadID:(NSString *)threadID
                          bulletinID:(NSString *)bulletinID;

// Convenience method to generate bulletinID based on notification content
- (NSString *)generateBulletinIDForBundleIdentifier:(NSString *)bundleIdentifier
                                              title:(NSString *)title;

// Get app display name for bundle identifier
- (NSString *)getAppDisplayNameForBundleIdentifier:(NSString *)bundleIdentifier;

// Get app icon URL from iTunes API with caching
- (void)getAppIconURLForBundleIdentifier:(NSString *)bundleIdentifier 
                              completion:(void (^)(NSString *iconURL))completion;

// Clear iTunes API cache
- (void)clearITunesAPICache;

@end
