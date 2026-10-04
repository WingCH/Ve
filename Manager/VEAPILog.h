#import <Foundation/Foundation.h>

@interface VEAPILog : NSObject
+ (NSDictionary *)request:(NSURLRequest *)request secrets:(NSArray<NSString *> *)secrets;
+ (NSDictionary *)response:(NSURLResponse *)response data:(NSData *)data error:(NSError *)error secrets:(NSArray<NSString *> *)secrets;
@end
