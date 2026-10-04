#import "VEAIManager.h"
#import "VEAIStore.h"
#import "VEAIPolicy.h"
#import "VEAIGate.h"
#import "VEAIClient.h"
#import "../Preferences/PreferenceKeys.h"

@implementation VEAIManager
+ (instancetype)sharedInstance {
    static VEAIManager *manager;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ manager = [self new]; });
    return manager;
}

- (void)forwardNotification:(NSDictionary *)notification completion:(void (^)(NSString *))completion {
    [self forwardNotification:notification trace:nil completion:completion];
}
- (void)forwardNotification:(NSDictionary *)notification trace:(void (^)(NSDictionary *))trace completion:(void (^)(NSString *))completion {
    [[BarkManager sharedInstance] forwardNotificationWithTitle:notification[@"title"] subtitle:nil
        body:notification[@"content"] bundleIdentifier:notification[@"bundle_identifier"]
        level:[notification[@"forward_level"] integerValue] threadID:notification[@"thread_id"]
        bulletinID:notification[@"bulletin_id"] trace:trace completion:completion];
}

- (void)processRecordID:(NSString *)recordID level:(BarkNotificationLevel)level {
    [self processRecordID:recordID notification:[[VEAIStore sharedStore] notificationForRecordID:recordID] level:level];
}

- (void)processRecordID:(NSString *)recordID notification:(NSDictionary *)snapshot level:(BarkNotificationLevel)level {
    NSDictionary *captured = [snapshot copy];
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_UTILITY, 0), ^{
        VEAIStore *store = [VEAIStore sharedStore];
        NSMutableDictionary *notification = [captured mutableCopy];
        if (!notification) return;
        notification[@"forward_level"] = @(level);
        NSUserDefaults *defaults = [[NSUserDefaults alloc] initWithSuiteName:kPreferencesIdentifier];
        NSArray *blocked = [defaults arrayForKey:kPreferenceKeyBlockedSenders] ?: @[];
        if ([blocked containsObject:notification[@"bundle_identifier"]]) {
            [store updateAIForRecordID:recordID requestID:nil changes:@{@"state": @"blocked", @"action": @"blocked"}];
            return;
        }
        NSDictionary *settings = [VEAIPolicy settingsFromDefaults:defaults];
        NSString *requestID = [NSUUID UUID].UUIDString;
        BOOL enabled = [settings[@"enabled"] boolValue];
        BOOL configured = [settings[@"token"] length] && (![settings[@"endpoint"] containsString:@"{account_id}"] || [settings[@"account_id"] length]);
        NSDictionary *initial = @{
            @"request_id": requestID, @"state": enabled ? (configured ? @"pending" : @"not_configured") : @"disabled",
            @"provider": settings[@"provider"], @"model": settings[@"model"], @"mode": settings[@"mode"], @"threshold": settings[@"threshold"],
            @"prompt_version": settings[@"prompt_version"], @"started_at": @([NSDate date].timeIntervalSince1970),
            @"api_log": @{@"state": enabled && configured ? @"pending" : @"not_requested", @"reason": enabled ? (configured ? @"awaiting_request" : @"not_configured") : @"disabled"}
        };
        if (![store updateAIForRecordID:recordID requestID:nil changes:initial]) {
            // History eviction or an unavailable metadata file must not swallow forwarding.
            [self forwardNotification:notification completion:nil];
            return;
        }
        void (^action)(BOOL, NSString *) = ^(BOOL forward, NSString *reason) {
            [store updateAIForRecordID:recordID requestID:requestID changes:@{@"action": reason, @"bark_status": forward ? @"sending" : @"not_attempted"}];
            [store updateAIForRecordID:recordID requestID:requestID changes:@{@"bark_api_log": @{@"state": forward ? @"pending" : @"not_requested", @"reason": reason}}];
            if (forward) [self forwardNotification:notification trace:^(NSDictionary *trace) {
                [store updateAIForRecordID:recordID requestID:requestID changes:@{@"bark_api_log": trace}];
            } completion:^(NSString *status) {
                [store updateAIForRecordID:recordID requestID:requestID changes:@{@"bark_status": status}];
            }];
        };
        // Optional AI: no token/account or a disabled switch means no request and no timer.
        if (!enabled || !configured) { action(YES, @"ai_skipped"); return; }
        NSArray *examples = [store examplesForApp:notification[@"bundle_identifier"] limit:10 blockedApps:blocked];
        NSMutableArray *exampleIDs = [NSMutableArray new];
        for (NSDictionary *example in examples) [exampleIDs addObject:example[@"record_id"]];
        [store updateAIForRecordID:recordID requestID:requestID changes:@{@"example_ids": exampleIDs}];
        VEAIGate *gate = [[VEAIGate alloc] initWithObserve:[settings[@"mode"] isEqual:@"observe"]
            timeout:[settings[@"timeout"] doubleValue] threshold:[settings[@"threshold"] doubleValue]
            action:action result:^(NSDictionary *info) {
                [store updateAIForRecordID:recordID requestID:requestID changes:info];
            }];
        [gate start];
        VEAIClient *client = [[VEAIClient alloc] initWithSession:[NSURLSession sharedSession]];
        [client evaluateNotification:notification settings:settings examples:examples trace:^(NSDictionary *trace) {
            [store updateAIForRecordID:recordID requestID:requestID changes:@{@"api_log": trace}];
        } completion:^(NSNumber *probability, NSString *errorCode) {
            [gate receiveProbability:probability errorCode:errorCode];
        }];
    });
}

- (void)resendRecordID:(NSString *)recordID completion:(void (^)(NSString *))completion {
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_UTILITY, 0), ^{
        VEAIStore *store = [VEAIStore sharedStore];
        NSMutableDictionary *notification = [[store notificationForRecordID:recordID] mutableCopy];
        if (!notification) { completion(@"deleted"); return; }
        notification[@"forward_level"] = @(BarkNotificationLevelActive);
        NSString *manualID = [NSUUID UUID].UUIDString;
        [store updateAIForRecordID:recordID requestID:nil changes:@{@"manual_request_id": manualID, @"manual_bark_status": @"sending", @"manual_bark_api_log": @{@"state": @"pending"}}];
        [self forwardNotification:notification trace:^(NSDictionary *trace) {
            [store updateManualForRecordID:recordID requestID:manualID changes:@{@"manual_bark_api_log": trace}];
        } completion:^(NSString *status) {
            [store updateManualForRecordID:recordID requestID:manualID changes:@{@"manual_bark_status": status}];
            completion(status);
        }];
    });
}
@end
