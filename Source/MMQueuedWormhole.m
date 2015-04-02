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

#pragma mark - Private File Operation Methods

- (NSInteger)smallestFileNumberForIdentifier:(NSString *)identifier
{
    NSString *directoryPath = [self messagePassingDirectoryPath];
    NSString *subDirectoryPath = [directoryPath stringByAppendingPathComponent:identifier];
    
    NSInteger smallest = -1;
    NSError *error;
    NSArray *files = [self.fileManager contentsOfDirectoryAtPath:subDirectoryPath error:&error];
    
    for (NSString *filePath in files) {
        NSString *fileName = [filePath lastPathComponent];
        NSString *fileNumberString = [fileName stringByDeletingPathExtension];
        NSInteger fileNumber = fileNumberString.integerValue;
        if (fileNumber >= 0 && (smallest < 0 || fileNumber < smallest)) {
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

- (NSInteger)oneGreaterThanLargestFileNumberForIdentifier:(NSString *)identifier
{
    NSString *directoryPath = [self messagePassingDirectoryPath];
    NSString *subDirectoryPath = [directoryPath stringByAppendingPathComponent:identifier];
    
    NSInteger oneGreater = 0;
    NSError *error;
    NSArray *files = [self.fileManager contentsOfDirectoryAtPath:subDirectoryPath error:&error];
    
    for (NSString *filePath in files) {
        NSString *fileName = [filePath lastPathComponent];
        NSString *fileNumberString = [fileName stringByDeletingPathExtension];
        NSInteger fileNumber = fileNumberString.integerValue;
        if (fileNumber >= oneGreater) {
            oneGreater = fileNumber + 1;
        }
    }
    
    return oneGreater;
}


- (NSString *)filePathForIdentifier:(NSString *)identifier withFileNumber:(NSInteger)fileNumber
{
    if (identifier == nil || identifier.length == 0 || fileNumber < 0) {
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

- (void)clearMessageContentsForIdentifier:(NSString *)identifier {
    if (identifier == nil) {
        return;
    }
    
    // clear the single file created by base class
    [super clearMessageContentsForIdentifier:identifier];
    
    // delete the queue director for this identifier
    NSString *directoryPath = [self messagePassingDirectoryPath];
    NSString *subDirectoryPath = [directoryPath stringByAppendingPathComponent:identifier];
    if (subDirectoryPath != nil) {
        [self.fileManager removeItemAtPath:subDirectoryPath error:NULL];
    }
}


- (NSString *)uniqueFilePathWithinParent:(NSString *)parentPath
{
    return [parentPath stringByAppendingPathComponent:[NSUUID UUID].UUIDString];
}

- (NSData *)atomicallyReadAndDeleteFile:(NSString *)filePath error:(NSError **)errorPtr
{
    // make this atomic by first moving the file to a unique path, then only if that succeeds then read & delete it
    // if 2 processes both enter this method for the same path, one move will win and the other will fail
    if (!filePath) {
        if (errorPtr) {
            errorPtr = nil; // return error = nil for now, don't know what error to use anyway
        }
        return nil;
    }
    
    NSString *uniquePath = [self uniqueFilePathWithinParent:[filePath stringByDeletingLastPathComponent]];
    if (![[NSFileManager defaultManager] moveItemAtPath:filePath toPath:uniquePath error:errorPtr]) {
        return nil;
    }
    
    NSData *data = [NSData dataWithContentsOfFile:uniquePath options:NSDataReadingUncached error:errorPtr];
    [[NSFileManager defaultManager] removeItemAtPath:filePath error:NULL];
    return data;
}

- (BOOL)atomicallyWriteData:(NSData *)data toFile:(NSString *)filePath error:(NSError **)errorPtr
{
    // write atomically by writing the file at a unique path then attempt to move to given location, failing if the move fails
    // if 2 processes both enter this method for the same path, one move will win and the other will fail
    if (!filePath) {
        if (errorPtr) {
            errorPtr = nil; // return error = nil for now, don't know what error to use anyway
        }
        return NO;
    }
    
    NSString *uniquePath = [self uniqueFilePathWithinParent:[filePath stringByDeletingLastPathComponent]];
    if (![data writeToFile:uniquePath options:NSDataWritingAtomic error:errorPtr]) {
        return NO;
    }
    
    if (![[NSFileManager defaultManager] moveItemAtPath:uniquePath toPath:filePath error:errorPtr]) {
        [[NSFileManager defaultManager] removeItemAtPath:uniquePath error:NULL]; // back out by deleting temporary file
        return NO;
    }
    return YES;
}


#pragma mark - Overridden Private File Operation Methods

- (void)writeMessageObject:(id)messageObject toFileWithIdentifier:(NSString *)identifier
{
    [self writeMessageObject:messageObject toFileWithIdentifier:identifier usedFileNumber:NULL];
}

- (BOOL)writeMessageObject:(id)messageObject toFileWithIdentifier:(NSString *)identifier usedFileNumber:(NSInteger *)fileNumberPtr
{
    if (identifier == nil) {
        return NO;
    }
    
    NSData *data = messageObject ? [NSKeyedArchiver archivedDataWithRootObject:messageObject] : [NSData data];
    NSInteger fileNumber = [self oneGreaterThanLargestFileNumberForIdentifier:identifier];
    NSString *filePath = [self filePathForIdentifier:identifier withFileNumber:fileNumber];
    
    if (data == nil || filePath == nil) {
        return NO;
    }
    
    NSString *parentPath = [filePath stringByDeletingLastPathComponent];
    [[NSFileManager defaultManager] createDirectoryAtPath:parentPath withIntermediateDirectories:YES attributes:nil error:NULL];
    
    while (1) {
        NSError *error;
        BOOL success = [self atomicallyWriteData:data toFile:filePath error:&error];
        if (success) {
            break;
        }
        
        // if race between multiple writers and writeToFile fails because a file already exists, then pick new number and try again
        if (error.code == 0) { // !!!
            filePath = [self filePathForIdentifier:identifier withFileNumber:++fileNumber];
            if (filePath != nil) { // only ever expect it to be nil if fileNumber wraps around to become negative
                continue;
            }
        }
        
        return NO; // any other case of !success
    }
    
    [self sendNotificationForMessageWithIdentifier:identifier];
    
    if (fileNumberPtr) {
        *fileNumberPtr = fileNumber;
    }
    return YES;
}


- (id)messageObjectFromFileWithIdentifier:(NSString *)identifier
{
    return [self messageObjectFromFileWithIdentifier:identifier notGreaterThanFileNumber:-1];
}

- (id)messageObjectFromFileWithIdentifier:(NSString *)identifier notGreaterThanFileNumber:(NSInteger)limitFileNumber
{
    if (identifier == nil) {
        return nil;
    }
    
    // first attempt to read from single file created by base class, only if its not present do we read from our subdirectory
    NSData *data = nil;
    NSString *filePath = [self filePathForIdentifier:identifier];
    BOOL isDir;
    if (filePath != nil && [self.fileManager fileExistsAtPath:filePath isDirectory:&isDir] && !isDir) {
        data = [self atomicallyReadAndDeleteFile:filePath error:NULL];
        
        if (data == nil) {
            return nil;
        }
    }
    
    else {
        NSInteger fileNumber = [self smallestFileNumberForIdentifier:identifier];
        filePath = [self filePathForIdentifier:identifier withFileNumber:fileNumber];
        
        if (filePath == nil) {
            return nil;
        }
        
        while (limitFileNumber < 0 || fileNumber <= limitFileNumber) {
            NSError *error;
            data = [self atomicallyReadAndDeleteFile:filePath error:&error];
            if (data != nil) {
                break;
            }
            
            // if race between multiple readers and file has already been deleted, then find new smallest number and try again
            if (error.code == 260) {
                NSInteger updatedFileNumber = [self smallestFileNumberForIdentifier:identifier];
                if (updatedFileNumber != fileNumber) {
                    fileNumber = updatedFileNumber;
                    filePath = [self filePathForIdentifier:identifier withFileNumber:updatedFileNumber];
                    if (filePath != nil) { // don't expect it to be nil
                        continue;
                    }
                }
            }
            
            return nil; // any other case of !data
        }
    }
    
    id messageObject = [NSKeyedUnarchiver unarchiveObjectWithData:data];
    
    return messageObject;
}


#pragma mark - Private Notification Methods

- (void)didReceiveMessageNotification:(NSNotification *)notification
{
    typedef void (^MessageListenerBlock)(id messageObject);
    
    NSDictionary *userInfo = notification.userInfo;
    NSString *identifier = [userInfo valueForKey:@"identifier"];
    NSString *fileNumberString = [userInfo valueForKey:@"number"];
    NSInteger fileNumber = fileNumberString.integerValue;
    
    if (identifier != nil) {
        MessageListenerBlock listenerBlock = [self listenerBlockForIdentifier:identifier];
        
        if (listenerBlock) {
            
            // if sender using base class and file number not given, delivers the first message only
            // otherwise deliver all messages up to this file number
            if (fileNumberString == nil) {
                id messageObject = [self messageObjectFromFileWithIdentifier:identifier notGreaterThanFileNumber:-1];
                
                listenerBlock(messageObject);
            }
            else {
                while (1) {
                    id messageObject = [self messageObjectFromFileWithIdentifier:identifier notGreaterThanFileNumber:fileNumber];
                    if (!messageObject) {
                        break;
                    }
                    
                    listenerBlock(messageObject);
                }
            }
            
        }
        
    }
}


#pragma mark - Public Interface Methods

- (void)listenForMessageWithIdentifier:(NSString *)identifier listener:(void (^)(id messageObject))listener
{
    [super listenForMessageWithIdentifier:identifier listener:listener];
    
    // immediately call listener for any existing queued messages
    NSInteger limitFileNumber = [self largestFileNumberForIdentifier:identifier];
    
    while (1) {
        id messageObject = [self messageObjectFromFileWithIdentifier:identifier notGreaterThanFileNumber:limitFileNumber];
        if (!messageObject) {
            break;
        }
        
        listener(messageObject);
    }
}

@end
