#import <Foundation/Foundation.h>
#import "../Manager/VEAIStore.h"
#import "../Manager/VEAIPolicy.h"
#import "../Manager/VEAIGate.h"
#import "../Manager/VEAIManager.h"
#import "../Preferences/PreferenceKeys.h"
#include <stdatomic.h>

static NSUInteger assertions;
static void check(BOOL condition, NSString *name) {
    assertions++;
    if (!condition) { fprintf(stderr, "FAIL: %s\n", name.UTF8String); exit(1); }
}
static BOOL waitFor(BOOL (^condition)(void), double seconds) {
    NSDate *end = [NSDate dateWithTimeIntervalSinceNow:seconds];
    while (!condition() && [end timeIntervalSinceNow] > 0) {
        [[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode beforeDate:[NSDate dateWithTimeIntervalSinceNow:0.01]];
    }
    return condition();
}
static NSData *encoded(id json) { return [NSJSONSerialization dataWithJSONObject:json options:0 error:nil]; }
static NSMutableDictionary *notification(NSString *record, NSString *app) {
    return [@{@"record_id": record, @"bundle_identifier": app, @"title": @"合成通知", @"content": @"測試通知，沒有私人資料", @"date": @"2026-10-04T00:00:00.000", @"bulletin_id": record} mutableCopy];
}
static void seed(VEAIStore *store) {
    [store performLocked:^id {
        NSMutableArray *logs = [NSMutableArray new];
        for (int i = 0; i < 12; i++) [logs addObject:notification([NSString stringWithFormat:@"a%d", i], @"app.a")];
        [logs addObject:notification(@"b0", @"app.b")];
        check([store writeJSON:@{@"logs": logs} name:@"logs.json"], @"seed isolated notifications");
        return nil;
    }];
    check([store clearCorrections], @"clear isolated examples");
}
static void unit(VEAIStore *store) {
    seed(store);
    for (int i = 0; i < 12; i++) check([store setCorrectionForRecordID:[NSString stringWithFormat:@"a%d", i] shouldForward:@YES reason:@"帳單提醒"], @"persist correction");
    check([store setCorrectionForRecordID:@"b0" shouldForward:@NO reason:@"促銷"], @"persist another app's correction");
    NSArray *examples = [store examplesForApp:@"app.a" limit:10 blockedApps:@[]];
    check(examples.count == 10 && [examples[0][@"record_id"] isEqual:@"a11"], @"select the latest ten corrections for the same app");
    for (NSDictionary *example in examples) check([example[@"bundle_identifier"] isEqual:@"app.a"], @"exclude other apps");
    check([store examplesForApp:@"app.a" limit:10 blockedApps:@[@"app.a"]].count == 0, @"do not transmit blocked app examples");
    check([store setCorrectionForRecordID:@"a0" shouldForward:@NO reason:@"updated"], @"edit existing correction");
    check([[store examplesForApp:@"app.a" limit:10 blockedApps:@[]][0][@"record_id"] isEqual:@"a0"], @"edits change recency without duplicating examples");
    check([store updateAIForRecordID:@"a0" requestID:nil changes:@{@"request_id": @"r1", @"state": @"classified", @"decision": @"skip", @"skip_probability": @0.97}], @"save original AI judgement");
    check([store setCorrectionForRecordID:@"a0" shouldForward:@YES reason:@"keep"], @"human override");
    check([[store notificationForRecordID:@"a0"][@"ai"][@"decision"] isEqual:@"skip"], @"human corrections preserve original AI output");
    check(![store updateAIForRecordID:@"a0" requestID:@"obsolete" changes:@{@"decision": @"forward"}], @"reject obsolete requests");
    [store performLocked:^id {
        NSMutableDictionary *json = [store readJSON:@"logs.json"];
        NSIndexSet *indices = [json[@"logs"] indexesOfObjectsPassingTest:^BOOL(NSDictionary *log, NSUInteger index, BOOL *stop) { return [log[@"record_id"] isEqual:@"a11"]; }];
        [json[@"logs"] removeObjectsAtIndexes:indices];
        check([store writeJSON:json name:@"logs.json"], @"delete source log");
        return nil;
    }];
    check([store correctionForRecordID:@"a11"] != nil, @"corrections survive source deletion");
    check(![store updateAIForRecordID:@"a11" requestID:nil changes:@{@"state": @"classified"}], @"late replies do not recreate deleted logs");
    check(![store setCorrectionForRecordID:@"a11" shouldForward:@NO reason:nil], @"stale UI cannot recreate a deleted source");
    check([store setCorrectionForRecordID:@"a0" shouldForward:nil reason:nil], @"undo correction");
    check([store correctionForRecordID:@"a0"] == nil, @"undone correction leaves future context");
    NSUserDefaults *defaults = [[NSUserDefaults alloc] initWithSuiteName:kPreferencesIdentifier];
    [defaults removePersistentDomainForName:kPreferencesIdentifier];
    NSDictionary *settings = [VEAIPolicy settingsFromDefaults:defaults];
    check([settings[@"mode"] isEqual:@"observe"] && [settings[@"model"] isEqual:@"clef"], @"default observation with Clef");
    check([settings[@"timeout"] doubleValue] == 2 && [settings[@"threshold"] doubleValue] == 0.9, @"default timing and gate threshold");
    [VEAIPolicy setToken:@"cloud-key" provider:@"cloudflare" defaults:defaults];
    [defaults setObject:@"systemone" forKey:kPreferenceKeyAIProvider];
    settings = [VEAIPolicy settingsFromDefaults:defaults];
    check([settings[@"token"] length] == 0, @"provider switch does not send another provider's token");
    check([settings[@"model"] isEqual:@"jev-latest"] && [settings[@"endpoint"] isEqual:@"https://api.typesafe.ai/v1/systemone"], @"Jev preset");
    [VEAIPolicy setToken:@"system-key" provider:@"systemone" defaults:defaults];
    [VEAIPolicy setEndpoint:@"http://127.0.0.1:8080/v1/systemone" provider:@"systemone" defaults:defaults];
    [defaults setObject:@"current rules" forKey:kPreferenceKeyAIPrompt];
    settings = [VEAIPolicy settingsFromDefaults:defaults];
    NSDictionary *request = [VEAIPolicy requestForNotification:notification(@"x", @"app.a") settings:settings examples:examples];
    check([request[@"state"][@"current_policy"][@"rules"] isEqual:@"current rules"], @"use latest custom prompt with context");
    check([request[@"questions"][@"skip_bark"][@"type"] isEqual:@"noul"], @"typed yes/no question");
    check([request[@"state"][@"corrected_examples"] count] == 10, @"send selected corrections as request context");
    [defaults setObject:@"cloudflare" forKey:kPreferenceKeyAIProvider];
    settings = [VEAIPolicy settingsFromDefaults:defaults];
    check([settings[@"token"] isEqual:@"cloud-key"] && [settings[@"endpoint"] hasPrefix:@"https://api.cloudflare.com/"], @"provider settings remain isolated");
    NSDictionary *answer = @{@"answers": @{@"skip_bark": @{@"type": @"noul", @"noul": @0.97}}};
    check([[VEAIPolicy skipProbabilityFromResponse:encoded(@{@"success": @YES, @"result": answer}) statusCode:200 provider:@"cloudflare"] doubleValue] == 0.97, @"decode Cloudflare wrapper");
    check([[VEAIPolicy skipProbabilityFromResponse:encoded(answer) statusCode:200 provider:@"systemone"] doubleValue] == 0.97, @"decode System One response");
    check([VEAIPolicy skipProbabilityFromResponse:encoded(answer) statusCode:200 provider:@"cloudflare"] == nil, @"reject wrong provider response");
    check([VEAIPolicy skipProbabilityFromResponse:encoded(@{@"success": @NO, @"result": answer}) statusCode:200 provider:@"cloudflare"] == nil, @"reject API failure");
    for (id value in @[@YES, @(-0.01), @1.01, @"0.99", [NSNull null]]) {
        check([VEAIPolicy skipProbabilityFromResponse:encoded(@{@"answers": @{@"skip_bark": @{@"noul": value}}}) statusCode:200 provider:@"systemone"] == nil, @"reject malformed probability");
    }
    check([VEAIPolicy skipProbabilityFromResponse:encoded(answer) statusCode:429 provider:@"systemone"] == nil, @"reject rate limit response");
    check([VEAIPolicy skipProbabilityFromResponse:encoded(@{@"answers": @[]}) statusCode:200 provider:@"systemone"] == nil, @"reject malformed answers");
    check([[VEAIPolicy decisionForProbability:@0.90 threshold:0.90] isEqual:@"skip"], @"threshold boundary");
    check([[VEAIPolicy decisionForProbability:@0.7 threshold:0.90] isEqual:@"uncertain"], @"uncertain decisions stay open");
    check([store clearCorrections] && ![store correctionForRecordID:@"b0"], @"clear all examples");
    check([store notificationForRecordID:@"a0"] != nil, @"clearing examples preserves source notifications");
    [defaults removePersistentDomainForName:kPreferencesIdentifier];
}

static atomic_int barkCount, requestCount;
static double fakeScore, fakeDelay;
static NSInteger fakeStatus;
static NSMutableArray *capturedRequests;
@interface FakeAIProtocol : NSURLProtocol
@property(nonatomic) BOOL stopped;
@end
@implementation FakeAIProtocol
+ (BOOL)canInitWithRequest:(NSURLRequest *)request { return [@[@"api.cloudflare.com", @"api.typesafe.ai", @"fixture.invalid"] containsObject:request.URL.host]; }
+ (NSURLRequest *)canonicalRequestForRequest:(NSURLRequest *)request { return request; }
- (void)startLoading {
    atomic_fetch_add(&requestCount, 1);
    NSData *data = self.request.HTTPBody;
    if (!data && self.request.HTTPBodyStream) {
        NSInputStream *stream = self.request.HTTPBodyStream;
        [stream open];
        NSMutableData *buffer = [NSMutableData new];
        uint8_t bytes[4096]; NSInteger count;
        while ((count = [stream read:bytes maxLength:sizeof(bytes)]) > 0) [buffer appendBytes:bytes length:(NSUInteger)count];
        [stream close]; data = buffer;
    }
    NSDictionary *body = data ? [NSJSONSerialization JSONObjectWithData:data options:0 error:nil] : nil;
    @synchronized ([FakeAIProtocol class]) { [capturedRequests addObject:body ?: @{}]; }
    double score = fakeScore, delay = fakeDelay; NSInteger status = fakeStatus;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delay * NSEC_PER_SEC)), dispatch_get_global_queue(QOS_CLASS_DEFAULT, 0), ^{
        if (self.stopped) return;
        NSDictionary *answer = @{@"model": body[@"model"] ?: @"unknown", @"answers": @{@"skip_bark": @{@"type": @"noul", @"noul": @(score)}}};
        id responseBody = [self.request.URL.host isEqual:@"api.cloudflare.com"] ? @{@"success": @YES, @"result": answer} : answer;
        NSHTTPURLResponse *response = [[NSHTTPURLResponse alloc] initWithURL:self.request.URL statusCode:status HTTPVersion:@"HTTP/1.1" headerFields:@{@"Content-Type": @"application/json"}];
        [self.client URLProtocol:self didReceiveResponse:response cacheStoragePolicy:NSURLCacheStorageNotAllowed];
        [self.client URLProtocol:self didLoadData:encoded(responseBody)];
        [self.client URLProtocolDidFinishLoading:self];
    });
}
- (void)stopLoading { self.stopped = YES; }
@end

// This fixture proves forwarding decisions, not Bark delivery.
@implementation BarkManager
+ (instancetype)sharedInstance { static BarkManager *manager; static dispatch_once_t once; dispatch_once(&once, ^{ manager = [self new]; }); return manager; }
- (void)forwardNotificationWithTitle:(NSString *)title subtitle:(NSString *)subtitle body:(NSString *)body bundleIdentifier:(NSString *)bundleIdentifier level:(BarkNotificationLevel)level threadID:(NSString *)threadID bulletinID:(NSString *)bulletinID completion:(void (^)(NSString *))completion {
    atomic_fetch_add(&barkCount, 1);
    if (completion) completion(@"accepted");
}
@end

static NSString *addRecord(VEAIStore *store, NSString *app) {
    NSString *record = [NSUUID UUID].UUIDString;
    [store performLocked:^id {
        NSMutableDictionary *json = [store readJSON:@"logs.json"];
        NSMutableArray *logs = json[@"logs"] ?: [NSMutableArray new];
        [logs addObject:notification(record, app)]; json[@"logs"] = logs;
        check([store writeJSON:json name:@"logs.json"], @"append isolated notification");
        return nil;
    }];
    return record;
}
static NSDictionary *info(VEAIStore *store, NSString *record) { return [store notificationForRecordID:record][@"ai"]; }
static void process(NSString *record) { [[VEAIManager sharedInstance] processRecordID:record level:BarkNotificationLevelActive]; }
static void managerTests(VEAIStore *store) {
    seed(store);
    capturedRequests = [NSMutableArray new];
    [NSURLProtocol registerClass:[FakeAIProtocol class]];
    fakeStatus = 200; fakeScore = 0.97; fakeDelay = 0;
    NSUserDefaults *defaults = [[NSUserDefaults alloc] initWithSuiteName:kPreferencesIdentifier];
    [defaults removePersistentDomainForName:kPreferencesIdentifier];
    [defaults setBool:YES forKey:kPreferenceKeyAIEnabled];
    [defaults setObject:@"systemone" forKey:kPreferenceKeyAIProvider];
    NSString *record = addRecord(store, @"app.a"); process(record);
    check(waitFor(^BOOL { return [info(store, record)[@"bark_status"] isEqual:@"accepted"]; }, 2), @"no token immediately follows the original forwarding route");
    check(atomic_load(&requestCount) == 0 && [info(store, record)[@"state"] isEqual:@"not_configured"], @"no token creates no AI request");
    [VEAIPolicy setToken:@"synthetic-test-token" provider:@"systemone" defaults:defaults];
    [defaults setBool:NO forKey:kPreferenceKeyAIEnabled];
    record = addRecord(store, @"app.a"); process(record);
    check(waitFor(^BOOL { return [info(store, record)[@"bark_status"] isEqual:@"accepted"]; }, 2) && atomic_load(&requestCount) == 0, @"disabled AI creates no request");
    [defaults setBool:YES forKey:kPreferenceKeyAIEnabled];
    [defaults setDouble:0.5 forKey:kPreferenceKeyAITimeout];
    [defaults setObject:@"observe" forKey:kPreferenceKeyAIMode];
    record = addRecord(store, @"app.a"); process(record);
    check(waitFor(^BOOL { return [info(store, record)[@"state"] isEqual:@"classified"] && [info(store, record)[@"bark_status"] isEqual:@"accepted"]; }, 3), @"observation completes the typed request");
    check([info(store, record)[@"decision"] isEqual:@"skip"] && [info(store, record)[@"action"] isEqual:@"observe"], @"observation preserves both AI skip and actual forwarding");
    [defaults setObject:@"filter" forKey:kPreferenceKeyAIMode];
    int before = atomic_load(&barkCount);
    record = addRecord(store, @"app.a"); process(record);
    check(waitFor(^BOOL { return [info(store, record)[@"action"] isEqual:@"skip"]; }, 3) && atomic_load(&barkCount) == before, @"confident filter skips Bark");
    NSString *corrected = record;
    check([store setCorrectionForRecordID:corrected shouldForward:@YES reason:@"this is a reminder"], @"correct a skipped notification");
    check(atomic_load(&barkCount) == before, @"correction never automatically resends");
    [[VEAIManager sharedInstance] resendRecordID:corrected completion:^(NSString *status) {}];
    check(waitFor(^BOOL { return [info(store, corrected)[@"manual_bark_status"] isEqual:@"accepted"]; }, 2) && atomic_load(&barkCount) == before + 1, @"explicit resend has its own result");
    check([info(store, corrected)[@"decision"] isEqual:@"skip"], @"resend preserves original AI judgement");
    [defaults setObject:@"latest prompt" forKey:kPreferenceKeyAIPrompt];
    fakeScore = 0.02; record = addRecord(store, @"app.a"); process(record);
    check(waitFor(^BOOL { return [info(store, record)[@"bark_status"] isEqual:@"accepted"]; }, 3), @"keep decision forwards");
    NSDictionary *last;
    @synchronized ([FakeAIProtocol class]) { last = capturedRequests.lastObject; }
    check([last[@"state"][@"current_policy"][@"rules"] isEqual:@"latest prompt"], @"pipeline transmits the latest prompt");
    check([last[@"state"][@"corrected_examples"][0][@"record_id"] isEqual:corrected], @"pipeline transmits the corrected same-app example");
    fakeScore = 0.7; record = addRecord(store, @"app.a"); process(record);
    check(waitFor(^BOOL { return [info(store, record)[@"bark_status"] isEqual:@"accepted"]; }, 3) && [info(store, record)[@"action"] isEqual:@"uncertain"], @"uncertain result forwards");
    fakeStatus = 500; record = addRecord(store, @"app.a"); process(record);
    check(waitFor(^BOOL { return [info(store, record)[@"bark_status"] isEqual:@"accepted"]; }, 3) && [info(store, record)[@"state"] isEqual:@"failed"], @"API failure forwards");
    fakeStatus = 200; fakeScore = 0.99; fakeDelay = 0.2;
    [defaults setDouble:0.05 forKey:kPreferenceKeyAITimeout];
    before = atomic_load(&barkCount); record = addRecord(store, @"app.a"); process(record);
    check(waitFor(^BOOL { return [info(store, record)[@"bark_status"] isEqual:@"accepted"]; }, 2), @"timeout forwards");
    check(waitFor(^BOOL { return [info(store, record)[@"state"] isEqual:@"classified"]; }, 2), @"late AI response is recorded");
    check(atomic_load(&barkCount) == before + 1 && [info(store, record)[@"action"] isEqual:@"timeout"] && [info(store, record)[@"late"] boolValue], @"late skip neither undoes nor repeats forwarding");
    int requestsBefore = atomic_load(&requestCount);
    [defaults setObject:@[@"app.a"] forKey:kPreferenceKeyBlockedSenders];
    record = addRecord(store, @"app.a"); process(record);
    check(waitFor(^BOOL { return [info(store, record)[@"state"] isEqual:@"blocked"]; }, 2) && atomic_load(&requestCount) == requestsBefore, @"blocked app has no AI request");
    [defaults setObject:@[] forKey:kPreferenceKeyBlockedSenders];
    [defaults setObject:@"cloudflare" forKey:kPreferenceKeyAIProvider];
    [defaults setObject:@"00000000000000000000000000000000" forKey:kPreferenceKeyAIAccountID];
    [VEAIPolicy setToken:@"synthetic-cloud-token" provider:@"cloudflare" defaults:defaults];
    [defaults setDouble:0.5 forKey:kPreferenceKeyAITimeout];
    fakeDelay = 0; record = addRecord(store, @"app.b"); process(record);
    check(waitFor(^BOOL { return [info(store, record)[@"action"] isEqual:@"skip"]; }, 3), @"Cloudflare route decodes its wrapper");
    @synchronized ([FakeAIProtocol class]) { last = capturedRequests.lastObject; }
    check([last[@"model"] isEqual:@"clef"] && [last[@"state"][@"corrected_examples"] count] == 0, @"Cloudflare uses Clef without another app's corrections");
    before = atomic_load(&barkCount);
    [[VEAIManager sharedInstance] processRecordID:@"already-evicted" notification:notification(@"already-evicted", @"app.b") level:BarkNotificationLevelActive];
    check(waitFor(^BOOL { return atomic_load(&barkCount) == before + 1; }, 2), @"history eviction does not swallow the captured notification");
    [defaults removePersistentDomainForName:kPreferencesIdentifier];
    [defaults synchronize];
    [NSURLProtocol unregisterClass:[FakeAIProtocol class]];
}

int main(int argc, char **argv) {
    @autoreleasepool {
        check(argc == 2, @"test mode specified");
        VEAIStore *store = [VEAIStore sharedStore];
        NSString *mode = @(argv[1]);
        if ([mode isEqual:@"--unit"]) unit(store);
        else if ([mode isEqual:@"--write-ai"]) {
            for (int i = 0; i < 100; i++) check([store updateAIForRecordID:@"a0" requestID:@"r1" changes:@{@"iteration": @(i)}], @"concurrent AI update");
        } else if ([mode isEqual:@"--write-correction"]) {
            for (int i = 0; i < 100; i++) check([store setCorrectionForRecordID:@"a0" shouldForward:@YES reason:[NSString stringWithFormat:@"iteration-%d", i]], @"concurrent correction");
        } else if ([mode isEqual:@"--verify-concurrency"]) {
            check([info(store, @"a0")[@"iteration"] intValue] == 99, @"cross-process AI updates survive");
            check([[store correctionForRecordID:@"a0"][@"reason"] isEqual:@"iteration-99"], @"cross-process human updates survive");
        } else if ([mode isEqual:@"--manager"]) managerTests(store);
        else return 2;
        printf("%s: %lu assertions passed\n", mode.UTF8String, (unsigned long)assertions);
    }
    return 0;
}
