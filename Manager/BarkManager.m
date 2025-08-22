//
//  BarkManager.m
//  Vē
//
//  Created by Alexandra Aurora Göttlicher
//

#import "BarkManager.h"
#import "../Preferences/PreferenceKeys.h"

@implementation BarkManager

+ (instancetype)sharedInstance {
    static BarkManager* sharedInstance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedInstance = [[self alloc] init];
    });
    return sharedInstance;
}

- (instancetype)init {
    self = [super init];
    return self;
}

- (void)forwardNotificationWithTitle:(NSString *)title content:(NSString *)content bundleIdentifier:(NSString *)bundleIdentifier {
    NSUserDefaults* preferences = [[NSUserDefaults alloc] initWithSuiteName:kPreferencesIdentifier];
    
    // Check if Bark forwarding is enabled
    BOOL barkForwardingEnabled = [[preferences objectForKey:kPreferenceKeyBarkForwardingEnabled] boolValue];
    if (!barkForwardingEnabled) {
        return;
    }
    
    // Get API key
    NSString* apiKey = [preferences objectForKey:kPreferenceKeyBarkAPIKey];
    if (!apiKey || [apiKey length] == 0) {
        NSLog(@"[Ve] Bark API key is not set");
        return;
    }
    
    // Prepare notification data
    NSString* notificationTitle = title ?: @"Notification";
    NSString* notificationContent = content ?: @"";
    NSString* appName = [self getAppNameForBundleIdentifier:bundleIdentifier] ?: bundleIdentifier;
    
    // Create the full message
    NSString* fullMessage = [NSString stringWithFormat:@"[%@] %@", appName, notificationContent];
    
    // Create Bark URL
    NSString* barkURL = [NSString stringWithFormat:@"https://api.day.app/%@/%@/%@", 
                        [self urlEncode:apiKey], 
                        [self urlEncode:notificationTitle], 
                        [self urlEncode:fullMessage]];
    
    // Add query parameters for better formatting
    barkURL = [barkURL stringByAppendingString:@"?group=Ve&sound=default"];
    
    // Send notification asynchronously
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        [self sendBarkNotificationWithURL:barkURL];
    });
}

- (void)sendBarkNotificationWithURL:(NSString *)urlString {
    NSURL* url = [NSURL URLWithString:urlString];
    if (!url) {
        NSLog(@"[Ve] Invalid Bark URL: %@", urlString);
        return;
    }
    
    NSMutableURLRequest* request = [NSMutableURLRequest requestWithURL:url];
    [request setHTTPMethod:@"GET"];
    [request setTimeoutInterval:10.0];
    
    NSURLSessionDataTask* task = [[NSURLSession sharedSession] dataTaskWithRequest:request completionHandler:^(NSData* data, NSURLResponse* response, NSError* error) {
        if (error) {
            NSLog(@"[Ve] Bark forwarding failed: %@", error.localizedDescription);
        } else {
            NSHTTPURLResponse* httpResponse = (NSHTTPURLResponse*)response;
            if (httpResponse.statusCode == 200) {
                NSLog(@"[Ve] Bark notification sent successfully");
            } else {
                NSLog(@"[Ve] Bark server returned status code: %ld", (long)httpResponse.statusCode);
            }
        }
    }];
    
    [task resume];
}

- (NSString *)getAppNameForBundleIdentifier:(NSString *)bundleIdentifier {
    if (!bundleIdentifier) return nil;
    
    // Try to get app name from bundle
    NSBundle* bundle = [NSBundle bundleWithIdentifier:bundleIdentifier];
    if (bundle) {
        NSString* displayName = [bundle objectForInfoDictionaryKey:@"CFBundleDisplayName"];
        if (displayName) return displayName;
        
        NSString* bundleName = [bundle objectForInfoDictionaryKey:@"CFBundleName"];
        if (bundleName) return bundleName;
    }
    
    // Fallback to bundle identifier
    return bundleIdentifier;
}

- (NSString *)urlEncode:(NSString *)string {
    NSCharacterSet* allowedCharacters = [NSCharacterSet URLQueryAllowedCharacterSet];
    return [string stringByAddingPercentEncodingWithAllowedCharacters:allowedCharacters];
}

@end
