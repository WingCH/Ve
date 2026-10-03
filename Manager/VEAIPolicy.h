#import <Foundation/Foundation.h>

@interface VEAIPolicy : NSObject
+ (NSString *)defaultPrompt;
+ (NSString *)providerFromDefaults:(NSUserDefaults *)defaults;
+ (NSString *)defaultEndpointForProvider:(NSString *)provider;
+ (NSString *)endpointForProvider:(NSString *)provider defaults:(NSUserDefaults *)defaults;
+ (NSString *)tokenForProvider:(NSString *)provider defaults:(NSUserDefaults *)defaults;
+ (void)setToken:(NSString *)token provider:(NSString *)provider defaults:(NSUserDefaults *)defaults;
+ (void)setEndpoint:(NSString *)endpoint provider:(NSString *)provider defaults:(NSUserDefaults *)defaults;
+ (NSDictionary *)settingsFromDefaults:(NSUserDefaults *)defaults;
+ (NSDictionary *)requestForNotification:(NSDictionary *)notification settings:(NSDictionary *)settings examples:(NSArray *)examples;
+ (NSNumber *)skipProbabilityFromResponse:(NSData *)data statusCode:(NSInteger)statusCode provider:(NSString *)provider;
+ (NSString *)decisionForProbability:(NSNumber *)probability threshold:(double)threshold;
+ (NSString *)summaryForInfo:(NSDictionary *)info;
+ (NSString *)actionLabel:(NSString *)action;
@end
