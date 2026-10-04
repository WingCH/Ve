#import <Foundation/Foundation.h>

@interface VEAPILog : NSObject
+ (NSDictionary *)request:(NSURLRequest *)request;
+ (NSDictionary *)response:(NSURLResponse *)response data:(NSData *)data error:(NSError *)error;
+ (NSData *)bodyDataFromRecord:(NSDictionary *)record;
+ (NSString *)textForTrace:(NSDictionary *)trace;
@end
