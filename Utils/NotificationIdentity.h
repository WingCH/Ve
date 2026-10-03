#ifndef VE_NOTIFICATION_IDENTITY_H
#define VE_NOTIFICATION_IDENTITY_H

#import <Foundation/Foundation.h>
#import "../Manager/Log.h"

static inline NSString *VENotificationIdentityString(id value) {
    return [value isKindOfClass:[NSString class]] ? value : @"";
}

static inline NSString *VENotificationPublisherIdentifier(NSDictionary *notification) {
    id rawBulletin = [notification objectForKey:kLogKeyRawBulletinData];
    if (![rawBulletin isKindOfClass:[NSDictionary class]]) {
        return @"";
    }
    return VENotificationIdentityString([rawBulletin objectForKey:@"publisherBulletinID"]);
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

    // Respring regenerates transport IDs for a retained publisher request.
    // The original date and content above still distinguish later updates.
    NSString *currentPublisher = VENotificationPublisherIdentifier(notification);
    NSString *existingPublisher = VENotificationPublisherIdentifier(existing);
    if (currentPublisher.length > 0 && existingPublisher.length > 0) {
        return [currentPublisher isEqualToString:existingPublisher];
    }

    // Legacy logs without a publisher ID retain the conservative ID check.
    // A version-only refresh does not change the notification's content.
    NSString *identifierKeys[] = { kLogKeyBulletinID };
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
