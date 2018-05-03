//
//  SANFtp.m
//  simclient-ios
//
//  Created by 30san-jiangyb on 16/10/31.
//
//

#import "SANFtp.h"
#import "GRListingRequest.h"

@interface SANFtp () <GRRequestsManagerDelegate>

@end

@implementation SANFtp

- (instancetype)initWithHostname:(NSString*)hostname username:(NSString*)username password:(NSString*)password port:(NSString *)port ftpType:(NSString*)ftpType{
    self = [super init];
    if (self) {
        self.hostname = hostname;
        self.username = username;
        self.password = password;
        self.ftpType = ftpType;
        self.port = port;
        self.requestsManager = [[GRRequestsManager alloc] initWithHostname:self.hostname
                                                                      user:self.username
                                                                  password:self.password
                                                                      port:self.port
                                                                   ftpType:self.ftpType];
        self.requestsManager.delegate = self;
    }
    return self;
}

- (void)listWithPath:(NSString*)path{
    if (path == nil){
        NSLog(@"path为空");
    }else{
        self.remotePath = path;
        if ([path characterAtIndex:path.length - 1] != '/'){
            path = [path stringByAppendingString:@"/"];
        }
        [self.requestsManager addRequestForListDirectoryAtPath:path];
        [self.requestsManager startProcessingRequests];
    }
}

- (void)createDirectoryWithPath:(NSString*)path{
    if (path == nil){
        NSLog(@"path为空");
    }else{
        self.remotePath = path;
        if ([path characterAtIndex:path.length - 1] != '/'){
            path = [path stringByAppendingString:@"/"];
        }
        
        [self.requestsManager addRequestForCreateDirectoryAtPath:path];
        [self.requestsManager startProcessingRequests];
    }
}

- (void)deleteDirectoryWithPath:(NSString*)path{
    if (path == nil){
        NSLog(@"path为空");
    }else{
        self.remotePath = path;
        if ([path characterAtIndex:path.length - 1] != '/'){
            path = [path stringByAppendingString:@"/"];
        }
        [self.requestsManager addRequestForDeleteDirectoryAtPath:path];
        [self.requestsManager startProcessingRequests];
    }
}

- (void)deleteFileWithPath:(NSString*)path{
    if (path == nil){
        NSLog(@"path为空");
    }else{
        self.remotePath = path;
        [self.requestsManager addRequestForDeleteFileAtPath:path];
        [self.requestsManager startProcessingRequests];
    }
}

- (void)uploadFileWithlocalPath:(NSString*)localPath remotePath:(NSString*)remotePath requestDic:(NSDictionary*)requestDic{
    if ([localPath length] == 0 || [remotePath length] == 0){
        NSLog(@"path为空");
    }else{
        self.localPath = localPath;
        //去创建文件夹
        NSString *dirPath = [remotePath stringByDeletingLastPathComponent];
        [self createDirectoryWithPath:dirPath];
        
        self.remotePath = remotePath;
        [self.requestsManager addRequestForUploadFileAtLocalPath:localPath toRemotePath:remotePath requestDic:requestDic];
        [self.requestsManager startProcessingRequests];
    }
}

- (void)downloadFileWithlocalPath:(NSString*)localPath remotePath:(NSString*)remotePath requestDic:(NSDictionary*)requestDic{
    if ([localPath length] == 0 || [remotePath length] == 0){
      NSLog(@"path为空");
    }else{
      self.localPath = localPath;
      NSFileManager *flieManger = [NSFileManager defaultManager];
      NSString *filePath = [NSString stringWithFormat:@"%@.sim",localPath];
      NSString *dirPath = [localPath substringToIndex:[localPath rangeOfString:[localPath pathComponents].lastObject].location];
      BOOL fileExists = [flieManger fileExistsAtPath:localPath];
      if (!fileExists){
        BOOL fileDirExists = [flieManger fileExistsAtPath:dirPath];
        if (!fileDirExists){
          //文件路径不存在，先补全路径
          [flieManger createDirectoryAtPath:dirPath withIntermediateDirectories:YES attributes:nil error:nil];
        }
        self.remotePath = remotePath;
        [flieManger createFileAtPath:filePath contents:NULL attributes:nil];
        [self.requestsManager addRequestForDownloadFileAtRemotePath:remotePath toLocalPath:filePath requestDic:requestDic];
        [self.requestsManager startProcessingRequests];
      } else{
        NSLog(@"本地存在该文件，不下载");
      }
    }
}

- (void)cancelAllRequests{
    [self.requestsManager stopAndCancelAllRequests];
}

- (void)cancelCurrentRequest{
    [self.requestsManager cancelCurrentRequest];
}

@end
