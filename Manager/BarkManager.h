//
//  BarkManager.h
//  Vē
//
//  Created by Alexandra Aurora Göttlicher
//

#import <Foundation/Foundation.h>
#import "../PrivateHeaders.h"

@interface BarkManager : NSObject

+ (instancetype)sharedInstance;
- (void)forwardNotificationWithTitle:(NSString *)title content:(NSString *)content bundleIdentifier:(NSString *)bundleIdentifier;

@end
