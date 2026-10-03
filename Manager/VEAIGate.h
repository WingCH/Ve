#import <Foundation/Foundation.h>

// Gate decisions and late results have separate callbacks.
@interface VEAIGate : NSObject
- (instancetype)initWithObserve:(BOOL)observe timeout:(NSTimeInterval)timeout threshold:(double)threshold action:(void (^)(BOOL, NSString *))action result:(void (^)(NSDictionary *))result;
- (void)start;
- (void)receiveProbability:(NSNumber *)probability errorCode:(NSString *)errorCode;
@end
