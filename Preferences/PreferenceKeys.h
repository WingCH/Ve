//
//  PreferenceKeys.h
//  Vē
//
//  Created by Alexandra Aurora Göttlicher
//

#if VE_HOST_TEST
static NSString* const kPreferencesIdentifier = @"codes.wingchan.ve-enhanced.host-tests";
#else
static NSString* const kPreferencesIdentifier = @"codes.wingchan.ve-enhanced.preferences";
#endif

static NSString* const kPreferenceKeyEnabled = @"Enabled";
static NSString* const kPreferenceKeyLogLimit = @"LogLimit";
static NSString* const kPreferenceKeySaveLocalAttachments = @"SaveLocalAttachments";
static NSString* const kPreferenceKeySaveRemoteAttachments = @"SaveRemoteAttachments";
static NSString* const kPreferenceKeyLogWithoutContent = @"LogWithoutContent";
static NSString* const kPreferenceKeyBlockedSenders = @"BlockedSenders";
static NSString* const kPreferenceKeyAutomaticallyDeleteLogs = @"AutomaticallyDeleteLogs";
static NSString* const kPreferenceKeyUseAmericanDateFormat = @"UseAmericanDateFormat";
static NSString* const kPreferenceKeyBarkForwardingEnabled = @"BarkForwardingEnabled";
static NSString* const kPreferenceKeyBarkAPIKey = @"BarkAPIKey";
static NSString* const kPreferenceKeyBarkEncryptionKey = @"BarkEncryptionKey";
static NSString* const kPreferenceKeyBarkDomain = @"BarkDomain";
static NSString* const kPreferenceKeySorting = @"Sorting";
static NSString* const kPreferenceKeyAIEnabled = @"AIEnabled";
static NSString* const kPreferenceKeyAIProvider = @"AIProvider";
static NSString* const kPreferenceKeyAITokens = @"AITokensByProvider";
static NSString* const kPreferenceKeyAIEndpoints = @"AIEndpointsByProvider";
static NSString* const kPreferenceKeyAISystemOneModel = @"AISystemOneModel";
static NSString* const kPreferenceKeyAIAccountID = @"AIAccountID";
static NSString* const kPreferenceKeyAIToken = @"AIToken";
static NSString* const kPreferenceKeyAIModel = @"AIModel";
static NSString* const kPreferenceKeyAIMode = @"AIMode";
static NSString* const kPreferenceKeyAITimeout = @"AITimeout";
static NSString* const kPreferenceKeyAIThreshold = @"AIThreshold";
static NSString* const kPreferenceKeyAIPrompt = @"AIPrompt";
static NSString* const kPreferenceKeyAIPromptVersion = @"AIPromptVersion";

static NSString* const kPreferenceKeySortingApplication = @"Application";
static NSString* const kPreferenceKeySortingDate = @"Date";
static NSString* const kPreferenceKeySortingSearch = @"Search";

static BOOL const kPreferenceKeyEnabledDefaultValue = YES;
static NSUInteger const kPreferenceKeyLogLimitDefaultValue = 2000;
static BOOL const kPreferenceKeySaveLocalAttachmentsDefaultValue = YES;
static BOOL const kPreferenceKeySaveRemoteAttachmentsDefaultValue = YES;
static BOOL const kPreferenceKeyLogWithoutContentDefaultValue = YES;
static inline NSArray* kPreferenceKeyBlockedSendersDefaultValue(void) {
    return @[];
}
static BOOL const kPreferenceKeyAutomaticallyDeleteLogsDefaultValue = YES;
static BOOL const kPreferenceKeyUseAmericanDateFormatDefaultValue = NO;
static BOOL const kPreferenceKeyBarkForwardingEnabledDefaultValue = NO;
static NSString* const kPreferenceKeyBarkAPIKeyDefaultValue = @"";
static NSString* const kPreferenceKeyBarkEncryptionKeyDefaultValue = @"";
static NSString* const kPreferenceKeyBarkDomainDefaultValue = @"https://api.day.app";
static NSString* const kPreferenceKeySortingDefaultValue = kPreferenceKeySortingDate;
