//
//  MMQueuedWormhole.m
//  MMWormhole
//
//  Created by Pierre Houston on 2015-03-11.
//  Copyright (c) 2015 Conrad Stoll. All rights reserved.
//

#import "MMQueuedWormhole.h"
#import "MMWormhole-Private.h"

@implementation MMQueuedWormhole

- (NSInteger)smallestFileNumberForIdentifier:(NSString *)identifier
{
    NSString *directoryPath = [self messagePassingDirectoryPath];
    NSString *subDirectoryPath = [directoryPath stringByAppendingPathComponent:identifier];
    
    NSInteger smallest = 0;
    NSError *error;
    NSArray *files = [self.fileManager contentsOfDirectoryAtPath:subDirectoryPath error:&error];
    
    for (NSString *filePath in files) {
        NSString *fileName = [filePath lastPathComponent];
        NSString *fileNumberString = [fileName stringByDeletingPathExtension];
        NSInteger fileNumber = fileNumberString.integerValue;
        if (fileNumber >= 0 && fileNumber < smallest) {
            smallest = fileNumber;
        }
    }
    
    return smallest;
}

- (NSInteger)largestFileNumberForIdentifier:(NSString *)identifier
{
    NSString *directoryPath = [self messagePassingDirectoryPath];
    NSString *subDirectoryPath = [directoryPath stringByAppendingPathComponent:identifier];
    
    NSInteger largest = 0;
    NSError *error;
    NSArray *files = [self.fileManager contentsOfDirectoryAtPath:subDirectoryPath error:&error];
    
    for (NSString *filePath in files) {
        NSString *fileName = [filePath lastPathComponent];
        NSString *fileNumberString = [fileName stringByDeletingPathExtension];
        NSInteger fileNumber = fileNumberString.integerValue;
        if (fileNumber > largest) {
            largest = fileNumber;
        }
    }
    
    return largest;
}

- (void)clearMessagesForIdentifier:(NSString *)identifier upToFileNumber:(NSInteger)deleteToFileNumber {
    if (identifier == nil) {
        return;
    }
    
    // first remove the single file written by the base class
    NSString *filePath = [self filePathForIdentifier:identifier];
    BOOL isDir;
    if ([self.fileManager fileExistsAtPath:filePath isDirectory:&isDir] && !isDir) {
        [self.fileManager removeItemAtPath:filePath error:NULL];
    }
    
    if (deleteToFileNumber >= 0) {
        NSString *directoryPath = [self messagePassingDirectoryPath];
        NSString *subDirectoryPath = [directoryPath stringByAppendingPathComponent:identifier];
        
        NSError *error;
        NSArray *files = [self.fileManager contentsOfDirectoryAtPath:subDirectoryPath error:&error];
        
        for (NSString *filePath in files) {
            NSString *fileName = [filePath lastPathComponent];
            NSString *fileNumberString = [fileName stringByDeletingPathExtension];
            NSInteger fileNumber = fileNumberString.integerValue;
            if (fileNumber >= 0 && fileNumber <= deleteToFileNumber) {
                [self.fileManager removeItemAtPath:filePath error:NULL];
            }
        }
    }
}


- (NSString *)filePathForIdentifier:(NSString *)identifier withFileNumber:(NSInteger)fileNumber {
    if (identifier == nil || identifier.length == 0) {
        return nil;
    }
    
    NSString *directoryPath = [self messagePassingDirectoryPath];
    NSString *subDirectoryPath = [directoryPath stringByAppendingPathComponent:identifier];
    
    BOOL isDir;
    if ([self.fileManager fileExistsAtPath:subDirectoryPath isDirectory:&isDir] && !isDir) {
        if (![self.fileManager removeItemAtPath:subDirectoryPath error:nil]) {
            return nil;
        }
    }
    
    NSString *fileName = [NSString stringWithFormat:@"%d.archive", (int)fileNumber];
    NSString *filePath = [subDirectoryPath stringByAppendingPathComponent:fileName];
    
    return filePath;
}


- (void)writeMessageObject:(id)messageObject toFileWithIdentifier:(NSString *)identifier {
    if (identifier == nil) {
        return;
    }
    
    NSData *data = messageObject ? [NSKeyedArchiver archivedDataWithRootObject:messageObject] : [NSData data];
    NSInteger fileNumber = [self largestFileNumberForIdentifier:identifier];
    NSString *filePath = [self filePathForIdentifier:identifier withFileNumber:fileNumber];
    
    if (data == nil || filePath == nil) {
        return;
    }
    
    do {
        NSError *error;
        BOOL success = [data writeToFile:filePath options:NSDataWritingWithoutOverwriting error:&error];
        
        // if race between multiple writers and writeToFile fails because a file already exists, then pick new number and try again
        if (!success && error.code == 0) { // !!!
            filePath = [self filePathForIdentifier:identifier withFileNumber:++fileNumber];
            if (filePath) {
                continue;
            }
        }
        
        if (!success) {
            return;
        }
    } while (0);
    
    [self sendNotificationForMessageWithIdentifier:identifier];
    
}

- (id)messageObjectFromFileWithIdentifier:(NSString *)identifier {
    return [self messageObjectFromFileWithIdentifier:identifier havingFileNumber:NULL delete:YES];
}

- (id)messageObjectFromFileWithIdentifier:(NSString *)identifier havingFileNumber:(NSInteger *)outFileNumber delete:(BOOL)delete {
    if (identifier == nil) {
        return nil;
    }
    
    // first attempt to read from single file created by base class, only if its not present do we read from our subdirectory
    NSData *data;
    NSInteger fileNumber = -1;
    NSString *filePath = [self filePathForIdentifier:identifier];
    BOOL isDir;
    if (filePath != nil && [self.fileManager fileExistsAtPath:filePath isDirectory:&isDir] && !isDir) {
        data = [NSData dataWithContentsOfFile:filePath];
    }
    
    else {
        fileNumber = [self smallestFileNumberForIdentifier:identifier];
        filePath = fileNumber >= 0 ? [self filePathForIdentifier:identifier withFileNumber:fileNumber] : nil;
        
        if (filePath != nil) {
            do {
                NSError *error;
                data = [NSData dataWithContentsOfFile:filePath options:0 error:&error];
                
                // if race between multiple readers and file has already been deleted, then find new smallest number and try again
                if (data == nil && error.code == 0) { // !!!
                    NSInteger updatedFileNumber = [self smallestFileNumberForIdentifier:identifier];
                    filePath = [self filePathForIdentifier:identifier withFileNumber:updatedFileNumber];
                    if (filePath != nil && updatedFileNumber != fileNumber) {
                        fileNumber = updatedFileNumber;
                        continue;
                    }
                }
                
            } while (0);
        }
    }
    
    if (filePath != nil && delete) {
        [self.fileManager removeItemAtPath:filePath error:nil];
    }
    
    if (data == nil || filePath == nil) {
        return nil;
    }
    
    if (outFileNumber) {
        *outFileNumber = fileNumber;
    }
    
    id messageObject = [NSKeyedUnarchiver unarchiveObjectWithData:data];
    
    return messageObject;
}


- (void)didReceiveMessageNotification:(NSNotification *)notification {
    typedef void (^MessageListenerBlock)(id messageObject);
    
    NSDictionary *userInfo = notification.userInfo;
    NSString *identifier = [userInfo valueForKey:@"identifier"];
    NSString *fileNumberString = [userInfo valueForKey:@"number"];
    NSInteger fileNumber = fileNumberString.integerValue;
    
    if (identifier != nil) {
        MessageListenerBlock listenerBlock = [self listenerBlockForIdentifier:identifier];
        
        if (listenerBlock) {
            
            id messageObject;
            
            // if sender using base class and file number not given, delivers the first / only message
            if (fileNumberString == nil) {
                messageObject = [self messageObjectFromFileWithIdentifier:identifier havingFileNumber:&fileNumber delete:NO];
            }
            else {
                NSString *filePath = [self filePathForIdentifier:identifier withFileNumber:fileNumber];
                if (filePath != nil) {
                    NSData *data = [NSData dataWithContentsOfFile:filePath];
                    if (data != nil) {
                        messageObject = [NSKeyedUnarchiver unarchiveObjectWithData:data];
                    }
                }
            }
            
            // if message can't be found, must have been picked up behind out backs so don't even notify
            if (messageObject) {
                listenerBlock(messageObject);
                
                [self clearMessagesForIdentifier:identifier upToFileNumber:fileNumber];
            }
        }
    }
}

@end
