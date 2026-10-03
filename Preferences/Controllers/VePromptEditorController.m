#import "VePromptEditorController.h"
#import "../PreferenceKeys.h"
#import "../NotificationKeys.h"
#import "../../Manager/VEAIPolicy.h"

static void VEPostSettingsChange(void) {
    CFNotificationCenterPostNotification(CFNotificationCenterGetDarwinNotifyCenter(), (__bridge CFStringRef)kNotificationKeyPreferencesReload, NULL, NULL, YES);
}

@interface VePromptEditorController ()
@property(nonatomic, strong) UITextView *editor;
@end

@implementation VePromptEditorController
- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"判斷規則";
    self.view.backgroundColor = [UIColor systemBackgroundColor];
    self.editor = [UITextView new];
    self.editor.font = [UIFont preferredFontForTextStyle:UIFontTextStyleBody];
    self.editor.adjustsFontForContentSizeCategory = YES;
    self.editor.accessibilityIdentifier = @"ve.ai.prompt";
    self.editor.text = [VEAIPolicy settingsFromDefaults:[[NSUserDefaults alloc] initWithSuiteName:kPreferencesIdentifier]][@"prompt"];
    self.editor.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:self.editor];
    [NSLayoutConstraint activateConstraints:@[
        [self.editor.topAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.topAnchor constant:12],
        [self.editor.leadingAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.leadingAnchor constant:12],
        [self.editor.trailingAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.trailingAnchor constant:-12],
        [self.editor.bottomAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.bottomAnchor constant:-12]
    ]];
    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:@"儲存" style:UIBarButtonItemStyleDone target:self action:@selector(savePrompt)];
    self.navigationItem.leftItemsSupplementBackButton = YES;
    self.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:@"還原預設" style:UIBarButtonItemStylePlain target:self action:@selector(restoreDefault)];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(keyboardChanged:) name:UIKeyboardWillChangeFrameNotification object:nil];
}
- (void)dealloc { [[NSNotificationCenter defaultCenter] removeObserver:self]; }
- (void)keyboardChanged:(NSNotification *)notification {
    CGRect frame = [self.view convertRect:[notification.userInfo[UIKeyboardFrameEndUserInfoKey] CGRectValue] fromView:nil];
    CGFloat overlap = MAX(0, CGRectGetMaxY(self.editor.frame) - CGRectGetMinY(frame));
    self.editor.contentInset = UIEdgeInsetsMake(0, 0, overlap, 0);
    self.editor.scrollIndicatorInsets = self.editor.contentInset;
}
- (void)restoreDefault { self.editor.text = [VEAIPolicy defaultPrompt]; }
- (void)savePrompt {
    NSString *prompt = [self.editor.text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if (!prompt.length) { [self restoreDefault]; return; }
    NSUserDefaults *defaults = [[NSUserDefaults alloc] initWithSuiteName:kPreferencesIdentifier];
    [defaults setObject:prompt forKey:kPreferenceKeyAIPrompt];
    [defaults setObject:[NSUUID UUID].UUIDString forKey:kPreferenceKeyAIPromptVersion];
    [defaults synchronize];
    VEPostSettingsChange();
    [self.navigationController popViewControllerAnimated:YES];
}
@end

@interface VeAITokenController ()
@property(nonatomic, strong) UITextField *tokenField;
@property(nonatomic, copy) NSString *provider;
@end

@implementation VeAITokenController
- (void)viewDidLoad {
    [super viewDidLoad];
    NSUserDefaults *defaults = [[NSUserDefaults alloc] initWithSuiteName:kPreferencesIdentifier];
    self.provider = [VEAIPolicy providerFromDefaults:defaults];
    self.title = [self.provider isEqual:@"cloudflare"] ? @"Cloudflare API Token" : @"System One API Token";
    self.view.backgroundColor = [UIColor systemBackgroundColor];
    self.tokenField = [UITextField new];
    self.tokenField.secureTextEntry = YES;
    self.tokenField.autocapitalizationType = UITextAutocapitalizationTypeNone;
    self.tokenField.autocorrectionType = UITextAutocorrectionTypeNo;
    self.tokenField.borderStyle = UITextBorderStyleRoundedRect;
    self.tokenField.placeholder = @"留空即可略過 AI";
    self.tokenField.accessibilityIdentifier = @"ve.ai.token";
    self.tokenField.text = [VEAIPolicy tokenForProvider:self.provider defaults:defaults];
    self.tokenField.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:self.tokenField];
    [NSLayoutConstraint activateConstraints:@[
        [self.tokenField.topAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.topAnchor constant:24],
        [self.tokenField.leadingAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.leadingAnchor constant:16],
        [self.tokenField.trailingAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.trailingAnchor constant:-16],
        [self.tokenField.heightAnchor constraintEqualToConstant:48]
    ]];
    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:@"儲存" style:UIBarButtonItemStyleDone target:self action:@selector(saveToken)];
}
- (void)saveToken {
    NSString *token = [self.tokenField.text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    NSUserDefaults *defaults = [[NSUserDefaults alloc] initWithSuiteName:kPreferencesIdentifier];
    [VEAIPolicy setToken:token provider:self.provider defaults:defaults];
    [defaults synchronize];
    VEPostSettingsChange();
    [self.navigationController popViewControllerAnimated:YES];
}
@end

@implementation VeAIEndpointController
- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"AI Endpoint URL";
    self.tokenField.secureTextEntry = NO;
    self.tokenField.keyboardType = UIKeyboardTypeURL;
    self.tokenField.accessibilityIdentifier = @"ve.ai.endpoint";
    self.tokenField.placeholder = @"留空使用 provider 預設";
    self.tokenField.text = [VEAIPolicy endpointForProvider:self.provider defaults:[[NSUserDefaults alloc] initWithSuiteName:kPreferencesIdentifier]];
    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:@"儲存" style:UIBarButtonItemStyleDone target:self action:@selector(saveEndpoint)];
    self.navigationItem.leftItemsSupplementBackButton = YES;
    self.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:@"還原預設" style:UIBarButtonItemStylePlain target:self action:@selector(restoreEndpoint)];
}
- (void)restoreEndpoint { self.tokenField.text = [VEAIPolicy defaultEndpointForProvider:self.provider]; }
- (void)saveEndpoint {
    NSString *endpoint = [self.tokenField.text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    NSString *preview = endpoint.length ? endpoint : [VEAIPolicy defaultEndpointForProvider:self.provider];
    preview = [[preview stringByReplacingOccurrencesOfString:@"{account_id}" withString:@"00000000000000000000000000000000"] stringByReplacingOccurrencesOfString:@"{model}" withString:@"clef"];
    NSURLComponents *components = [NSURLComponents componentsWithString:preview];
    if (![@[@"http", @"https"] containsObject:components.scheme.lowercaseString] || !components.host.length || components.user || components.password) {
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"URL 無效" message:@"請輸入完整的 HTTP 或 HTTPS endpoint URL。" preferredStyle:UIAlertControllerStyleAlert];
        [alert addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil]];
        [self presentViewController:alert animated:YES completion:nil];
        return;
    }
    NSUserDefaults *defaults = [[NSUserDefaults alloc] initWithSuiteName:kPreferencesIdentifier];
    [VEAIPolicy setEndpoint:endpoint provider:self.provider defaults:defaults];
    [defaults synchronize];
    VEPostSettingsChange();
    [self.navigationController popViewControllerAnimated:YES];
}
@end
