//
//  LogManager.h
//  Vē
//
//  Created by Alexandra Aurora Göttlicher
//

#import <Foundation/Foundation.h>

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
// Returns NO for an unchanged notification already present in the saved logs.
- (BOOL)addLogForBulletin:(BBBulletin *)bulletin;
- (BOOL)addLogForBulletin:(BBBulletin *)bulletin recordID:(NSString **)recordID;
- (Log *)logForRecordID:(NSString *)recordID;
- (void)removeLog:(Log *)log;
- (void)removeAllLogs;
- (NSArray *)getAttachmentsForLog:(Log *)log;
- (NSMutableArray *)getLogsFromJson:(NSMutableDictionary *)json;
- (NSMutableDictionary *)getJson;
- (BOOL)isBulletinIDAlreadyExists:(NSString *)bulletinID;
@end
