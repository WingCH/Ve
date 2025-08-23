//
//  BarkManager.m
//  Vē
//
//  Created by Alexandra Aurora Göttlicher
//

#import "BarkManager.h"
#import "../Preferences/PreferenceKeys.h"
#import <CommonCrypto/CommonDigest.h>
#import <CommonCrypto/CommonCryptor.h>
#import <Security/Security.h>
#import <objc/runtime.h>

@interface BarkManager ()
@property (nonatomic, strong) NSMutableDictionary *iTunesAPICache;
@end

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
    if (self) {
        _iTunesAPICache = [[NSMutableDictionary alloc] init];
    }
    return self;
}

- (void)forwardNotificationWithTitle:(NSString *)title
                            subtitle:(NSString *)subtitle
                                body:(NSString *)body
                    bundleIdentifier:(NSString *)bundleIdentifier
                               level:(BarkNotificationLevel)level
                            threadID:(NSString *)threadID
                          bulletinID:(NSString *)bulletinID {
    NSUserDefaults* preferences = [[NSUserDefaults alloc] initWithSuiteName:kPreferencesIdentifier];
    
    // Check if Bark forwarding is enabled
    BOOL barkForwardingEnabled = [[preferences objectForKey:kPreferenceKeyBarkForwardingEnabled] boolValue];
    NSLog(@"[Ve] Bark forwarding enabled: %@", barkForwardingEnabled ? @"YES" : @"NO");
    if (!barkForwardingEnabled) {
        return;
    }
    
    // Get API key
    NSString* apiKey = [preferences objectForKey:kPreferenceKeyBarkAPIKey];
    NSLog(@"[Ve] Bark API key: %@", apiKey ? @"[SET]" : @"[NOT SET]");
    if (!apiKey || [apiKey length] == 0) {
        NSLog(@"[Ve] Bark API key is not set");
        return;
    }
    
    // Get encryption key (optional)
    NSString* encryptionKey = [preferences objectForKey:kPreferenceKeyBarkEncryptionKey];
    
    // Prepare notification data according to Bark API spec
    NSString* notificationTitle = title ?: @"Notification";
    NSString* notificationSubtitle = subtitle ?: @"";
    NSString* notificationBody = body ?: @"";
    
    NSLog(@"[Ve] Preparing Bark notification - Title: %@, Subtitle: %@, Body: %@, Level: %@", 
          notificationTitle, notificationSubtitle, notificationBody, [self levelToString:level]);
    
    // Get app icon URL and then send notification  
    [self getAppIconURLForBundleIdentifier:bundleIdentifier completion:^(NSString *iconURL) {
        // Send notification using POST method for better parameter control
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            [self sendBarkNotificationWithAPIKey:apiKey
                                           title:notificationTitle
                                        subtitle:notificationSubtitle
                                            body:notificationBody
                                           level:level
                                        threadID:threadID
                                      bulletinID:bulletinID
                                         iconURL:iconURL
                                   encryptionKey:encryptionKey];
        });
    }];
}


- (void)sendBarkNotificationWithAPIKey:(NSString *)apiKey
                                 title:(NSString *)title
                              subtitle:(NSString *)subtitle
                                  body:(NSString *)body
                                 level:(BarkNotificationLevel)level
                              threadID:(NSString *)threadID
                            bulletinID:(NSString *)bulletinID
                               iconURL:(NSString *)iconURL
                         encryptionKey:(NSString *)encryptionKey {
    NSString* baseURL = @"https://api.day.app";
    NSURL* url = [NSURL URLWithString:[NSString stringWithFormat:@"%@/%@", baseURL, apiKey]];
    
    if (!url) {
        NSLog(@"[Ve] Invalid Bark URL with API key: %@", apiKey);
        return;
    }
    
    // Create request body according to Bark API
    NSMutableDictionary* requestBody = [NSMutableDictionary dictionary];
    
    // Apply encryption if key is provided
    if (encryptionKey && encryptionKey.length > 0) {
        // For encrypted messages, create JSON payload and encrypt it
        NSMutableDictionary* payloadDict = [NSMutableDictionary dictionary];
        if (title && title.length > 0) [payloadDict setObject:title forKey:@"title"];
        if (subtitle && subtitle.length > 0) [payloadDict setObject:subtitle forKey:@"subtitle"];
        if (body && body.length > 0) [payloadDict setObject:body forKey:@"body"];
        [payloadDict setObject:[self levelToString:level] forKey:@"level"];
        [payloadDict setObject:@"default" forKey:@"sound"];
        if (iconURL && iconURL.length > 0) [payloadDict setObject:iconURL forKey:@"icon"];
        
        // Convert to JSON string
        NSError* jsonError;
        NSData* jsonData = [NSJSONSerialization dataWithJSONObject:payloadDict options:0 error:&jsonError];
        if (jsonError) {
            NSLog(@"[Ve] Failed to create JSON payload for encryption: %@", jsonError.localizedDescription);
            // Fallback to unencrypted
            [requestBody setObject:title forKey:@"title"];
            if (subtitle && subtitle.length > 0) [requestBody setObject:subtitle forKey:@"subtitle"];
            [requestBody setObject:body forKey:@"body"];
            [requestBody setObject:[self levelToString:level] forKey:@"level"];
            [requestBody setObject:@"default" forKey:@"sound"];
            if (iconURL && iconURL.length > 0) [requestBody setObject:iconURL forKey:@"icon"];
        } else {
            NSString* jsonString = [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];
            NSString* encryptedMessage = [self encryptMessage:jsonString withKey:encryptionKey];
            
            [requestBody setObject:encryptedMessage forKey:@"ciphertext"];
            NSLog(@"[Ve] Sending AES-128-ECB encrypted Bark notification");
        }
    } else {
        // Standard unencrypted message
        [requestBody setObject:title forKey:@"title"];
        if (subtitle && subtitle.length > 0) [requestBody setObject:subtitle forKey:@"subtitle"];
        [requestBody setObject:body forKey:@"body"];
        NSLog(@"[Ve] Sending unencrypted Bark notification");
        [requestBody setObject:[self levelToString:level] forKey:@"level"];
        [requestBody setObject:@"default" forKey:@"sound"];
        if (iconURL && iconURL.length > 0) {
            [requestBody setObject:iconURL forKey:@"icon"];
            NSLog(@"[Ve] Adding custom icon URL: %@", iconURL);
        }
    }
    
    // Set group based on threadID or default to app bundle
    if (threadID && threadID.length > 0) {
        [requestBody setObject:threadID forKey:@"group"];
    } else {
        [requestBody setObject:@"Ve" forKey:@"group"];
    }
    
    // Set bulletinID for notification editing capability
    if (bulletinID && bulletinID.length > 0) {
        [requestBody setObject:bulletinID forKey:@"id"];
    }
    
    NSError* error;
    NSData* jsonData = [NSJSONSerialization dataWithJSONObject:requestBody options:0 error:&error];
    
    if (error) {
        NSLog(@"[Ve] Failed to serialize Bark request: %@", error.localizedDescription);
        return;
    }
    
    NSMutableURLRequest* request = [NSMutableURLRequest requestWithURL:url];
    [request setHTTPMethod:@"POST"];
    [request setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
    [request setHTTPBody:jsonData];
    [request setTimeoutInterval:10.0];
    
    NSURLSessionDataTask* task = [[NSURLSession sharedSession] dataTaskWithRequest:request completionHandler:^(NSData* data, NSURLResponse* response, NSError* error) {
        if (error) {
            NSLog(@"[Ve] Bark forwarding failed: %@", error.localizedDescription);
        } else {
            NSHTTPURLResponse* httpResponse = (NSHTTPURLResponse*)response;
            if (httpResponse.statusCode == 200) {
                NSLog(@"[Ve] Bark notification sent successfully");
                if (data) {
                    NSError* parseError;
                    NSDictionary* responseDict = [NSJSONSerialization JSONObjectWithData:data options:0 error:&parseError];
                    if (!parseError && responseDict) {
                        NSLog(@"[Ve] Bark response: %@", responseDict);
                    }
                }
            } else {
                NSLog(@"[Ve] Bark server returned status code: %ld", (long)httpResponse.statusCode);
                if (data) {
                    NSString* responseString = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
                    NSLog(@"[Ve] Bark error response: %@", responseString);
                }
            }
        }
    }];
    
    [task resume];
}

- (NSString *)levelToString:(BarkNotificationLevel)level {
    switch (level) {
        case BarkNotificationLevelActive:
            return @"active";
        case BarkNotificationLevelTimeSensitive:
            return @"timeSensitive";
        case BarkNotificationLevelPassive:
            return @"passive";
        default:
            return @"active";
    }
}

- (NSString *)getAppDisplayNameForBundleIdentifier:(NSString *)bundleIdentifier {
    if (!bundleIdentifier) return @"Unknown App";
    
    // Use LSApplicationProxy to get the localized app name (same method as Log.m)
    LSApplicationProxy* applicationProxy = [objc_getClass("LSApplicationProxy") applicationProxyForIdentifier:bundleIdentifier];
    NSString* localizedName = [applicationProxy localizedName];
    
    if (localizedName && localizedName.length > 0) {
        return localizedName;
    }
    
    // Fallback: extract readable name from bundle ID
    NSArray* components = [bundleIdentifier componentsSeparatedByString:@"."];
    NSString* lastComponent = [components lastObject];
    
    if (lastComponent && lastComponent.length > 0) {
        // Capitalize first letter
        NSString* firstChar = [[lastComponent substringToIndex:1] uppercaseString];
        NSString* restOfString = [lastComponent substringFromIndex:1];
        return [NSString stringWithFormat:@"%@%@", firstChar, restOfString];
    }
    
    return bundleIdentifier;
}

- (NSString *)generateBulletinIDForBundleIdentifier:(NSString *)bundleIdentifier
                                              title:(NSString *)title {
    // Create a consistent bulletinID based on bundle identifier and title
    // This allows the same notification type to be updated rather than creating duplicates
    NSString* baseString = [NSString stringWithFormat:@"ve_%@_%@", 
                           bundleIdentifier ?: @"unknown", 
                           title ?: @"notification"];
    
    // Create a hash for consistent but unique ID using SHA256
    NSData* data = [baseString dataUsingEncoding:NSUTF8StringEncoding];
    uint8_t digest[CC_SHA256_DIGEST_LENGTH];
    CC_SHA256(data.bytes, (CC_LONG)data.length, digest);
    
    NSMutableString* output = [NSMutableString stringWithCapacity:CC_SHA256_DIGEST_LENGTH * 2];
    for (int i = 0; i < CC_SHA256_DIGEST_LENGTH; i++) {
        [output appendFormat:@"%02x", digest[i]];
    }
    
    // Return truncated hash for readability (16 characters)
    return [output substringToIndex:MIN(16, output.length)];
}

- (NSString *)urlEncode:(NSString *)string {
    NSCharacterSet* allowedCharacters = [NSCharacterSet URLQueryAllowedCharacterSet];
    return [string stringByAddingPercentEncodingWithAllowedCharacters:allowedCharacters];
}

#pragma mark - Encryption

- (NSString *)encryptMessage:(NSString *)message withKey:(NSString *)key {
    if (!message || !key || key.length == 0) {
        return message;
    }
    
    // Convert strings to data
    NSData* messageData = [message dataUsingEncoding:NSUTF8StringEncoding];
    NSData* keyData = [key dataUsingEncoding:NSUTF8StringEncoding];
    
    // For Bark AES-128-ECB, ensure key is exactly 16 bytes
    NSMutableData* aesKey = [NSMutableData dataWithLength:16];
    if (keyData.length >= 16) {
        [keyData getBytes:aesKey.mutableBytes length:16];
    } else {
        // Pad with zeros if key is shorter
        [keyData getBytes:aesKey.mutableBytes length:keyData.length];
        // Remaining bytes are already zero from dataWithLength
    }
    
    // Create output buffer
    size_t bufferSize = messageData.length + kCCBlockSizeAES128;
    void* buffer = malloc(bufferSize);
    size_t numBytesEncrypted = 0;
    
    // Perform AES-128-ECB encryption (no IV needed for ECB mode)
    CCCryptorStatus cryptStatus = CCCrypt(kCCEncrypt,
                                         kCCAlgorithmAES128,
                                         kCCOptionPKCS7Padding | kCCOptionECBMode,
                                         aesKey.bytes,
                                         aesKey.length,
                                         NULL, // No IV for ECB mode
                                         messageData.bytes,
                                         messageData.length,
                                         buffer,
                                         bufferSize,
                                         &numBytesEncrypted);
    
    if (cryptStatus != kCCSuccess) {
        NSLog(@"[Ve] AES-128-ECB encryption failed with status: %d", cryptStatus);
        free(buffer);
        return message;
    }
    
    // Create encrypted data
    NSData* encryptedData = [NSData dataWithBytes:buffer length:numBytesEncrypted];
    free(buffer);
    
    // Convert to Base64
    NSString* ciphertext = [encryptedData base64EncodedStringWithOptions:0];
    
    return ciphertext;
}

#pragma mark - iTunes API & Icon Caching

- (void)getAppIconURLForBundleIdentifier:(NSString *)bundleIdentifier 
                              completion:(void (^)(NSString *iconURL))completion {
    if (!bundleIdentifier || bundleIdentifier.length == 0) {
        if (completion) completion(nil);
        return;
    }
    
    // Check cache first
    NSString *cachedIconURL = self.iTunesAPICache[bundleIdentifier];
    if (cachedIconURL != nil) {
        NSLog(@"[Ve] Using cached icon URL for %@", bundleIdentifier);
        // Return nil if cached value is empty string (no icon found previously)
        if (completion) completion(cachedIconURL.length > 0 ? cachedIconURL : nil);
        return;
    }
    
    // Make iTunes API request
    NSString *iTunesURL = [NSString stringWithFormat:@"https://itunes.apple.com/lookup?bundleId=%@", 
                          [self urlEncode:bundleIdentifier]];
    NSURL *url = [NSURL URLWithString:iTunesURL];
    
    if (!url) {
        NSLog(@"[Ve] Invalid iTunes API URL for bundle: %@", bundleIdentifier);
        if (completion) completion(nil);
        return;
    }
    
    NSLog(@"[Ve] Fetching icon URL from iTunes API for %@", bundleIdentifier);
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url];
        [request setHTTPMethod:@"GET"];
        [request setTimeoutInterval:10.0];
        [request setValue:@"application/json" forHTTPHeaderField:@"Accept"];
        
        NSURLSessionDataTask *task = [[NSURLSession sharedSession] dataTaskWithRequest:request 
                                                                     completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
            NSString *iconURL = nil;
            
            if (error) {
                NSLog(@"[Ve] iTunes API request failed: %@", error.localizedDescription);
            } else {
                NSHTTPURLResponse *httpResponse = (NSHTTPURLResponse *)response;
                if (httpResponse.statusCode == 200 && data) {
                    NSError *parseError;
                    NSDictionary *responseDict = [NSJSONSerialization JSONObjectWithData:data options:0 error:&parseError];
                    
                    if (!parseError && responseDict) {
                        NSArray *results = responseDict[@"results"];
                        if (results && results.count > 0) {
                            NSDictionary *appInfo = results[0];
                            
                            // Try different icon sizes (prefer higher resolution)
                            iconURL = appInfo[@"artworkUrl512"] ?: 
                                     appInfo[@"artworkUrl100"] ?: 
                                     appInfo[@"artworkUrl60"];
                            
                            if (iconURL) {
                                NSLog(@"[Ve] Found icon URL for %@: %@", bundleIdentifier, iconURL);
                                // Cache the result
                                self.iTunesAPICache[bundleIdentifier] = iconURL;
                            } else {
                                NSLog(@"[Ve] No icon URL found in iTunes API response for %@", bundleIdentifier);
                                // Cache empty result to avoid future requests for system apps
                                self.iTunesAPICache[bundleIdentifier] = @"";
                            }
                        } else {
                            NSLog(@"[Ve] No results found in iTunes API response for %@", bundleIdentifier);
                            // Cache empty result to avoid future requests for non-App Store apps
                            self.iTunesAPICache[bundleIdentifier] = @"";
                        }
                    } else {
                        NSLog(@"[Ve] Failed to parse iTunes API response: %@", parseError.localizedDescription);
                    }
                } else {
                    NSLog(@"[Ve] iTunes API returned status code: %ld for %@", (long)httpResponse.statusCode, bundleIdentifier);
                }
            }
            
            // Call completion on main queue
            dispatch_async(dispatch_get_main_queue(), ^{
                if (completion) completion(iconURL);
            });
        }];
        
        [task resume];
    });
}

- (void)clearITunesAPICache {
    [self.iTunesAPICache removeAllObjects];
    NSLog(@"[Ve] iTunes API cache cleared");
}

@end
