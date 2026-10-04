#import "VeAPIRawDataController.h"
#import "../../../Manager/LogManager.h"
#import "../../../Manager/Log.h"
#import "../../../Manager/VEAPILog.h"
#import "../../../Preferences/NotificationKeys.h"

@interface VeAPIRawDataController ()
@property(nonatomic, copy) NSString *recordID;
@property(nonatomic, copy) NSString *channel;
@property(nonatomic, strong) UITextView *viewer;
@property(nonatomic, strong) NSDictionary *trace;
@end

@implementation VeAPIRawDataController
- (instancetype)initWithRecordID:(NSString *)recordID channel:(NSString *)channel title:(NSString *)title {
    self = [super init];
    if (self) {
        _recordID = [recordID copy];
        _channel = [channel copy];
        self.title = title;
    }
    return self;
}
- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = UIColor.systemBackgroundColor;
    UILabel *notice = [UILabel new];
    notice.text = @"New logs preserve full request and response bodies, including credentials. Older logs may be redacted or incomplete.";
    notice.numberOfLines = 0;
    notice.font = [UIFont preferredFontForTextStyle:UIFontTextStyleFootnote];
    notice.textColor = UIColor.secondaryLabelColor;
    notice.translatesAutoresizingMaskIntoConstraints = NO;
    self.viewer = [UITextView new];
    self.viewer.editable = NO;
    self.viewer.selectable = YES;
    self.viewer.font = [UIFont monospacedSystemFontOfSize:12 weight:UIFontWeightRegular];
    self.viewer.accessibilityIdentifier = @"ve.api.raw";
    self.viewer.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:notice];
    [self.view addSubview:self.viewer];
    [NSLayoutConstraint activateConstraints:@[
        [notice.topAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.topAnchor constant:12],
        [notice.leadingAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.leadingAnchor constant:12],
        [notice.trailingAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.trailingAnchor constant:-12],
        [self.viewer.topAnchor constraintEqualToAnchor:notice.bottomAnchor constant:8],
        [self.viewer.leadingAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.leadingAnchor constant:8],
        [self.viewer.trailingAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.trailingAnchor constant:-8],
        [self.viewer.bottomAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.bottomAnchor constant:-8]
    ]];
    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:@"Copy" style:UIBarButtonItemStylePlain target:self action:@selector(showCopyMenu)];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(refresh:) name:kNotificationKeyLogsChanged object:nil];
    [self refresh:nil];
}
- (void)dealloc { [[NSNotificationCenter defaultCenter] removeObserver:self]; }
- (void)refresh:(NSNotification *)notification {
    Log *log = [[LogManager sharedInstance] logForRecordID:self.recordID];
    NSDictionary *trace;
    if ([self.channel isEqual:@"api_log"]) {
        trace = log.aiInfo[@"api_log"];
    } else {
        NSMutableDictionary *bark = [NSMutableDictionary new];
        if (log.aiInfo[@"bark_api_log"]) bark[@"automatic"] = log.aiInfo[@"bark_api_log"];
        if (log.aiInfo[@"manual_bark_api_log"]) bark[@"manual"] = log.aiInfo[@"manual_bark_api_log"];
        trace = bark;
    }
    if (![trace isKindOfClass:[NSDictionary class]] || !trace.count) {
        self.viewer.text = @"Raw data for this API call was not recorded. New requests record their request and response data.";
        self.navigationItem.rightBarButtonItem.enabled = NO;
        return;
    }
    self.trace = trace;
    if ([self.channel isEqual:@"api_log"]) self.viewer.text = [VEAPILog textForTrace:trace];
    else {
        NSMutableString *text = [NSMutableString new];
        if (trace[@"automatic"]) [text appendFormat:@"AUTOMATIC BARK\n%@", [VEAPILog textForTrace:trace[@"automatic"]]];
        if (trace[@"manual"]) [text appendFormat:@"\nMANUAL BARK\n%@", [VEAPILog textForTrace:trace[@"manual"]]];
        self.viewer.text = text;
    }
    self.navigationItem.rightBarButtonItem.enabled = YES;
}
- (void)addBodyActions:(UIAlertController *)menu trace:(NSDictionary *)trace prefix:(NSString *)prefix {
    for (NSString *part in @[@"request", @"response"]) {
        NSDictionary *record = trace[part];
        NSData *bytes = [VEAPILog bodyDataFromRecord:record];
        if (!bytes || ![record[@"body_present"] boolValue]) continue;
        NSString *body = [[NSString alloc] initWithData:bytes encoding:NSUTF8StringEncoding];
        NSString *title = [NSString stringWithFormat:@"%@%@ Body%@", prefix, [part capitalizedString], body ? @"" : @" (Base64)"];
        NSString *copied = body ?: record[@"body_base64"];
        [menu addAction:[UIAlertAction actionWithTitle:title style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
            [UIPasteboard generalPasteboard].string = copied;
        }]];
    }
}
- (void)showCopyMenu {
    UIAlertController *menu = [UIAlertController alertControllerWithTitle:@"Copy Raw Data" message:nil preferredStyle:UIAlertControllerStyleActionSheet];
    [menu addAction:[UIAlertAction actionWithTitle:@"Full Trace" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
        [UIPasteboard generalPasteboard].string = self.viewer.text;
    }]];
    [menu addAction:[UIAlertAction actionWithTitle:@"JSON Archive" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
        NSData *data = [NSJSONSerialization dataWithJSONObject:self.trace options:0 error:nil];
        if (data) [UIPasteboard generalPasteboard].string = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
    }]];
    if ([self.channel isEqual:@"api_log"]) [self addBodyActions:menu trace:self.trace prefix:@""];
    else {
        if (self.trace[@"automatic"]) [self addBodyActions:menu trace:self.trace[@"automatic"] prefix:@"Automatic "];
        if (self.trace[@"manual"]) [self addBodyActions:menu trace:self.trace[@"manual"] prefix:@"Manual "];
    }
    [menu addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:nil]];
    menu.popoverPresentationController.barButtonItem = self.navigationItem.rightBarButtonItem;
    [self presentViewController:menu animated:YES completion:nil];
}
@end
