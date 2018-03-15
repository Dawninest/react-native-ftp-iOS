//
//  GRRequestsManager.m
//  GoldRaccoon
//  v1.0.1
//
//  Created by Alberto De Bortoli on 14/06/2013.
//  Copyright 2013 Alberto De Bortoli. All rights reserved.
//

#import "GRRequestsManager.h"

#import "GRListingRequest.h"
#import "GRCreateDirectoryRequest.h"
#import "GRUploadRequest.h"
#import "GRDownloadRequest.h"
#import "GRDeleteRequest.h"



@interface GRRequestsManager () <GRRequestDelegate, GRRequestDataSource>
{
    BOOL writeToFileSucceeded;
}

//@property (nonatomic, copy) NSString *username;
//@property (nonatomic, copy) NSString *password;
@property (nonatomic, strong) NSMutableData *currentDownloadData;
@property (nonatomic, strong) NSData *currentUploadData;
//@property (nonatomic, strong) GRQueue *requestQueue;
//@property (nonatomic, strong) GRRequest *currentRequest;
@property (nonatomic, assign) BOOL delegateRespondsToPercentProgress;
//@property (nonatomic, assign) BOOL isRunning;

- (id<GRRequestProtocol>)_addRequestOfType:(Class)clazz withPath:(NSString *)filePath;
- (id<GRDataExchangeRequestProtocol>)_addDataExchangeRequestOfType:(Class)clazz withLocalPath:(NSString *)localPath remotePath:(NSString *)remotePath requestDic:(NSDictionary*)requestDic;
- (void)_enqueueRequest:(id<GRRequestProtocol>)request;
- (void)_processNextRequest;

@property (nonatomic, strong) NSFileHandle *file;

@end

@implementation GRRequestsManager

@synthesize hostname = _hostname;
@synthesize username = _username;
@synthesize password = _password;
@synthesize port = _port;
@synthesize ftpType = _ftpType;
@synthesize delegate = _delegate;

#pragma mark - Dealloc and Initialization

- (instancetype)init
{
    [self doesNotRecognizeSelector:_cmd];
    return nil;
}

- (instancetype)initWithHostname:(NSString *)hostname user:(NSString *)username password:(NSString *)password port:(NSString *)port ftpType:(NSString*)ftpType
{
    NSAssert([hostname length], @"hostname must not be nil");
    
    self = [super init];
    if (self) {
        _hostname = hostname;
        _username = username;
        _password = password;
        _ftpType = ftpType;
        _port = port;
        _requestQueue = [[GRQueue alloc] init];
        _isRunning = NO;
        _delegateRespondsToPercentProgress = NO;
    }
    return self;
}

- (void)dealloc
{
    [self stopAndCancelAllRequests];
}

#pragma mark - Setters

- (void)setDelegate:(id<GRRequestsManagerDelegate>)delegate
{
    if (_delegate != delegate) {
        _delegate = delegate;
        _delegateRespondsToPercentProgress = [_delegate respondsToSelector:@selector(requestsManager:didCompletePercent:forRequest:)];
    }
}

#pragma mark - Public Methods

- (void)startProcessingRequests
{
    if (_isRunning == NO) {
        _isRunning = YES;
        [self _processNextRequest];
    }
}

- (void)stopAndCancelAllRequests
{
    [self.requestQueue clear];
    self.currentRequest.cancelDoesNotCallDelegate = YES;
    [self.currentRequest cancelRequest];
    self.currentRequest = nil;
    _isRunning = NO;
}

- (void)cancelCurrentRequest
{
    [self.requestQueue removeObject:self.currentRequest];
    [self.currentRequest cancelRequest];
    _isRunning = NO;
}

- (BOOL)cancelRequest:(GRRequest *)request
{
    return [self.requestQueue removeObject:request];
}

- (NSUInteger)remainingRequests
{
    return [self.requestQueue count];
}

#pragma mark - FTP Actions

- (id<GRRequestProtocol>)addRequestForListDirectoryAtPath:(NSString *)path
{
    return [self _addRequestOfType:[GRListingRequest class] withPath:path];
}

- (id<GRRequestProtocol>)addRequestForCreateDirectoryAtPath:(NSString *)path
{
    return [self _addRequestOfType:[GRCreateDirectoryRequest class] withPath:path];
}

- (id<GRRequestProtocol>)addRequestForDeleteFileAtPath:(NSString *)filePath
{
    return [self _addRequestOfType:[GRDeleteRequest class] withPath:filePath];
}

- (id<GRRequestProtocol>)addRequestForDeleteDirectoryAtPath:(NSString *)path
{
    return [self _addRequestOfType:[GRDeleteRequest class] withPath:path];
}

- (id<GRDataExchangeRequestProtocol>)addRequestForDownloadFileAtRemotePath:(NSString *)remotePath toLocalPath:(NSString *)localPath requestDic:(NSDictionary*)requestDic
{
    return [self _addDataExchangeRequestOfType:[GRDownloadRequest class] withLocalPath:localPath remotePath:remotePath requestDic:requestDic];
}

- (id<GRDataExchangeRequestProtocol>)addRequestForUploadFileAtLocalPath:(NSString *)localPath toRemotePath:(NSString *)remotePath requestDic:(NSDictionary*)requestDic
{
    return [self _addDataExchangeRequestOfType:[GRUploadRequest class] withLocalPath:localPath remotePath:remotePath  requestDic:requestDic];
}

#pragma mark - GRRequestDelegate required
- (void)uploadRequestStart:(GRRequest *)request{
    if ([self.delegate respondsToSelector:@selector(requestsManager:didScheduleRequest:)]) {
        [self.delegate requestsManager:self didScheduleRequest:self.currentRequest];
    }
}


- (void)requestCompleted:(GRRequest *)request
{
    // listing request
    if ([request isKindOfClass:[GRListingRequest class]]) {
        NSMutableArray *listing = [NSMutableArray array];
        for (NSDictionary *file in ((GRListingRequest *)request).filesInfo) {
            [listing addObject:[file objectForKey:(id)kCFFTPResourceName]];
        }
        if ([self.delegate respondsToSelector:@selector(requestsManager:didCompleteListingRequest:listing:)]) {
            [self.delegate requestsManager:self
                 didCompleteListingRequest:((GRListingRequest *)request)
                                   listing:listing];
        }
    }
    
    // create directory request
    if ([request isKindOfClass:[GRCreateDirectoryRequest class]]) {
        if ([self.delegate respondsToSelector:@selector(requestsManager:didCompleteCreateDirectoryRequest:)]) {
            [self.delegate requestsManager:self didCompleteCreateDirectoryRequest:(GRUploadRequest *)request];
        }
    }

    // delete request
    if ([request isKindOfClass:[GRDeleteRequest class]]) {
        if ([self.delegate respondsToSelector:@selector(requestsManager:didCompleteDeleteRequest:)]) {
            [self.delegate requestsManager:self didCompleteDeleteRequest:(GRUploadRequest *)request];
        }
    }

    // upload request
    if ([request isKindOfClass:[GRUploadRequest class]]) {
        if ([self.delegate respondsToSelector:@selector(requestsManager:didCompleteUploadRequest:)]) {
            [self.delegate requestsManager:self didCompleteUploadRequest:(GRUploadRequest *)request];
        }
        _currentUploadData = nil;
    }
    
    // download request
    else if ([request isKindOfClass:[GRDownloadRequest class]]) {
        //先注解，不在最后一起写入
        
        [self.file closeFile];
        self.file = nil;
        
        NSError *writeError = nil;
        
        if (writeToFileSucceeded) {
            if ([self.delegate respondsToSelector:@selector(requestsManager:didCompleteDownloadRequest:)]) {
                [self.delegate requestsManager:self didCompleteDownloadRequest:(GRDownloadRequest *)request];
            }
        }
        else {
            if ([self.delegate respondsToSelector:@selector(requestsManager:didFailWritingFileAtPath:forRequest:error:)]) {
                [self.delegate requestsManager:self
                      didFailWritingFileAtPath:((GRDownloadRequest *)request).localFilePath
                                    forRequest:(GRDownloadRequest *)request
                                         error:writeError];
            }
        }
//        NSError *writeError = nil;
//        BOOL writeToFileSucceeded = [_currentDownloadData writeToFile:((GRDownloadRequest *)request).localFilePath
//                                                              options:NSDataWritingAtomic
//                                                                error:&writeError];
//        
//        if (writeToFileSucceeded && !writeError) {
//            if ([self.delegate respondsToSelector:@selector(requestsManager:didCompleteDownloadRequest:)]) {
//                [self.delegate requestsManager:self didCompleteDownloadRequest:(GRDownloadRequest *)request];
//            }
//        }
//        else {
//            if ([self.delegate respondsToSelector:@selector(requestsManager:didFailWritingFileAtPath:forRequest:error:)]) {
//                [self.delegate requestsManager:self
//                      didFailWritingFileAtPath:((GRDownloadRequest *)request).localFilePath
//                                    forRequest:(GRDownloadRequest *)request
//                                         error:writeError];
//            }
//        }
//        _currentDownloadData = nil;
    }
    
    [self _processNextRequest];
}

- (void)requestFailed:(GRRequest *)request
{
    if ([self.delegate respondsToSelector:@selector(requestsManager:didFailRequest:withError:)]) {
        NSError *error = [NSError errorWithDomain:@"com.albertodebortoli.goldraccoon" code:-1000 userInfo:@{@"message": request.error.message}];
        [self.delegate requestsManager:self didFailRequest:request withError:error];
    }
    
    [self _processNextRequest];
}

#pragma mark - GRRequestDelegate optional

- (void)percentCompleted:(float)percent forRequest:(id<GRRequestProtocol>)request
{
    if (_delegateRespondsToPercentProgress) {
        [self.delegate requestsManager:self didCompletePercent:percent forRequest:request];
    }
}

//static const double kBufferSize = 1000*1000;
- (void)dataAvailable:(NSData *)data forRequest:(id<GRDataExchangeRequestProtocol>)request
{
    //直接將檔案寫入disk中，不存在memeroy中
    writeToFileSucceeded = YES;
    @try {
        long num = [self.file seekToEndOfFile];
        [self.file writeData:data];
        NSLog(@"本次写入大小:%lu",(unsigned long)data.length);
        NSLog(@"下载已写入的大小:%ld",num);
    }
    @catch (NSException *exception) {
        NSLog(@"exception => %@", ((GRDownloadRequest *)request).localFilePath);
        writeToFileSucceeded = NO;
    }
    
    //    [_currentDownloadData appendData:data];
}

- (BOOL)shouldOverwriteFile:(NSString *)filePath forRequest:(id<GRDataExchangeRequestProtocol>)request
{
    // called only with GRUploadRequest requests
    return YES;
}

#pragma mark - GRRequestDataSource

- (NSString *)hostnameForRequest:(id<GRRequestProtocol>)request
{
    return self.hostname;
}

- (NSString *)usernameForRequest:(id<GRRequestProtocol>)request
{
    return self.username;
}

- (NSString *)passwordForRequest:(id<GRRequestProtocol>)request
{
    return self.password;
}

- (NSString *)portForRequest:(id<GRRequestProtocol>)request
{
    return self.port;
}

- (long)dataSizeForUploadRequest:(id<GRDataExchangeRequestProtocol>)request
{
    return [_currentUploadData length];
}

//修改
- (NSString *)dataForUploadRequest:(id<GRDataExchangeRequestProtocol>)request
{
    NSString *localFilepath = ((GRUploadRequest *)self.currentRequest).localFilePath;
    
    return localFilepath;
}

//- (NSData *)dataForUploadRequest:(id<GRDataExchangeRequestProtocol>)request
//{
//    NSData *temp = _currentUploadData;
//    _currentUploadData = nil; // next time will return nil;
//    return temp;
//}

#pragma mark - Private Methods

- (id<GRRequestProtocol>)_addRequestOfType:(Class)clazz withPath:(NSString *)filePath
{
    id<GRRequestProtocol> request = [[clazz alloc] initWithDelegate:self datasource:self transferID:nil requestDic:nil];
    request.path = filePath;
    
    [self _enqueueRequest:request];
    return request;
}

- (id<GRDataExchangeRequestProtocol>)_addDataExchangeRequestOfType:(Class)clazz withLocalPath:(NSString *)localPath remotePath:(NSString *)remotePath  requestDic:(NSDictionary*)requestDic
{
    NSString *transferID = [requestDic objectForKey:@"transferID"];
    id<GRDataExchangeRequestProtocol> request = [[clazz alloc] initWithDelegate:self datasource:self transferID:transferID requestDic:requestDic];
    request.path = remotePath;
    request.localFilePath = localPath;
    
    [self _enqueueRequest:request];
    return request;
}

- (void)_enqueueRequest:(id<GRRequestProtocol>)request
{
    [self.requestQueue enqueue:request];
}

- (void)_processNextRequest
{
    self.currentRequest = [self.requestQueue dequeue];
    
    if (self.currentRequest == nil) {
        [self stopAndCancelAllRequests];
        
        if ([self.delegate respondsToSelector:@selector(requestsManagerDidCompleteQueue:)]) {
            [self.delegate requestsManagerDidCompleteQueue:self];
        }
        
        return;
    }
    
    if ([self.currentRequest isKindOfClass:[GRDownloadRequest class]]) {
        _currentDownloadData = [NSMutableData dataWithCapacity:4096];
        //添加代码
        NSError *error;
        NSString *localPath = ((GRDownloadRequest *)self.currentRequest).localFilePath;
        [[NSFileManager defaultManager]removeItemAtPath:localPath error:&error];
        
        self.file = [NSFileHandle fileHandleForWritingAtPath:localPath];
        if(self.file == nil) {
            [[NSFileManager defaultManager] createFileAtPath:localPath contents:nil attributes:nil];
            self.file = [NSFileHandle fileHandleForWritingAtPath:localPath];
            NSLog(@"Dawninest-downLoad-localPath %@",localPath);
            NSLog(@" %@", self.file);
        }
    }
    if ([self.currentRequest isKindOfClass:[GRUploadRequest class]]) {
        NSString *localFilepath = ((GRUploadRequest *)self.currentRequest).localFilePath;
//        _currentUploadData = [NSData dataWithContentsOfFile:localFilepath];
        NSLog(@"Dawninest-upLoad-localPath %@",localFilepath);
        
//        NSInputStream *myStream = [NSInputStream inputStreamWithFileAtPath:localFilepath];
//        [myStream open];
//        Byte buffer[1024];
//        NSData *uploadData;
//        while ([myStream hasBytesAvailable])
//        {
//            int bytesRead = [myStream read:buffer maxLength:(NSUInteger)1024];
//            uploadData = [NSData dataWithBytes:buffer length:bytesRead];
//            // do other stuff...
//        }
//        [myStream close];
//        
//        
//        NSFileHandle *fileHandle=[NSFileHandle fileHandleForReadingAtPath:localFilepath];
//        
//        if (fileHandle == nil) {
//            NSLog(@"Fuck, can't read file");
//        }
//        //        [fileHandle seekToFileOffset:32768];
//        //        _currentDownloadData = (NSMutableData *)[fileHandle readDataOfLength:32768];
//        _currentUploadData =[fileHandle readDataToEndOfFile];
//        
//        NSLog(@"_currentUploadData %lu",(unsigned long)_currentDownloadData.length);
//        [fileHandle closeFile];
//        
//        
//        
//        NSError* error = nil;
//        _currentUploadData = [NSData dataWithContentsOfFile:localFilepath options:NSDataReadingMappedAlways error: &error];
//        if (_currentDownloadData == nil) {
//            NSLog(@"Failed to read file, error %@", error);
//        } else {
//            NSLog(@"_currentUploadData %lu",(unsigned long)_currentUploadData.length);
//        }

        
    }
    
    dispatch_async(dispatch_get_main_queue(), ^{
        [self.currentRequest start];
    });
    
    if (![self.currentRequest isKindOfClass:[GRUploadRequest class]]) {
        if ([self.delegate respondsToSelector:@selector(requestsManager:didScheduleRequest:)]) {
            [self.delegate requestsManager:self didScheduleRequest:self.currentRequest];
        }
    }
    
    
}

@end
