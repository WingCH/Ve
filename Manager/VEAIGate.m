#import "VEAIGate.h"
#import "VEAIPolicy.h"

@interface VEAIGate ()
@property(nonatomic, strong) dispatch_queue_t queue;
@property(nonatomic) BOOL observe;
@property(nonatomic) BOOL actionResolved;
@property(nonatomic) BOOL resultReceived;
@property(nonatomic) BOOL timedOut;
@property(nonatomic) NSTimeInterval timeout;
@property(nonatomic) double threshold;
@property(nonatomic, copy) void (^action)(BOOL, NSString *);
@property(nonatomic, copy) void (^result)(NSDictionary *);
@end

@implementation VEAIGate
- (instancetype)initWithObserve:(BOOL)observe timeout:(NSTimeInterval)timeout threshold:(double)threshold action:(void (^)(BOOL, NSString *))action result:(void (^)(NSDictionary *))result {
    self = [super init];
    if (self) {
        _observe = observe; _timeout = timeout; _threshold = threshold;
        _action = [action copy]; _result = [result copy];
        _queue = dispatch_queue_create("codes.wingchan.ve.ai.gate", DISPATCH_QUEUE_SERIAL);
    }
    return self;
}

- (void)resolveAction:(BOOL)forward reason:(NSString *)reason {
    if (self.actionResolved) return;
    self.actionResolved = YES;
    self.action(forward, reason);
}

- (void)start {
    dispatch_async(self.queue, ^{
        if (self.observe) [self resolveAction:YES reason:@"observe"];
    });
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(self.timeout * NSEC_PER_SEC)), self.queue, ^{
        if (self.resultReceived) return;
        self.timedOut = YES;
        self.result(@{@"state": @"timeout"});
        [self resolveAction:YES reason:@"timeout"];
    });
}

- (void)receiveProbability:(NSNumber *)probability errorCode:(NSString *)errorCode {
    dispatch_async(self.queue, ^{
        if (self.resultReceived) return;
        self.resultReceived = YES;
        NSString *decision = [VEAIPolicy decisionForProbability:probability threshold:self.threshold];
        NSMutableDictionary *info = [@{
            @"state": probability ? @"classified" : @"failed", @"decision": decision,
            @"late": @(self.timedOut)
        } mutableCopy];
        if (probability) info[@"skip_probability"] = probability;
        if (errorCode) info[@"error"] = errorCode;
        self.result(info);
        BOOL skip = [decision isEqual:@"skip"];
        [self resolveAction:!skip reason:probability ? decision : @"failed"];
    });
}
@end
