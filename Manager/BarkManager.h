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

- (void)forwardNotificationWithTitle:(NSString *)title 
                             content:(NSString *)content 
                    bundleIdentifier:(NSString *)bundleIdentifier;

- (void)forwardNotificationWithTitle:(NSString *)title
                            subtitle:(NSString *)subtitle
                                body:(NSString *)body
                    bundleIdentifier:(NSString *)bundleIdentifier
                               level:(BarkNotificationLevel)level
                            threadID:(NSString *)threadID;

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

@end
