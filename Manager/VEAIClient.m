#import "VEAIClient.h"
#import "VEAIPolicy.h"

@interface VEAIClient ()
@property(nonatomic, strong) NSURLSession *session;
@end

@implementation VEAIClient
- (instancetype)initWithSession:(NSURLSession *)session {
    self = [super init];
    if (self) { _session = session; }
    return self;
}

- (void)evaluateNotification:(NSDictionary *)notification settings:(NSDictionary *)settings examples:(NSArray *)examples completion:(void (^)(NSNumber *, NSString *))completion {
    NSString *account = settings[@"account_id"];
    NSString *token = settings[@"token"];
    NSString *endpoint = settings[@"endpoint"];
    BOOL needsAccount = [endpoint containsString:@"{account_id}"];
    NSCharacterSet *nonHex = [[NSCharacterSet characterSetWithCharactersInString:@"0123456789abcdefABCDEF"] invertedSet];
    if ((needsAccount && (account.length != 32 || [account rangeOfCharacterFromSet:nonHex].location != NSNotFound)) || !token.length || [token rangeOfCharacterFromSet:[NSCharacterSet newlineCharacterSet]].location != NSNotFound) {
        completion(nil, @"invalid_configuration");
        return;
    }
    endpoint = [[endpoint stringByReplacingOccurrencesOfString:@"{account_id}" withString:account] stringByReplacingOccurrencesOfString:@"{model}" withString:settings[@"model"]];
    NSURLComponents *components = [NSURLComponents componentsWithString:endpoint];
    if (![@[@"http", @"https"] containsObject:components.scheme.lowercaseString] || !components.host.length || components.user || components.password) {
        completion(nil, @"invalid_endpoint"); return;
    }
    NSURL *url = components.URL;
    NSDictionary *body = [VEAIPolicy requestForNotification:notification settings:settings examples:examples];
    NSData *data = [NSJSONSerialization dataWithJSONObject:body options:0 error:nil];
    if (!data) { completion(nil, @"invalid_request"); return; }
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url];
    request.HTTPMethod = @"POST";
    request.HTTPBody = data;
    [request setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
    [request setValue:[@"Bearer " stringByAppendingString:token] forHTTPHeaderField:@"Authorization"];
    // The forwarding gate has a separate deadline. A bounded late response can still be recorded.
    request.timeoutInterval = MAX(10.0, [settings[@"timeout"] doubleValue] + 5.0);
    [[self.session dataTaskWithRequest:request completionHandler:^(NSData *responseData, NSURLResponse *response, NSError *error) {
        NSInteger status = [response isKindOfClass:[NSHTTPURLResponse class]] ? [(NSHTTPURLResponse *)response statusCode] : 0;
        NSNumber *probability = error ? nil : [VEAIPolicy skipProbabilityFromResponse:responseData statusCode:status provider:settings[@"provider"]];
        NSString *code = nil;
        if (error) code = @"transport_error";
        else if (!probability) code = status >= 200 && status < 300 ? @"invalid_response" : [NSString stringWithFormat:@"http_%ld", (long)status];
        completion(probability, code);
    }] resume];
}
@end
