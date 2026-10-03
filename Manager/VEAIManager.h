#import <Foundation/Foundation.h>
#import "BarkManager.h"

@interface VEAIManager : NSObject
+ (instancetype)sharedInstance;
- (void)processRecordID:(NSString *)recordID level:(BarkNotificationLevel)level;
- (void)processRecordID:(NSString *)recordID notification:(NSDictionary *)notification level:(BarkNotificationLevel)level;
- (void)resendRecordID:(NSString *)recordID completion:(void (^)(NSString *))completion;
@end
