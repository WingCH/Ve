#import <Foundation/Foundation.h>

@interface VEAIClient : NSObject
- (instancetype)initWithSession:(NSURLSession *)session;
- (void)evaluateNotification:(NSDictionary *)notification settings:(NSDictionary *)settings examples:(NSArray *)examples completion:(void (^)(NSNumber *, NSString *))completion;
@end
