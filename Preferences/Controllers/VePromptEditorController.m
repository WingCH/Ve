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
    self.title = @"Notification Rules";
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
    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:@"Save" style:UIBarButtonItemStyleDone target:self action:@selector(savePrompt)];
    self.navigationItem.leftItemsSupplementBackButton = YES;
    self.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:@"Restore Default" style:UIBarButtonItemStylePlain target:self action:@selector(restoreDefault)];
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
    self.title = [self.provider isEqual:@"cloudflare"] ? @"Cloudflare API Token" : @"Jev API Token";
    self.view.backgroundColor = [UIColor systemBackgroundColor];
    self.tokenField = [UITextField new];
    self.tokenField.secureTextEntry = YES;
    self.tokenField.autocapitalizationType = UITextAutocapitalizationTypeNone;
    self.tokenField.autocorrectionType = UITextAutocorrectionTypeNo;
    self.tokenField.borderStyle = UITextBorderStyleRoundedRect;
    self.tokenField.placeholder = @"Leave blank to skip AI";
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
    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:@"Save" style:UIBarButtonItemStyleDone target:self action:@selector(saveToken)];
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
    self.title = [self.provider isEqual:@"cloudflare"] ? @"Cloudflare Endpoint URL" : @"Jev Endpoint URL";
    self.tokenField.secureTextEntry = NO;
    self.tokenField.keyboardType = UIKeyboardTypeURL;
    self.tokenField.accessibilityIdentifier = @"ve.ai.endpoint";
    self.tokenField.placeholder = @"Leave blank to use the default URL";
    self.tokenField.text = [VEAIPolicy endpointForProvider:self.provider defaults:[[NSUserDefaults alloc] initWithSuiteName:kPreferencesIdentifier]];
    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:@"Save" style:UIBarButtonItemStyleDone target:self action:@selector(saveEndpoint)];
    self.navigationItem.leftItemsSupplementBackButton = YES;
    self.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:@"Restore Default" style:UIBarButtonItemStylePlain target:self action:@selector(restoreEndpoint)];
    UILabel *help = [UILabel new];
    help.font = [UIFont preferredFontForTextStyle:UIFontTextStyleFootnote];
    help.textColor = [UIColor secondaryLabelColor];
    help.numberOfLines = 0;
    help.text = [self.provider isEqual:@"cloudflare"]
        ? @"Use {account_id} to insert the Account ID and {model} to insert the selected model. A URL that already contains the Account ID needs no separate Account ID field."
        : @"Enter a complete System One API URL. The default is https://api.typesafe.ai/v1/systemone. No Cloudflare Account ID is needed.";
    help.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:help];
    [NSLayoutConstraint activateConstraints:@[
        [help.topAnchor constraintEqualToAnchor:self.tokenField.bottomAnchor constant:12],
        [help.leadingAnchor constraintEqualToAnchor:self.tokenField.leadingAnchor],
        [help.trailingAnchor constraintEqualToAnchor:self.tokenField.trailingAnchor]
    ]];
}
- (void)restoreEndpoint { self.tokenField.text = [VEAIPolicy defaultEndpointForProvider:self.provider]; }
- (void)saveEndpoint {
    NSString *endpoint = [self.tokenField.text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    NSString *preview = endpoint.length ? endpoint : [VEAIPolicy defaultEndpointForProvider:self.provider];
    preview = [[preview stringByReplacingOccurrencesOfString:@"{account_id}" withString:@"00000000000000000000000000000000"] stringByReplacingOccurrencesOfString:@"{model}" withString:@"clef"];
    NSURLComponents *components = [NSURLComponents componentsWithString:preview];
    if (![@[@"http", @"https"] containsObject:components.scheme.lowercaseString] || !components.host.length || components.user || components.password) {
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Invalid URL" message:@"Enter a complete HTTP or HTTPS endpoint URL." preferredStyle:UIAlertControllerStyleAlert];
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
