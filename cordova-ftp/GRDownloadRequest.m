//
//  GRDownloadRequest.m
//  GoldRaccoon
//  v1.0.1
//
//  Created by Valentin Radu on 8/23/11.
//  Copyright 2011 Valentin Radu. All rights reserved.
//
//  Modified and/or redesigned by Lloyd Sargent to be ARC compliant.
//  Copyright 2012 Lloyd Sargent. All rights reserved.
//
//  Modified and redesigned by Alberto De Bortoli.
//  Copyright 2013 Alberto De Bortoli. All rights reserved.
//

#import "GRDownloadRequest.h"

@interface GRDownloadRequest ()

@property (nonatomic, strong) NSData *receivedData;

@property (nonatomic, assign) BOOL hadUpLoad;

@end

@implementation GRDownloadRequest

@synthesize localFilePath = _localFilePath;
@synthesize fullRemotePath = _fullRemotePath;

- (void)start
{
    if ([self.delegate respondsToSelector:@selector(dataAvailable:forRequest:)] == NO) {
        [self.streamInfo streamError:self errorCode:kGRFTPClientMissingRequestDataAvailable];
        return;
    }
    
    // open the read stream and check for errors calling delegate methods
    // if things fail. This encapsulates the streamInfo object and cleans up our code.
    [self.streamInfo openRead:self];
}

- (void)stream:(NSStream *)theStream handleEvent:(NSStreamEvent)streamEvent
{
    self.hadUpLoad = NO;
    // see if we have cancelled the runloop
    if ([self.streamInfo checkCancelRequest:self]) {
        return;
    }
    //获取传入的文件大小的参数
    long fileSize = [[self.requestDic objectForKey:@"fileSize"] longValue];
    switch (streamEvent) {
        case NSStreamEventOpenCompleted: {
            self.maximumSize = [[theStream propertyForKey:(id)kCFStreamPropertyFTPResourceSize] integerValue];
            self.didOpenStream = YES;
            self.streamInfo.bytesTotal = 0;
            self.receivedData = [NSMutableData data];
            long getFileSize = (long)self.maximumSize;
            if (getFileSize == fileSize) {
                self.hadUpLoad = YES;
                NSLog(@"本次下载文件大小(获取自服务器/获取自参数):%ld/%ld",getFileSize,fileSize);
            }else{
                NSLog(@"本次下载文件大小(获取自服务器/获取自参数):%ld/%ld,上传方上传未完成",getFileSize,fileSize);
            }
            
        }
        break;
        
        case NSStreamEventHasBytesAvailable: {
            self.receivedData = [self.streamInfo read:self];
            if (self.receivedData) {
                if ([self.delegate respondsToSelector:@selector(dataAvailable:forRequest:)]) {
                    [self.delegate dataAvailable:self.receivedData forRequest:self];
                }
            }
            else {
                [self.streamInfo streamError:self errorCode:kGRFTPClientCantReadStream];
            }
        }
        break;
        
        case NSStreamEventHasSpaceAvailable: {
            
        }
        break;
        
        case NSStreamEventErrorOccurred: {
            [self.streamInfo streamError:self errorCode:[GRError errorCodeWithError:[theStream streamError]]];
        }
        break;
        
        case NSStreamEventEndEncountered: {
            //完成下载后将临时文件后缀去掉
            NSString *filePath = _localFilePath;
            NSString *finshFilePath = [_localFilePath substringToIndex:[filePath length] - 4];//去掉最后四位
            NSError *error;
            BOOL rename = [[NSFileManager defaultManager] moveItemAtPath:filePath toPath:finshFilePath error:&error];
            if (rename) {
                [[NSFileManager defaultManager] removeItemAtPath:filePath error:&error];
            }
            
            [self.streamInfo streamComplete:self];
        }
        break;
        
        default:
        break;
    }
}

- (NSString *)fullRemotePath
{
    return [[self fullURL] absoluteString];
}

@end
