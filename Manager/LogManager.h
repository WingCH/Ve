//
//  LogManager.h
//  Vē
//
//  Created by Alexandra Aurora Göttlicher
//

#import <Foundation/Foundation.h>
#import <rootless.h>

@class Log;
@class BBBulletin;

@interface LogManager : NSObject {
    NSFileManager* _fileManager;
}
@property(nonatomic)BOOL saveLocalAttachments;
@property(nonatomic)BOOL saveRemoteAttachments;
@property(nonatomic)NSUInteger logLimit;
@property(nonatomic)BOOL automaticallyDeleteLogs;
+ (NSString *)logsPath;
+ (NSString *)logsAttachmentPath;
+ (instancetype)sharedInstance;
- (void)addLogForBulletin:(BBBulletin *)bulletin;
- (void)removeLog:(Log *)log;
- (NSArray *)getAttachmentsForLog:(Log *)log;
- (NSMutableArray *)getLogsFromJson:(NSMutableDictionary *)json;
- (NSMutableDictionary *)getJson;
@end
