//
//  SANFtp.h
//  simclient-ios
//
//  Created by 30san-jiangyb on 16/10/31.
//
//

#import <Foundation/Foundation.h>
#import "GRRequestsManager.h"

@interface SANFtp : NSObject

- (instancetype)initWithHostname:(NSString*)hostname username:(NSString*)username password:(NSString*)password port:(NSString *)port ftpType:(NSString*)ftpType;

- (void)listWithPath:(NSString*)path;
- (void)createDirectoryWithPath:(NSString*)path;
- (void)deleteDirectoryWithPath:(NSString*)path;
- (void)deleteFileWithPath:(NSString*)path;

- (void)uploadFileWithlocalPath:(NSString*)localPath remotePath:(NSString*)remotePath requestDic:(NSDictionary*)requestDic;
- (void)downloadFileWithlocalPath:(NSString*)localPath remotePath:(NSString*)remotePath requestDic:(NSDictionary*)requestDic;
- (void)cancelAllRequests;
- (void)cancelCurrentRequest;

@property (nonatomic, strong) GRRequestsManager *requestsManager;
@property (nonatomic, strong) NSString *hostname;
@property (nonatomic, strong) NSString *username;
@property (nonatomic, strong) NSString *password;
@property (nonatomic, strong) NSString *localPath;
@property (nonatomic, strong) NSString *remotePath;
@property (nonatomic, strong) NSString *port;
@property (nonatomic, strong) NSString *ftpType;


@end
