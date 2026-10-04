#import "VEAPILog.h"

static NSString *VEMaskText(NSString *text, NSArray<NSString *> *secrets) {
    for (NSString *secret in secrets) {
        if (secret.length) text = [text stringByReplacingOccurrencesOfString:secret withString:@"[REDACTED]"];
    }
    return text;
}
static BOOL VESecretKey(NSString *key) {
    NSString *name = [[key lowercaseString] stringByReplacingOccurrencesOfString:@"-" withString:@"_"];
    return [name hasSuffix:@"_token"] || [name hasSuffix:@"_api_key"] || [name hasSuffix:@"_secret"] ||
        [@[@"authorization", @"proxy_authorization", @"cookie", @"set_cookie", @"token", @"api_key", @"apikey", @"key", @"password", @"secret", @"device_key"] containsObject:name];
}
static id VERedact(id value, NSArray<NSString *> *secrets) {
    if ([value isKindOfClass:[NSDictionary class]]) {
        NSMutableDictionary *safe = [NSMutableDictionary new];
        for (NSString *key in value) safe[key] = VESecretKey(key) ? @"[REDACTED]" : VERedact(value[key], secrets);
        return safe;
    }
    if ([value isKindOfClass:[NSArray class]]) {
        NSMutableArray *safe = [NSMutableArray new];
        for (id item in value) [safe addObject:VERedact(item, secrets)];
        return safe;
    }
    return [value isKindOfClass:[NSString class]] ? VEMaskText(value, secrets) : value;
}
static NSDictionary *VEBody(NSData *data, NSArray<NSString *> *secrets) {
    if (!data) return @{@"byte_count": @0, @"body": @""};
    NSUInteger limit = 16 * 1024;
    id json = [NSJSONSerialization JSONObjectWithData:data options:NSJSONReadingFragmentsAllowed error:nil];
    id safeJSON = json ? VERedact(json, secrets) : nil;
    NSData *safeData = safeJSON ? [NSJSONSerialization dataWithJSONObject:safeJSON options:NSJSONWritingFragmentsAllowed error:nil] : data;
    NSMutableData *masked = [safeData mutableCopy];
    NSData *replacement = [@"[REDACTED]" dataUsingEncoding:NSUTF8StringEncoding];
    // Mask known credentials before truncating, including non-UTF8 error bodies.
    for (NSString *secret in secrets) {
        NSData *needle = [secret dataUsingEncoding:NSUTF8StringEncoding];
        if (!needle.length) continue;
        NSUInteger offset = 0;
        while (offset < masked.length) {
            NSRange range = [masked rangeOfData:needle options:0 range:NSMakeRange(offset, masked.length - offset)];
            if (range.location == NSNotFound) break;
            [masked replaceBytesInRange:range withBytes:replacement.bytes length:replacement.length];
            offset = range.location + replacement.length;
        }
    }
    BOOL truncated = masked.length > limit;
    NSData *preview = truncated ? [masked subdataWithRange:NSMakeRange(0, limit)] : masked;
    NSMutableDictionary *body = [@{@"byte_count": @(data.length), @"truncated": @(truncated)} mutableCopy];
    if (safeJSON && !truncated) body[@"body_json"] = safeJSON;
    else {
        NSString *text = [[NSString alloc] initWithData:preview encoding:NSUTF8StringEncoding];
        if (text) body[@"body_text"] = text;
        else body[@"body_base64"] = [preview base64EncodedStringWithOptions:0];
    }
    return body;
}

@implementation VEAPILog
+ (NSDictionary *)request:(NSURLRequest *)request secrets:(NSArray<NSString *> *)secrets {
    NSURLComponents *url = [NSURLComponents componentsWithURL:request.URL resolvingAgainstBaseURL:NO];
    NSMutableArray *query = [NSMutableArray new];
    for (NSURLQueryItem *item in url.queryItems) {
        [query addObject:[NSURLQueryItem queryItemWithName:item.name value:VESecretKey(item.name) ? @"[REDACTED]" : VEMaskText(item.value ?: @"", secrets)]];
    }
    if (url.queryItems) url.queryItems = query;
    NSMutableDictionary *result = [@{@"method": request.HTTPMethod ?: @"GET", @"url": VEMaskText(url.string ?: @"", secrets), @"headers": VERedact(request.allHTTPHeaderFields ?: @{}, secrets)} mutableCopy];
    [result addEntriesFromDictionary:VEBody(request.HTTPBody, secrets)];
    return result;
}
+ (NSDictionary *)response:(NSURLResponse *)response data:(NSData *)data error:(NSError *)error secrets:(NSArray<NSString *> *)secrets {
    NSHTTPURLResponse *http = [response isKindOfClass:[NSHTTPURLResponse class]] ? (NSHTTPURLResponse *)response : nil;
    NSMutableDictionary *result = [@{@"status_code": @(http.statusCode), @"headers": VERedact(http.allHeaderFields ?: @{}, secrets)} mutableCopy];
    [result addEntriesFromDictionary:VEBody(data, secrets)];
    if (error) result[@"error"] = @{@"domain": error.domain, @"code": @(error.code), @"message": VEMaskText(error.localizedDescription, secrets)};
    return result;
}
@end
