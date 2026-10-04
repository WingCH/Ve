#import <Foundation/Foundation.h>

// All processes use the same lock for logs and correction examples.
@interface VEAIStore : NSObject
@property(nonatomic, readonly, copy) NSString *directory;
+ (instancetype)sharedStore;
- (instancetype)initWithDirectory:(NSString *)directory;
- (id)performLocked:(id (^)(void))operation;
- (NSMutableDictionary *)readJSON:(NSString *)name;
- (BOOL)writeJSON:(NSDictionary *)json name:(NSString *)name;
- (NSDictionary *)notificationForRecordID:(NSString *)recordID;
- (BOOL)updateAIForRecordID:(NSString *)recordID requestID:(NSString *)requestID changes:(NSDictionary *)changes;
- (BOOL)updateManualForRecordID:(NSString *)recordID requestID:(NSString *)requestID changes:(NSDictionary *)changes;
- (NSDictionary *)correctionForRecordID:(NSString *)recordID;
- (BOOL)setCorrectionForRecordID:(NSString *)recordID shouldForward:(NSNumber *)shouldForward reason:(NSString *)reason;
- (NSArray *)examplesForApp:(NSString *)bundleIdentifier limit:(NSUInteger)limit blockedApps:(NSArray *)blockedApps;
- (BOOL)clearCorrections;
- (void)postChange;
@end
