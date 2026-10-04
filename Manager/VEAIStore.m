#import "VEAIStore.h"
#import <CoreFoundation/CoreFoundation.h>
#import <sys/file.h>
#import <fcntl.h>
#import <unistd.h>
#if !VE_HOST_TEST
#import "../Utils/JailbreakPath.h"
#endif

@interface VEAIStore ()
@property(nonatomic, copy, readwrite) NSString *directory;
@property(nonatomic, strong) NSRecursiveLock *threadLock;
@property(nonatomic) NSUInteger lockDepth;
@end

@implementation VEAIStore
+ (instancetype)sharedStore {
    static VEAIStore *store;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
#if VE_HOST_TEST
        NSString *directory = [NSProcessInfo processInfo].environment[@"VE_TEST_DIRECTORY"];
        NSAssert(directory.length, @"VE_TEST_DIRECTORY is required for host tests");
#else
        NSString *directory = VEJailbreakRootPath(@"/var/mobile/Library/codes.wingchan.ve-enhanced");
#endif
        store = [[self alloc] initWithDirectory:directory];
    });
    return store;
}

- (instancetype)initWithDirectory:(NSString *)directory {
    self = [super init];
    if (self) {
        _directory = [directory copy];
        _threadLock = [NSRecursiveLock new];
    }
    return self;
}

- (id)performLocked:(id (^)(void))operation {
    [self.threadLock lock];
    int descriptor = -1;
    if (self.lockDepth == 0) {
        [[NSFileManager defaultManager] createDirectoryAtPath:self.directory withIntermediateDirectories:YES attributes:nil error:nil];
        NSString *path = [self.directory stringByAppendingPathComponent:@"state.lock"];
        descriptor = open(path.fileSystemRepresentation, O_CREAT | O_RDWR, 0600);
        if (descriptor < 0 || flock(descriptor, LOCK_EX) != 0) {
            if (descriptor >= 0) close(descriptor);
            [self.threadLock unlock];
            return nil;
        }
    }
    self.lockDepth++;
    id result;
    @try {
        result = operation();
    } @finally {
        self.lockDepth--;
        if (descriptor >= 0) {
            flock(descriptor, LOCK_UN);
            close(descriptor);
        }
        [self.threadLock unlock];
    }
    return result;
}

// Call these two helpers within performLocked: for read-modify-write operations.
- (NSMutableDictionary *)readJSON:(NSString *)name {
    NSString *path = [self.directory stringByAppendingPathComponent:name];
    if (![[NSFileManager defaultManager] fileExistsAtPath:path]) return [NSMutableDictionary new];
    NSData *data = [NSData dataWithContentsOfFile:path];
    if (!data) return nil;
    id json = [NSJSONSerialization JSONObjectWithData:data options:NSJSONReadingMutableContainers error:nil];
    // Preserve unreadable files rather than replacing them with an empty history.
    return [json isKindOfClass:[NSMutableDictionary class]] ? json : nil;
}

- (BOOL)writeJSON:(NSDictionary *)json name:(NSString *)name {
    if (!json || ![NSJSONSerialization isValidJSONObject:json]) return NO;
    NSData *data = [NSJSONSerialization dataWithJSONObject:json options:0 error:nil];
    NSString *path = [self.directory stringByAppendingPathComponent:name];
    return data && [data writeToFile:path options:NSDataWritingAtomic error:nil];
}

- (NSDictionary *)notificationForRecordID:(NSString *)recordID {
    if (!recordID.length) return nil;
    return [self performLocked:^id {
        for (NSDictionary *log in [self readJSON:@"logs.json"][@"logs"]) {
            if ([log[@"record_id"] isEqual:recordID]) {
                NSMutableDictionary *copy = [log mutableCopy];
                NSDictionary *correction = [self correctionForRecordID:recordID];
                if (correction) copy[@"correction"] = correction;
                else [copy removeObjectForKey:@"correction"];
                return copy;
            }
        }
        return nil;
    }];
}

- (BOOL)updateAIForRecordID:(NSString *)recordID requestID:(NSString *)requestID changes:(NSDictionary *)changes {
    return [self updateRecordID:recordID matchKey:@"request_id" requestID:requestID changes:changes];
}
- (BOOL)updateManualForRecordID:(NSString *)recordID requestID:(NSString *)requestID changes:(NSDictionary *)changes {
    return [self updateRecordID:recordID matchKey:@"manual_request_id" requestID:requestID changes:changes];
}
- (BOOL)updateRecordID:(NSString *)recordID matchKey:(NSString *)matchKey requestID:(NSString *)requestID changes:(NSDictionary *)changes {
    if (!recordID.length) return NO;
    NSNumber *result = [self performLocked:^id {
        NSMutableDictionary *json = [self readJSON:@"logs.json"];
        for (NSMutableDictionary *log in json[@"logs"]) {
            if (![log[@"record_id"] isEqual:recordID]) continue;
            NSMutableDictionary *info = [log[@"ai"] mutableCopy] ?: [NSMutableDictionary new];
            if (requestID && ![info[matchKey] isEqual:requestID]) return @NO;
            [info addEntriesFromDictionary:changes];
            log[@"ai"] = info;
            return @([self writeJSON:json name:@"logs.json"]);
        }
        // Deleted notifications and pre-reset requests never recreate a record.
        return @NO;
    }];
    if (result.boolValue) [self postChange];
    return result.boolValue;
}

- (NSDictionary *)correctionForRecordID:(NSString *)recordID {
    if (!recordID.length) return nil;
    return [self performLocked:^id {
        return [self readJSON:@"corrections.json"][@"examples"][recordID];
    }];
}

- (BOOL)setCorrectionForRecordID:(NSString *)recordID shouldForward:(NSNumber *)shouldForward reason:(NSString *)reason {
    if (!recordID.length) return NO;
    NSNumber *result = [self performLocked:^id {
        NSDictionary *log = [self notificationForRecordID:recordID];
        if (!log) return @NO;
        NSMutableDictionary *json = [self readJSON:@"corrections.json"];
        if (!json) return @NO;
        NSMutableDictionary *examples = [json[@"examples"] mutableCopy] ?: [NSMutableDictionary new];
        if (shouldForward) {
            examples[recordID] = @{
                @"record_id": recordID, @"bundle_identifier": log[@"bundle_identifier"] ?: @"",
                @"title": log[@"title"] ?: @"", @"body": log[@"content"] ?: @"",
                @"should_forward": @(shouldForward.boolValue), @"reason": reason ?: @"",
                @"corrected_at": @([NSDate date].timeIntervalSince1970)
            };
        } else {
            [examples removeObjectForKey:recordID];
        }
        json[@"examples"] = examples;
        return @([self writeJSON:json name:@"corrections.json"]);
    }];
    if (result.boolValue) [self postChange];
    return result.boolValue;
}

- (NSArray *)examplesForApp:(NSString *)bundleIdentifier limit:(NSUInteger)limit blockedApps:(NSArray *)blockedApps {
    if (!bundleIdentifier.length || [blockedApps containsObject:bundleIdentifier]) return @[];
    NSArray *result = [self performLocked:^id {
        NSDictionary *examples = [self readJSON:@"corrections.json"][@"examples"];
        NSMutableArray *matching = [NSMutableArray new];
        for (NSDictionary *example in examples.allValues) {
            if ([example[@"bundle_identifier"] isEqual:bundleIdentifier]) [matching addObject:example];
        }
        [matching sortUsingComparator:^NSComparisonResult(NSDictionary *a, NSDictionary *b) {
            NSComparisonResult order = [b[@"corrected_at"] compare:a[@"corrected_at"]];
            return order == NSOrderedSame ? [a[@"record_id"] compare:b[@"record_id"]] : order;
        }];
        return [matching subarrayWithRange:NSMakeRange(0, MIN(limit, matching.count))];
    }];
    return result ?: @[];
}

- (BOOL)clearCorrections {
    NSNumber *result = [self performLocked:^id {
        return @([self writeJSON:@{@"examples": @{}} name:@"corrections.json"]);
    }];
    if (result.boolValue) [self postChange];
    return result.boolValue;
}

- (void)postChange {
    CFNotificationCenterPostNotification(CFNotificationCenterGetDarwinNotifyCenter(), CFSTR("codes.wingchan.ve-enhanced.logs.changed"), NULL, NULL, YES);
}
@end
