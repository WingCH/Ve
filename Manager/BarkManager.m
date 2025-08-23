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
    NSString* appName = [self getAppDisplayNameForBundleIdentifier:bundleIdentifier];
    NSString* generatedBulletinID = [self generateBulletinIDForBundleIdentifier:bundleIdentifier title:title];
    
    [self forwardNotificationWithTitle:appName
                               subtitle:title
                                   body:content
                       bundleIdentifier:bundleIdentifier
                                  level:BarkNotificationLevelActive
                               threadID:nil
                             bulletinID:generatedBulletinID];
}

- (void)forwardNotificationWithTitle:(NSString *)title
                            subtitle:(NSString *)subtitle
                                body:(NSString *)body
                    bundleIdentifier:(NSString *)bundleIdentifier
                               level:(BarkNotificationLevel)level
                            threadID:(NSString *)threadID {
    [self forwardNotificationWithTitle:title
                               subtitle:subtitle
                                   body:body
                       bundleIdentifier:bundleIdentifier
                                  level:level
                               threadID:threadID
                             bulletinID:nil];
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
    if (!barkForwardingEnabled) {
        return;
    }
    
    // Get API key
    NSString* apiKey = [preferences objectForKey:kPreferenceKeyBarkAPIKey];
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
    
    // Send notification using POST method for better parameter control
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        [self sendBarkNotificationWithAPIKey:apiKey
                                       title:notificationTitle
                                    subtitle:notificationSubtitle
                                        body:notificationBody
                                       level:level
                                    threadID:threadID
                                  bulletinID:bulletinID
                               encryptionKey:encryptionKey];
    });
}

- (void)sendBarkNotificationWithAPIKey:(NSString *)apiKey
                                 title:(NSString *)title
                              subtitle:(NSString *)subtitle
                                  body:(NSString *)body
                                 level:(BarkNotificationLevel)level
                              threadID:(NSString *)threadID
                            bulletinID:(NSString *)bulletinID
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
        
        // Convert to JSON string
        NSError* jsonError;
        NSData* jsonData = [NSJSONSerialization dataWithJSONObject:payloadDict options:0 error:&jsonError];
        if (jsonError) {
            NSLog(@"[Ve] Failed to create JSON payload for encryption: %@", jsonError.localizedDescription);
            // Fallback to unencrypted
            [requestBody setObject:title forKey:@"title"];
            [requestBody setObject:subtitle forKey:@"subtitle"];
            [requestBody setObject:body forKey:@"body"];
        } else {
            NSString* jsonString = [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];
            NSString* encryptedMessage = [self encryptMessage:jsonString withKey:encryptionKey];
            
            [requestBody setObject:encryptedMessage forKey:@"ciphertext"];
            NSLog(@"[Ve] Sending AES-128-ECB encrypted Bark notification");
        }
    } else {
        // Standard unencrypted message
        [requestBody setObject:title forKey:@"title"];
        [requestBody setObject:subtitle forKey:@"subtitle"];
        [requestBody setObject:body forKey:@"body"];
        NSLog(@"[Ve] Sending unencrypted Bark notification");
        [requestBody setObject:[self levelToString:level] forKey:@"level"];
        [requestBody setObject:@"default" forKey:@"sound"];
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

@end
