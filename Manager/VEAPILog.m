#import "VEAPILog.h"

static NSDictionary *VEBody(NSData *data) {
    NSData *bytes = data ?: [NSData data];
    NSMutableDictionary *body = [@{
        @"capture_version": @2, @"body_present": @(data != nil),
        @"byte_count": @(bytes.length), @"body_base64": [bytes base64EncodedStringWithOptions:0]
    } mutableCopy];
    NSString *text = [[NSString alloc] initWithData:bytes encoding:NSUTF8StringEncoding];
    if (text) body[@"body_text"] = text;
    return body;
}

static void VEAppendMessage(NSMutableString *text, NSDictionary *message) {
    if (!message) { [text appendString:@"Not recorded.\n"]; return; }
    if (message[@"method"]) [text appendFormat:@"%@ %@\n", message[@"method"], message[@"url"] ?: @""];
    else [text appendFormat:@"HTTP status: %@\nURL: %@\n", message[@"status_code"] ?: @0, message[@"url"] ?: @""];
    NSDictionary *headers = message[@"headers"];
    for (NSString *name in headers) [text appendFormat:@"%@: %@\n", name, headers[name]];
    [text appendString:@"\n"];
    NSData *bytes = [VEAPILog bodyDataFromRecord:message];
    if (bytes) {
        NSString *body = [[NSString alloc] initWithData:bytes encoding:NSUTF8StringEncoding];
        if (body) [text appendString:body];
        else [text appendFormat:@"[Non-UTF8 body, %@ bytes; lossless Base64]\n%@", message[@"byte_count"], message[@"body_base64"]];
    } else {
        [text appendString:@"[Legacy capture: original bytes are unavailable.]\n"];
        if (message[@"body_text"]) [text appendString:message[@"body_text"]];
        else if (message[@"body_base64"]) [text appendString:message[@"body_base64"]];
        else if (message[@"body_json"]) {
            NSData *json = [NSJSONSerialization dataWithJSONObject:message[@"body_json"] options:NSJSONWritingPrettyPrinted | NSJSONWritingFragmentsAllowed error:nil];
            if (json) [text appendString:[[NSString alloc] initWithData:json encoding:NSUTF8StringEncoding]];
        }
    }
    if (message[@"error"]) [text appendFormat:@"\n\nTRANSPORT ERROR\n%@", message[@"error"][@"description"] ?: message[@"error"][@"message"]];
    [text appendString:@"\n"];
}

@implementation VEAPILog
+ (NSDictionary *)request:(NSURLRequest *)request {
    NSMutableDictionary *result = [@{
        @"method": request.HTTPMethod ?: @"GET", @"url": request.URL.absoluteString ?: @"",
        @"headers": request.allHTTPHeaderFields ?: @{}
    } mutableCopy];
    [result addEntriesFromDictionary:VEBody(request.HTTPBody)];
    return result;
}
+ (NSDictionary *)response:(NSURLResponse *)response data:(NSData *)data error:(NSError *)error {
    NSHTTPURLResponse *http = [response isKindOfClass:[NSHTTPURLResponse class]] ? (NSHTTPURLResponse *)response : nil;
    NSMutableDictionary *result = [@{
        @"status_code": @(http.statusCode), @"url": response.URL.absoluteString ?: @"",
        @"headers": http.allHeaderFields ?: @{}
    } mutableCopy];
    [result addEntriesFromDictionary:VEBody(data)];
    if (error) result[@"error"] = @{
        @"domain": error.domain, @"code": @(error.code), @"message": error.localizedDescription,
        @"description": error.description, @"user_info_description": error.userInfo.description
    };
    return result;
}
+ (NSData *)bodyDataFromRecord:(NSDictionary *)record {
    if ([record[@"capture_version"] integerValue] != 2 || ![record[@"body_base64"] isKindOfClass:[NSString class]]) return nil;
    return [[NSData alloc] initWithBase64EncodedString:record[@"body_base64"] options:0];
}
+ (NSString *)textForTrace:(NSDictionary *)trace {
    NSMutableString *text = [NSMutableString new];
    if (trace[@"state"]) [text appendFormat:@"State: %@\n", trace[@"state"]];
    if (trace[@"started_at"]) [text appendFormat:@"Started at: %@\n", trace[@"started_at"]];
    if (trace[@"duration_ms"]) [text appendFormat:@"Duration (ms): %@\n", trace[@"duration_ms"]];
    [text appendString:@"\nREQUEST\n"];
    VEAppendMessage(text, trace[@"request"]);
    [text appendString:@"\nRESPONSE\n"];
    VEAppendMessage(text, trace[@"response"]);
    return text;
}
@end
