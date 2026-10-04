#import "VeAPIRawDataController.h"
#import "../../../Manager/LogManager.h"
#import "../../../Manager/Log.h"
#import "../../../Preferences/NotificationKeys.h"

@interface VeAPIRawDataController ()
@property(nonatomic, copy) NSString *recordID;
@property(nonatomic, strong) UITextView *viewer;
@end

@implementation VeAPIRawDataController
- (instancetype)initWithRecordID:(NSString *)recordID {
    self = [super init];
    if (self) _recordID = [recordID copy];
    return self;
}
- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"AI API Raw Data";
    self.view.backgroundColor = UIColor.systemBackgroundColor;
    UILabel *notice = [UILabel new];
    notice.text = @"Credentials are redacted. Each body is limited to 16 KiB. Larger bodies are marked as truncated.";
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
    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:@"Copy JSON" style:UIBarButtonItemStylePlain target:self action:@selector(copyJSON)];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(refresh:) name:kNotificationKeyLogsChanged object:nil];
    [self refresh:nil];
}
- (void)dealloc { [[NSNotificationCenter defaultCenter] removeObserver:self]; }
- (void)refresh:(NSNotification *)notification {
    Log *log = [[LogManager sharedInstance] logForRecordID:self.recordID];
    NSDictionary *trace = log.aiInfo[@"api_log"];
    if (!trace) {
        self.viewer.text = @"API raw data was not recorded for this notification. New AI requests record their request and response data.";
        self.navigationItem.rightBarButtonItem.enabled = NO;
        return;
    }
    NSData *data = [NSJSONSerialization dataWithJSONObject:trace options:NSJSONWritingPrettyPrinted | NSJSONWritingSortedKeys error:nil];
    self.viewer.text = data ? [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding] : @"API raw data could not be displayed.";
    self.navigationItem.rightBarButtonItem.enabled = data != nil;
}
- (void)copyJSON { [UIPasteboard generalPasteboard].string = self.viewer.text; }
@end
