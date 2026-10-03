#import <Foundation/Foundation.h>
#import "../Utils/NotificationIdentity.h"

static NSUInteger assertions;

static void check(BOOL condition, NSString *message) {
    assertions++;
    if (!condition) {
        fprintf(stderr, "FAIL: %s\n", [message UTF8String]);
        exit(1);
    }
}

static NSDictionary *notification(void) {
    return @{
        kLogKeyBundleIdentifier: @"com.example.messages",
        kLogKeyTitle: @"Alice",
        kLogKeyContent: @"Hello",
        kLogKeyDate: @"2026-10-03T12:00:00.123",
        kLogKeyBulletinID: @"message-1",
        kLogKeyBulletinVersionID: @"version-1"
    };
}

int main(int argc, const char *argv[]) {
    @autoreleasepool {
        if (argc != 3) {
            fprintf(stderr, "Usage: notification-replay-test --record|--verify history.json\n");
            return 2;
        }
        NSString *path = [NSString stringWithUTF8String:argv[2]];
        if (strcmp(argv[1], "--record") == 0) {
            NSData *data = [NSJSONSerialization dataWithJSONObject:@[notification()] options:0 error:NULL];
            check([data writeToFile:path atomically:YES], @"persist the notification before restarting");
            return 0;
        }
        check(strcmp(argv[1], "--verify") == 0, @"valid test mode");
        NSData *data = [NSData dataWithContentsOfFile:path];
        NSArray *logs = [NSJSONSerialization JSONObjectWithData:data options:0 error:NULL];
        check(logs.count == 1, @"load persisted history in a fresh process");
        NSDictionary *existing = [logs objectAtIndex:0];
        check(VEIsSameLoggedNotification(notification(), existing), @"suppress an unchanged notification restored after reboot");
        check(!VEIsSameLoggedNotification(notification(), @{}), @"forward a notification absent from history");

        NSMutableDictionary *updated = [notification() mutableCopy];
        [updated setObject:@"New message" forKey:kLogKeyContent];
        check(!VEIsSameLoggedNotification(updated, existing), @"forward changed content with the same bulletin ID and date");
        [updated release];

        updated = [notification() mutableCopy];
        [updated setObject:@"version-2" forKey:kLogKeyBulletinVersionID];
        check(!VEIsSameLoggedNotification(updated, existing), @"forward a new bulletin version");
        [updated release];

        updated = [notification() mutableCopy];
        [updated setObject:@"Updated title" forKey:kLogKeyTitle];
        check(!VEIsSameLoggedNotification(updated, existing), @"forward an updated title");
        [updated release];

        updated = [notification() mutableCopy];
        [updated setObject:@"New subtitle" forKey:kLogKeySubtitle];
        check(!VEIsSameLoggedNotification(updated, existing), @"retain subtitle updates");
        [updated release];

        updated = [notification() mutableCopy];
        [updated setObject:@"com.example.other" forKey:kLogKeyBundleIdentifier];
        check(!VEIsSameLoggedNotification(updated, existing), @"forward another app's notification at the same timestamp");
        [updated release];

        updated = [notification() mutableCopy];
        [updated setObject:@"message-2" forKey:kLogKeyBulletinID];
        check(!VEIsSameLoggedNotification(updated, existing), @"forward a distinct notification with identical content and time");
        [updated release];

        updated = [notification() mutableCopy];
        [updated setObject:@"2026-10-03T12:01:00.123" forKey:kLogKeyDate];
        check(!VEIsSameLoggedNotification(updated, existing), @"forward a later message even when its ID and content are reused");
        [updated release];

        NSMutableDictionary *legacy = [notification() mutableCopy];
        [legacy removeObjectForKey:kLogKeyBulletinID];
        [legacy removeObjectForKey:kLogKeyBulletinVersionID];
        check(VEIsSameLoggedNotification(notification(), legacy), @"recognize legacy saved logs without optional IDs");
        check(VEIsSameLoggedNotification(legacy, legacy), @"recognize repeated notifications without IDs");
        [legacy setObject:[NSNull null] forKey:kLogKeySubtitle];
        check(VEIsSameLoggedNotification(notification(), legacy), @"normalize missing and null optional subtitle fields");
        [legacy release];

        updated = [notification() mutableCopy];
        [updated removeObjectForKey:kLogKeyDate];
        check(!VEIsSameLoggedNotification(updated, existing), @"do not discard notifications without an identifiable timestamp");
        [updated release];
        printf("Notification replay regression tests passed (%lu assertions; history reloaded in a new process)\n", (unsigned long)assertions);
    }
    return 0;
}
