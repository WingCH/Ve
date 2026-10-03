#ifndef VE_NOTIFICATION_IDENTITY_H
#define VE_NOTIFICATION_IDENTITY_H

#import <Foundation/Foundation.h>
#import "../Manager/Log.h"

static inline NSString *VENotificationIdentityString(id value) {
    return [value isKindOfClass:[NSString class]] ? value : @"";
}

// Match a retained bulletin replay without discarding real updates or other
// notifications that happen to share its timestamp. Missing optional fields
// remain compatible with logs written by earlier versions.
static inline BOOL VEIsSameLoggedNotification(NSDictionary *notification, NSDictionary *existing) {
    if (VENotificationIdentityString([notification objectForKey:kLogKeyDate]).length == 0 ||
        VENotificationIdentityString([notification objectForKey:kLogKeyBundleIdentifier]).length == 0) {
        return NO;
    }

    NSString *contentKeys[] = {
        kLogKeyDate, kLogKeyBundleIdentifier, kLogKeyTitle, kLogKeySubtitle, kLogKeyContent
    };
    for (NSUInteger i = 0; i < sizeof(contentKeys) / sizeof(contentKeys[0]); i++) {
        NSString *currentValue = VENotificationIdentityString([notification objectForKey:contentKeys[i]]);
        NSString *existingValue = VENotificationIdentityString([existing objectForKey:contentKeys[i]]);
        if (![currentValue isEqualToString:existingValue]) {
            return NO;
        }
    }

    NSString *identifierKeys[] = { kLogKeyBulletinID, kLogKeyBulletinVersionID };
    for (NSUInteger i = 0; i < sizeof(identifierKeys) / sizeof(identifierKeys[0]); i++) {
        NSString *currentValue = VENotificationIdentityString([notification objectForKey:identifierKeys[i]]);
        NSString *existingValue = VENotificationIdentityString([existing objectForKey:identifierKeys[i]]);
        if (currentValue.length > 0 && existingValue.length > 0 &&
            ![currentValue isEqualToString:existingValue]) {
            return NO;
        }
    }
    return YES;
}

#endif
