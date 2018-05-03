//
//  FileTransfer.m
//  moffice
//
//  Created by 30san on 2018/3/5.
//  Copyright © 2018年 Facebook. All rights reserved.
//

#import "FileTransfer.h"
#import "SANFtp.h"
#import "GRRequestsManager.h"
#import "GRListingRequest.h"
#import "GRRequest.h"
#import "GRUploadRequest.h"
#import "GRDownloadRequest.h"

@interface FileTransfer ()<GRRequestsManagerDelegate>

@property (nonatomic, strong) NSDictionary* cmd;
@property (nonatomic, strong) GRRequestsManager *requestsManager;
@property (nonatomic, strong) NSMutableDictionary* accountDir;
@property (nonatomic, strong) NSMutableDictionary* ftpDir;
@property (nonatomic, strong) NSString *hostname;
@property (nonatomic, strong) NSString *username;
@property (nonatomic, strong) NSString *password;
@property (nonatomic, strong) NSString *port;
@property (nonatomic, strong) NSString *localPath;
@property (nonatomic, strong) NSString *remoteFilePath;
@property (nonatomic, strong) NSString *toAccount;
@property (nonatomic, strong) NSString *transferId;
@property (nonatomic, strong) NSString *fileMimeType;
@property (nonatomic, assign) BOOL isUpload;
@property (nonatomic, assign) NSInteger *fileSize;
@property (nonatomic, strong) NSString *ftpType;

@property (nonatomic, strong) NSTimer *timer;
@property (nonatomic, strong) GRUploadRequest *uploadRequest;

@end

@implementation FileTransfer

RCT_EXPORT_MODULE();

- (NSArray<NSString *> *)supportedEvents{
  return @[@"completed",@"fileTransfer",@"updateProgress",@"cancelAllError",@"cancelCompleted"];
}

/*
 0:ftpServerIp :eg:10.131.129.21
 1:username :dummy1
 2:password :hysy@qjstx4F
 3:ftpServerPort :990
 4:localPath : (绝对路径) file:///开头，
 5:remoteFilePath : (绝对路径) ，上传时提供文件夹地址，后带 "/" eg /2016-11-11-1/，下载时提供文件地址(2016-11-11-1/down)
 6:toAccount : 当前聊天窗口的发送对象
 7:transferId : 发送文件的uuid 32位
 8:fileMimeType : other image audio
 9:isUpload : bool
 10:isSSL : bool //iOS不支持 ssl
 11:fileSize : 文件大小
 */
RCT_EXPORT_METHOD(addFtpTask:(NSDictionary *)cmd){
  dispatch_async(dispatch_get_main_queue(), ^{
    [self initData:cmd];
    SANFtp *ftp = [self getFtpWithCmd:self.cmd];
    //[ftp listWithPath:@""];
    [self addTaskToFtp:ftp cmd:self.cmd];
  });
}

//JSON:transferId toAccount fileMineType isUpload
RCT_EXPORT_METHOD(cancelFtpTask:(NSDictionary*)cmd){
  dispatch_async(dispatch_get_main_queue(), ^{
    self.toAccount = [cmd objectForKey:@"toAccount"];
    self.fileMimeType = [cmd objectForKey:@"fileMimeType"];
    self.isUpload = [[cmd objectForKey:@"isUpload"] boolValue];
    self.ftpType = [self getFtpTypeWithfileMimeType:self.fileMimeType isUpload:self.isUpload];
    self.transferId = [cmd objectForKey:@"transferId"];
    NSDictionary *ftpDic = [self.accountDir objectForKey:self.toAccount];
    NSArray *ftpArr = [ftpDic objectForKey:self.ftpType];
    SANFtp *getFtp = ftpArr[0];
    //取消当前任务后清除未上传／下载完成的垃圾文件 fileUPFtp fileDownFtp imageUPFtp imageDownFtp audioUPFtp audioDownFtp
    if (self.isUpload) {
      for (int index = 0; index < getFtp.requestsManager.requestQueue.count; index ++) {
        GRUploadRequest<GRRequestDelegate> *getRequest = getFtp.requestsManager.requestQueue.items[index];
        if ([getRequest.uuid isEqualToString:self.transferId]) {
          [getFtp.requestsManager.requestQueue removeObject:getRequest];
        }else{
          continue;
        }
      }
      GRUploadRequest<GRRequestDelegate> *currentRequest = getFtp.requestsManager.currentRequest;
      if ([currentRequest.uuid isEqualToString:self.transferId]) {
        [getFtp cancelCurrentRequest];
        //[self.pluginResult setKeepCallbackAsBool:YES];
        //上传取消，删除服务器文件  --测试后发现上传中断服务器上并不会有垃圾文件
        //[getFtp deleteFileWithPath:getFtp.remotePath];
      }
      
    }else {
      for (int index = 0; index < getFtp.requestsManager.requestQueue.count; index ++) {
        GRDownloadRequest<GRRequestDelegate> *getRequest = getFtp.requestsManager.requestQueue.items[index];
        if ([getRequest.uuid isEqualToString:self.transferId]) {
          [getFtp.requestsManager.requestQueue removeObject:getRequest];
        }else{
          continue;
        }
      }
      GRDownloadRequest<GRRequestDelegate> *currentRequest = getFtp.requestsManager.currentRequest;
      if ([currentRequest.uuid isEqualToString:self.transferId]) {
        [getFtp cancelCurrentRequest];
        //[self.pluginResult setKeepCallbackAsBool:YES];
        //下载取消，删除本地文件
        NSFileManager *fileMgr = [NSFileManager defaultManager];
        NSError *err;
        [fileMgr removeItemAtPath:getFtp.localPath error:&err];
      }
    }
    //        [getFtp cancelAllRequests];
    //删除完成后的提示
    NSDictionary *callbackDic = [NSMutableDictionary dictionary];
    [callbackDic setValue:@"cancelSuccess" forKey:@"value"];
    [callbackDic setValue:self.transferId forKey:@"transferId"];
    [self sendEventWithName:@"cancelCompleted" body:callbackDic];
  });
}

- (void)initData:(NSDictionary*)jsonDic{
  self.cmd = jsonDic;
  self.hostname = [jsonDic objectForKey:@"ftpServerIp"];
  self.username = [jsonDic objectForKey:@"username"];
  self.password = [jsonDic objectForKey:@"password"];
  self.port = [NSString stringWithFormat:@"%@",[jsonDic objectForKey:@"ftpServerPort"]];
  [jsonDic setValue:self.port forKey:@"ftpServerPort"];
  self.toAccount = [jsonDic objectForKey:@"toAccount"];
  self.transferId = [jsonDic objectForKey:@"transferId"];
  self.fileMimeType = [jsonDic objectForKey:@"fileMimeType"];
  self.isUpload = [[jsonDic objectForKey:@"isUpload"] boolValue];
  [jsonDic setValue:[NSNumber numberWithBool:self.isUpload] forKey:@"isUpload"];
  self.localPath = [self getRealFilePath:[jsonDic objectForKey:@"localPath"]];
  self.fileSize = [[jsonDic objectForKey:@"fileSize"] longValue];
  NSString *localPath = [jsonDic objectForKey:@"localPath"];
  if ([[localPath substringToIndex:7] isEqualToString:@"file://"]) {
    self.localPath = [localPath substringFromIndex:7];
  }
  [jsonDic setValue:self.localPath forKey:@"localPath"];
  NSString *remoteFilePath = [jsonDic objectForKey:@"remoteFilePath"];
  self.remoteFilePath = remoteFilePath;
  if (self.isUpload) {
    self.remoteFilePath = [NSString stringWithFormat:@"%@/%@",remoteFilePath,self.transferId];
  }
  [jsonDic setValue:self.remoteFilePath forKey:@"remoteFilePath"];
  self.ftpType = [self getFtpTypeWithfileMimeType:self.fileMimeType isUpload:self.isUpload];
  self.cmd = jsonDic;
}



#pragma mark - getFtp
- (SANFtp*)getFtpWithCmd:(NSDictionary*)cmd{
  if (!self.accountDir) {
    self.accountDir = [NSMutableDictionary dictionary];
  }
  NSMutableDictionary *ftpDic = [self.accountDir objectForKey:self.toAccount];
  if (ftpDic) {
    //已经与该account创建过连接
    NSArray *ftpArr = [ftpDic objectForKey:self.ftpType];
    if (ftpArr) {
      //已在此account建立过指定ftp
      SANFtp *getFtp = ftpArr[0];
      if ([self.hostname isEqualToString:getFtp.hostname]) {
        //新建传输任务与之前传输任务的hostname一致
        return getFtp;
      }else{
        SANFtp *newFtp = [self creatNewFtpWithCmd:cmd];
        NSArray *ftpArr = @[newFtp,cmd];
        [ftpDic setObject:ftpArr forKey:self.ftpType];
        [self.accountDir setObject:ftpDic forKey:self.toAccount];
        return newFtp;
      }
    }else{
      //未在此account建立过指定ftp
      SANFtp *newFtp = [self creatNewFtpWithCmd:cmd];
      NSArray *ftpArr = @[newFtp,cmd];
      [ftpDic setObject:ftpArr forKey:self.ftpType];
      [self.accountDir setObject:ftpDic forKey:self.toAccount];
      return newFtp;
    }
  }else{
    //未创建过此account的连接
    NSMutableDictionary *ftpDic = [NSMutableDictionary dictionary];
    SANFtp *newFtp = [self creatNewFtpWithCmd:cmd];
    NSArray *ftpArr = @[newFtp,cmd];
    [ftpDic setObject:ftpArr forKey:self.ftpType];
    [self.accountDir setObject:ftpDic forKey:self.toAccount];
    return newFtp;
  }
}

- (NSString *)getFtpTypeWithfileMimeType:(NSString *)fileMimeType isUpload:(BOOL)isUpload{
  if ([fileMimeType isEqualToString:@"image"]) {
    return isUpload ? @"imageUPFtp" : @"imageDownFtp";
  }else if([fileMimeType isEqualToString:@"audio"]){
    return isUpload ? @"audioUPFtp" : @"audioDownFtp";
  }else{
    return isUpload ? @"fileUPFtp" : @"fileDownFtp";
  }
}

- (SANFtp*)creatNewFtpWithCmd:(NSDictionary *)cmd{
  SANFtp *sanFtp = [[SANFtp alloc]initWithHostname:self.hostname
                                          username:self.username
                                          password:self.password
                                              port:self.port
                                           ftpType:self.ftpType];
  sanFtp.requestsManager.delegate = self;
  return sanFtp;
}

#pragma mark - ftpTask
- (void)addTaskToFtp:(SANFtp*)ftp cmd:(NSDictionary*)cmd{
  if(self.isUpload){
    [self uploadTaskStart:ftp requestDic:cmd];
  }else{
    [self downloadTaskStart:ftp requestDic:cmd];
  }
}

/*upLoadTask*/
- (void)uploadTaskStart:(SANFtp*)ftp requestDic:(NSDictionary*)requestDic{
  [self creatNewFtpToCreateDir];
  [ftp uploadFileWithlocalPath:self.localPath remotePath:self.remoteFilePath requestDic:requestDic];
  //[self.pluginResult setKeepCallbackAsBool:YES];
}
- (void)creatNewFtpToCreateDir{
  SANFtp *createDirFtp = [[SANFtp alloc]initWithHostname:self.hostname
                                                username:self.username
                                                password:self.password
                                                    port:self.port
                                                 ftpType:self.ftpType];
  NSString *dirPath = [self.remoteFilePath stringByDeletingLastPathComponent];
  createDirFtp.requestsManager.delegate = self;
  [createDirFtp createDirectoryWithPath:dirPath];
}

/*downLoadTask*/
- (void)downloadTaskStart:(SANFtp*)ftp requestDic:(NSDictionary*)requestDic{
  [ftp downloadFileWithlocalPath:self.localPath remotePath:self.remoteFilePath requestDic:requestDic];
  //[self.pluginResult setKeepCallbackAsBool:YES];
}

#pragma mark - GRRequestsManagerDelegate
//获取list的回调
- (void)requestsManager:(id<GRRequestsManagerProtocol>)requestsManager didCompleteListingRequest:(id<GRRequestProtocol>)request listing:(NSArray *)listing{
  NSMutableArray* newFilesInfo = [[NSMutableArray alloc] init];
  for (NSDictionary* file in ((GRListingRequest *)request).filesInfo) {
    NSMutableDictionary* newFile = [[NSMutableDictionary alloc] init];
    //找到对应的name
    NSString* name = [file objectForKey:(id)kCFFTPResourceName];
    if ([name isEqualToString:self.transferId]) {
      //校验文件大小是否符合要求
      NSNumber* size = [file objectForKey:(id)kCFFTPResourceSize];
      if ([size longValue] < self.fileSize) {
        NSLog(@"文件上传校验未通过，暂不关闭传输");
      }else{
        NSLog(@"文件上传校验通过，关闭传输");
        //关闭GRUploadRequest
        [self.uploadRequest.streamInfo close:self.uploadRequest];
        //关闭计时器
        [self.timer invalidate];
        self.timer = nil;
      }
    }
    
    
    
  }
}

//在服务器上创建文件夹
- (void)requestsManager:(id<GRRequestsManagerProtocol>)requestsManager didCompleteCreateDirectoryRequest:(id<GRRequestProtocol>)request{
  NSLog(@"requestsManager:didCompleteCreateDirectoryRequest: Create directory OK");
}

//在服务器上删除
- (void)requestsManager:(id<GRRequestsManagerProtocol>)requestsManager didCompleteDeleteRequest:(id<GRRequestProtocol>)request{
  NSLog(@"requestsManager:didCompleteDeleteRequest: Delete file/directory OK");
}

//加载插件完成的回调
- (void)requestsManager:(id<GRRequestsManagerProtocol>)requestsManager didScheduleRequest:(id<GRRequestProtocol>)request{
  NSDictionary *jsonDic = request.requestDic;
  if (jsonDic){
    NSString *transferId = [jsonDic objectForKey:@"transferId"];
    NSDictionary *callbackDic = [NSMutableDictionary dictionary];
    [callbackDic setValue:@(0) forKey:@"percent"];
    [callbackDic setValue:transferId forKey:@"transferId"];
    [self sendEventWithName:@"updateProgress" body:callbackDic];
  }
}

//文件传输进度
- (void)requestsManager:(id<GRRequestsManagerProtocol>)requestsManager didCompletePercent:(float)percent forRequest:(id<GRRequestProtocol>)request{
  if (percent >= 0 && percent < 1) {
    NSDictionary *jsonDic = request.requestDic;
    NSString *transferId = [jsonDic objectForKey:@"transferId"];
    NSDictionary *callbackDic = [NSMutableDictionary dictionary];
    NSLog(@"ftp_percent:%f",percent);
    [callbackDic setValue:@(percent) forKey:@"percent"];
    [callbackDic setValue:transferId forKey:@"transferId"];
    [self sendEventWithName:@"updateProgress" body:callbackDic];
    /*
     多个任务时无法回馈给指定的任务准确进度，待改进
     */
  }
}

//上传完成
- (void)requestsManager:(id<GRRequestsManagerProtocol>)requestsManager didCompleteUploadRequest:(id<GRDataExchangeRequestProtocol>)request{
  self.uploadRequest = request;
  [self uploadCheck];
  NSDictionary *jsonDic = request.requestDic;
  NSString *transferId = [jsonDic objectForKey:@"transferId"];
  NSDictionary *callbackDic = [NSMutableDictionary dictionary];
  [callbackDic setValue:@(1) forKey:@"percent"];
  [callbackDic setValue:transferId forKey:@"transferId"];
  [callbackDic setValue:@"YES" forKey:@"isUpload"];
  [self sendEventWithName:@"completed" body:callbackDic];
}
//上传成功校验，确认服务器上存在文件且大小正确后再去关闭传输连接
- (void)uploadCheck{
  self.timer = [NSTimer scheduledTimerWithTimeInterval:0.3f target:self selector:@selector(getFlieList:) userInfo:nil repeats:YES];
  [self.timer fire];
}
- (void)getFlieList:(NSTimer*)timer{
  NSMutableDictionary *ftpDic = [self.accountDir objectForKey:self.toAccount];
  NSArray *ftpArr = [ftpDic objectForKey:self.ftpType];
  SANFtp *getFtp = ftpArr[0];
  NSString *listPath = [self.remoteFilePath componentsSeparatedByString:@"/"][0];
  [getFtp listWithPath:listPath];
}

//下载完成
- (void)requestsManager:(id<GRRequestsManagerProtocol>)requestsManager didCompleteDownloadRequest:(id<GRDataExchangeRequestProtocol>)request{
  NSDictionary *jsonDic = request.requestDic;
  NSString *toAccount = [jsonDic objectForKey:@"toAccount"];
  NSString *transferId = [jsonDic objectForKey:@"transferId"];
  NSDictionary *ftpDic = [self.accountDir objectForKey:toAccount];
  NSArray *ftpArr = [ftpDic objectForKey:requestsManager.ftpType];
  
  NSDictionary *callbackDic = [NSMutableDictionary dictionary];
  [callbackDic setValue:@(1) forKey:@"percent"];
  [callbackDic setValue:transferId forKey:@"transferId"];
  [self sendEventWithName:@"completed" body:callbackDic];
  
}

- (void)requestsManager:(id<GRRequestsManagerProtocol>)requestsManager didFailWritingFileAtPath:(NSString *)path forRequest:(id<GRDataExchangeRequestProtocol>)request error:(NSError *)error{
  
  NSLog(@"requestsManager:didFailWritingFileAtPath:forRequest:error: \n %@", error);
  NSString* errorMsg = nil;
  if ([error userInfo] == nil || (errorMsg = [[error userInfo] valueForKey:@"message"]) == nil) {
    errorMsg = [error localizedDescription];
  }
  [self sendEventWithName:@"fileTransfer" body:errorMsg];
  
}

//失败回调
- (void)requestsManager:(id<GRRequestsManagerProtocol>)requestsManager didFailRequest:(id<GRRequestProtocol>)request withError:(NSError *)error{
  NSLog(@"requestsManager:didFailRequest:withError: \n %@", error);
  NSDictionary *jsonDic = request.requestDic;
  if (jsonDic) {
    NSString *toAccount = [jsonDic objectForKey:@"toAccount"];
    NSString *transferId = [jsonDic objectForKey:@"transferId"];
    NSDictionary *ftpDic = [self.accountDir objectForKey:toAccount];
    NSArray *ftpArr = [ftpDic objectForKey:requestsManager.ftpType];
    [self callbackErrorWithTransferId:transferId error:error];
  }else{
    //文件操作的异常不回传给js端
    //        [self callbackErrorWithCmd:self.cmd transferId:self.transferId error:error];
  }
  
}
- (void)callbackErrorWithTransferId:(NSString *)transferId error:(NSError *)error{
  NSDictionary *callbackDic = [NSMutableDictionary dictionary];
  NSString *errorStr = [error.userInfo objectForKey:@"message"];
  [callbackDic setValue:errorStr forKey:@"error"];
  [callbackDic setValue:transferId forKey:@"transferId"];
  [self sendEventWithName:@"fileTransfer" body:callbackDic];
  
}

- (NSString *)getRealFilePath:(NSString *)filePath{
  NSArray *documentsPathArr = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
  NSString *document = [documentsPathArr lastObject];
  if ([filePath rangeOfString:document].length == 0){
    return [NSString stringWithFormat:@"%@%@",document,filePath];
  } else {
    return filePath;
    
  }
}

@end
