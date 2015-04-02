//
//  MMQueuedWormholeTests.m
//  MMWormhole
//
//  Created by Pierre Houston on 2015-04-01.
//  Copyright (c) 2015 Conrad Stoll. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <XCTest/XCTest.h>

#import "MMQueuedWormhole.h"

@interface MMWormhole (TextExtension)

- (NSString *)messagePassingDirectoryPath;
- (NSString *)filePathForIdentifier:(NSString *)identifier;
- (void)writeMessageObject:(id)messageObject toFileWithIdentifier:(NSString *)identifier;
- (id)messageObjectFromFileWithIdentifier:(NSString *)identifier;
- (void)deleteFileForIdentifier:(NSString *)identifier;
- (id)listenerBlockForIdentifier:(NSString *)identifier;

@end

@interface MMQueuedWormhole (TextExtension)

- (NSInteger)smallestFileNumberForIdentifier:(NSString *)identifier;
- (NSInteger)largestFileNumberForIdentifier:(NSString *)identifier;
- (NSInteger)oneGreaterThanLargestFileNumberForIdentifier:(NSString *)identifier;
- (NSString *)filePathForIdentifier:(NSString *)identifier withFileNumber:(NSInteger)fileNumber;
- (NSString *)uniqueFilePathWithinParent:(NSString *)parentPath;
- (NSData *)atomicallyReadAndDeleteFile:(NSString *)filePath error:(NSError **)errorPtr;
- (BOOL)atomicallyWriteData:(NSData *)data toFile:(NSString *)filePath error:(NSError **)errorPtr;
- (BOOL)writeMessageObject:(id)messageObject toFileWithIdentifier:(NSString *)identifier usedFileNumber:(NSInteger *)fileNumberPtr;
- (id)messageObjectFromFileWithIdentifier:(NSString *)identifier notGreaterThanFileNumber:(NSInteger)limitFileNumber;

@end

@interface NSArray (ArrayByRemovingLastObject)
- (NSArray *)arrayByRemovingLastObject;
@end
@implementation NSArray (ArrayByRemovingLastObject)
- (NSArray *)arrayByRemovingLastObject {
    NSMutableArray *subArray = self.mutableCopy;
    [subArray removeLastObject];
    return subArray;
}
@end

//static NSString * const applicationGroupIdentifier = @"group.com.mutualmobile.wormhole";
static NSString * const applicationGroupIdentifier = @"group.com.room1337.mmwormhole";

@interface MMQueuedWormholeTests : XCTestCase

@end

@implementation MMQueuedWormholeTests

- (void)setUp {
    [super setUp];
}

- (void)tearDown {
    [super tearDown];
    
//    MMQueuedWormhole *wormhole = [[MMQueuedWormhole alloc] initWithApplicationGroupIdentifier:applicationGroupIdentifier
//                                                                            optionalDirectory:@"testDirectory"];
//    [wormhole clearAllMessageContents];
}

// TODO: add tests for:
// smallestFileNumberForIdentifier:, largestFileNumberForIdentifier:, oneGreaterThanLargestFileNumberForIdentifier:
// atomicallyReadAndDeleteFile:error:, atomicallyWriteData:toFile:error:

// many of these are essentially copied from the MMWormhole tests, those methods are indented

    - (void)testMessagePassingDirectory {
        MMQueuedWormhole *wormhole = [[MMQueuedWormhole alloc] initWithApplicationGroupIdentifier:applicationGroupIdentifier
                                                                                optionalDirectory:@"testDirectory"];
        NSString *messagePassingDirectoryPath = [wormhole messagePassingDirectoryPath];
        
        NSString *lastComponent = [[messagePassingDirectoryPath pathComponents] lastObject];
        
        XCTAssert([lastComponent isEqualToString:@"testDirectory"], @"Message Passing Directory path should contain optional directory.");
    }

    - (void)testFilePathForIdentifier {
        MMQueuedWormhole *wormhole = [[MMQueuedWormhole alloc] initWithApplicationGroupIdentifier:applicationGroupIdentifier
                                                                                optionalDirectory:@"testDirectory"];
        NSString *filePathForIdentifier = [wormhole filePathForIdentifier:@"testIdentifier"];
        
        NSString *lastComponent = [[filePathForIdentifier pathComponents] lastObject];
        
        XCTAssert([lastComponent isEqualToString:@"testIdentifier.archive"], @"File Path Identifier should equal the passed identifier with the .archive extension.");
    }

    - (void)testFilePathForNilIdentifier {
        MMQueuedWormhole *wormhole = [[MMQueuedWormhole alloc] initWithApplicationGroupIdentifier:applicationGroupIdentifier
                                                                                optionalDirectory:@"testDirectory"];
        NSString *filePathForIdentifier = [wormhole filePathForIdentifier:nil];
        
        NSString *lastComponent = [[filePathForIdentifier pathComponents] lastObject];
        
        XCTAssertNil(lastComponent, @"File Path Identifier should be nil if no identifier is provided.");
    }

    - (void)testPassingMessageWithNilIdentifier {
        MMQueuedWormhole *wormhole = [[MMQueuedWormhole alloc] initWithApplicationGroupIdentifier:applicationGroupIdentifier
                                                                                optionalDirectory:@"testDirectory"];
        
        [wormhole passMessageObject:@{} identifier:nil];
        
        XCTAssertTrue(YES, @"Message Passing should not crash for nil message identifiers.");
    }

- (void)testFilePathForIdentifierAndNumber {
    MMQueuedWormhole *wormhole = [[MMQueuedWormhole alloc] initWithApplicationGroupIdentifier:applicationGroupIdentifier
                                                                            optionalDirectory:@"testDirectory"];
    NSString *filePathForIdentifierAndNumber = [wormhole filePathForIdentifier:@"testIdentifier" withFileNumber:12];
    
    NSString *lastComponent = [filePathForIdentifierAndNumber pathComponents].lastObject;
    //NSString *secondToLastComponent = [[filePathForIdentifierAndNumber pathComponents] secondToLastObject];
    NSString *secondToLastComponent = [[filePathForIdentifierAndNumber pathComponents] arrayByRemovingLastObject].lastObject;
    
    XCTAssert([secondToLastComponent isEqualToString:@"testIdentifier"], @"File Path Identifier parent directory should equal the passed identifier.");
    XCTAssert([lastComponent isEqualToString:@"12.archive"], @"File Path Identifier should equal the file number with the .archive extension.");
}

- (void)testFilePathForNilIdentifierAndNumber {
    MMQueuedWormhole *wormhole = [[MMQueuedWormhole alloc] initWithApplicationGroupIdentifier:applicationGroupIdentifier
                                                                            optionalDirectory:@"testDirectory"];
    NSString *filePathForIdentifierAndNumber = [wormhole filePathForIdentifier:nil withFileNumber:6];
    
    XCTAssertNil(filePathForIdentifierAndNumber, @"File Path Identifier should be nil if no identifier is provided.");
}

- (void)testFilePathForIdentifierAndNegativeNumber {
    MMQueuedWormhole *wormhole = [[MMQueuedWormhole alloc] initWithApplicationGroupIdentifier:applicationGroupIdentifier
                                                                            optionalDirectory:@"testDirectory"];
    NSString *filePathForIdentifierAndNumber = [wormhole filePathForIdentifier:@"testIdentifier" withFileNumber:-33];
    
    XCTAssertNil(filePathForIdentifierAndNumber, @"File Path Identifier should be nil if file number is negative.");
}

- (void)testValidMessagePassing {
    MMQueuedWormhole *wormhole = [[MMQueuedWormhole alloc] initWithApplicationGroupIdentifier:applicationGroupIdentifier
                                                                            optionalDirectory:@"testDirectory"];
    
    [wormhole clearMessageContentsForIdentifier:@"testIdentifier"];
    
    id messageObject = [wormhole messageObjectFromFileWithIdentifier:@"testIdentifier"];
    
    XCTAssertNil(messageObject, @"Message object should be nil after deleting file.");
    
    NSString *filePathForIdentifierAndDummyNumber = [wormhole filePathForIdentifier:@"testIdentifier" withFileNumber:0];
    NSString *filePathForParent = [filePathForIdentifierAndDummyNumber stringByDeletingLastPathComponent];
    
    [wormhole passMessageObject:@{} identifier:@"testIdentifier"];
    
    NSArray *directoryContents = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:filePathForParent error:NULL];
    
    XCTAssertNotNil(directoryContents, @"Getting message directory contents should not fail after passing a valid message.");
    XCTAssert(directoryContents.count > 0, @"Message directory should not be empty after passing a valid message.");
    XCTAssert(directoryContents.count == 1, @"Fresh message directory should have 1 file after passing a valid message.");
    
    NSData *data = [NSData dataWithContentsOfFile:[filePathForParent stringByAppendingPathComponent:directoryContents.firstObject]];
    
    XCTAssertNotNil(data, @"Message contents should not be nil after passing a valid message.");
}

- (void)testFileWriting {
    MMQueuedWormhole *wormhole = [[MMQueuedWormhole alloc] initWithApplicationGroupIdentifier:applicationGroupIdentifier
                                                                            optionalDirectory:@"testDirectory"];
    
    [wormhole clearMessageContentsForIdentifier:@"testIdentifier"];
    
    id messageObject = [wormhole messageObjectFromFileWithIdentifier:@"testIdentifier"];
    
    XCTAssertNil(messageObject, @"Message object should be nil after deleting file.");
    
    NSInteger fileNumber;
    BOOL written = [wormhole writeMessageObject:@{} toFileWithIdentifier:@"testIdentifier" usedFileNumber:&fileNumber];
    
    XCTAssert(written, @"Passing a valid message should succeed.");
    NSString *filePathForIdentifierAndNumber = [wormhole filePathForIdentifier:@"testIdentifier" withFileNumber:fileNumber];
    
    NSData *data = [NSData dataWithContentsOfFile:filePathForIdentifierAndNumber];
    
    XCTAssertNotNil(data, @"Message contents should not be nil after writing a valid message to disk.");
}

- (void)testClearingIndividualMessage {
    MMQueuedWormhole *wormhole = [[MMQueuedWormhole alloc] initWithApplicationGroupIdentifier:applicationGroupIdentifier
                                                                            optionalDirectory:@"testDirectory"];
    
    [wormhole passMessageObject:@{} identifier:@"testIdentifier"];
    
    id messageObject = [wormhole messageObjectFromFileWithIdentifier:@"testIdentifier"];
    
    XCTAssertNotNil(messageObject, @"Message contents should not be nil after passing a valid message.");
    
    [wormhole clearMessageContentsForIdentifier:@"testIdentifier"];
    
    NSString *filePathForIdentifierAndDummyNumber = [wormhole filePathForIdentifier:@"testIdentifier" withFileNumber:0];
    NSString *filePathForParent = [filePathForIdentifierAndDummyNumber stringByDeletingLastPathComponent];
    
    NSArray *directoryContents = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:filePathForParent error:NULL];
    
    XCTAssertNil(directoryContents, @"Getting message directory contents should fail after deleting messages for an identifer.");
    
    id deletedMessageObject = [wormhole messageObjectFromFileWithIdentifier:@"testIdentifier"];
    
    XCTAssertNil(deletedMessageObject, @"Message object should be nil after deleting message.");
}

    - (void)testClearingAllMessages {
        MMQueuedWormhole *wormhole = [[MMQueuedWormhole alloc] initWithApplicationGroupIdentifier:applicationGroupIdentifier
                                                                                optionalDirectory:@"testDirectory"];
        
        [wormhole passMessageObject:@{} identifier:@"testIdentifier1"];
        [wormhole passMessageObject:@{} identifier:@"testIdentifier2"];
        [wormhole passMessageObject:@{} identifier:@"testIdentifier3"];
        
        [wormhole clearAllMessageContents];
        
        id deletedMessageObject1 = [wormhole messageObjectFromFileWithIdentifier:@"testIdentifier1"];
        id deletedMessageObject2 = [wormhole messageObjectFromFileWithIdentifier:@"testIdentifier2"];
        id deletedMessageObject3 = [wormhole messageObjectFromFileWithIdentifier:@"testIdentifier3"];
        
        XCTAssertNil(deletedMessageObject1, @"Message object should be nil after deleting message.");
        XCTAssertNil(deletedMessageObject2, @"Message object should be nil after deleting message.");
        XCTAssertNil(deletedMessageObject3, @"Message object should be nil after deleting message.");
    }

    - (void)testMessageListening {
        MMQueuedWormhole *wormhole = [[MMQueuedWormhole alloc] initWithApplicationGroupIdentifier:applicationGroupIdentifier
                                                                                optionalDirectory:@"testDirectory"];
        
        XCTestExpectation *expectation = [self expectationWithDescription:@"Listener should hear something"];
        
        [wormhole listenForMessageWithIdentifier:@"testIdentifier" listener:^(id messageObject) {
            XCTAssertNotNil(messageObject, @"Valid message object should not be nil.");
            
            [expectation fulfill];
        }];
        
        [wormhole passMessageObject:@{} identifier:@"testIdentifier"];
        
        // Simulate a fake notification since Darwin notifications aren't delivered to the sender (don't understand why this is needed by the base class' tests)
        //
        //[[NSNotificationCenter defaultCenter] postNotificationName:@"MMWormholeNotificationName"
        //                                                    object:nil
        //                                                  userInfo:@{@"identifier" : @"testIdentifier"}];
        
        [self waitForExpectationsWithTimeout:2 handler:nil];
    }

- (void)testMessageQueuedListening {
    MMQueuedWormhole *wormhole = [[MMQueuedWormhole alloc] initWithApplicationGroupIdentifier:applicationGroupIdentifier
                                                                            optionalDirectory:@"testDirectory"];
    
    [wormhole clearMessageContentsForIdentifier:@"testIdentifier"];
    
    [wormhole passMessageObject:@{} identifier:@"testIdentifier"];
    [wormhole passMessageObject:@{} identifier:@"testIdentifier"];
    
    // Simulate a fake notification since Darwin notifications aren't delivered to the sender (don't understand why this is needed by the base class' tests)
    //
    //[[NSNotificationCenter defaultCenter] postNotificationName:@"MMWormholeNotificationName"
    //                                                    object:nil
    //                                                  userInfo:@{@"identifier" : @"testIdentifier"}];
    //
    //[[NSNotificationCenter defaultCenter] postNotificationName:@"MMWormholeNotificationName"
    //                                                    object:nil
    //                                                  userInfo:@{@"identifier" : @"testIdentifier"}];
    
    __block XCTestExpectation *expectation1 = [self expectationWithDescription:@"Listener should hear something once"];
    __block XCTestExpectation *expectation2 = [self expectationWithDescription:@"Listener should hear something twice"];
    
    [wormhole listenForMessageWithIdentifier:@"testIdentifier" listener:^(id messageObject) {
        XCTAssertNotNil(messageObject, @"Valid message object should not be nil.");
        
        if (expectation1) {
            [expectation1 fulfill];
            expectation1 = nil;
        }
        else if (expectation2) {
            [expectation2 fulfill];
            expectation2 = nil;
        }
        else {
            XCTAssertTrue(NO, @"Listener should not get called more than the number of posted notifications.");
        }
    }];
    
    [self waitForExpectationsWithTimeout:2 handler:nil];
}

    - (void)testStopMessageListening {
        MMQueuedWormhole *wormhole = [[MMQueuedWormhole alloc] initWithApplicationGroupIdentifier:applicationGroupIdentifier
                                                                                optionalDirectory:@"testDirectory"];
        
        XCTestExpectation *expectation = [self expectationWithDescription:@"Listener should hear something"];
        
        [wormhole listenForMessageWithIdentifier:@"testIdentifier" listener:^(id messageObject) {
            XCTAssertNotNil(messageObject, @"Valid message object should not be nil.");
            
            [expectation fulfill];
        }];
        
        [wormhole passMessageObject:@{} identifier:@"testIdentifier"];
        
        // Simulate a fake notification since Darwin notifications aren't delivered to the sender (don't understand why this is needed by the base class' tests)
        //
        //[[NSNotificationCenter defaultCenter] postNotificationName:@"MMWormholeNotificationName"
        //                                                    object:nil
        //                                                  userInfo:@{@"identifier" : @"testIdentifier"}];
        
        [self waitForExpectationsWithTimeout:2 handler:^(NSError *error) {
            id listenerBlock = [wormhole listenerBlockForIdentifier:@"testIdentifier"];
            
            XCTAssertNotNil(listenerBlock, @"A valid listener block should not be nil.");
            
            [wormhole stopListeningForMessageWithIdentifier:@"testIdentifier"];
            
            id deletedListenerBlock = [wormhole listenerBlockForIdentifier:@"testIdentifier"];
            
            XCTAssertNil(deletedListenerBlock, @"The listener block should be nil after you stop listening.");
        }];
    }

    - (void)testMessagePassingPerformance {
        [self measureBlock:^{
            MMQueuedWormhole *wormhole = [[MMQueuedWormhole alloc] initWithApplicationGroupIdentifier:applicationGroupIdentifier
                                                                                    optionalDirectory:@"testDirectory"];
            
            [wormhole passMessageObject:[self performanceSampleJSONObject] identifier:@"testPerformance"];
        }];
    }

- (id)performanceSampleJSONObject {
    return @[@{@"key1" : @"string1", @"key2" : @(1), @"key3" : @{@"innerKey1" : @"innerString1", @"innerKey2" : @(1)}},
             @{@"key1" : @"string1", @"key2" : @(1), @"key3" : @{@"innerKey1" : @"innerString1", @"innerKey2" : @(1)}},
             @{@"key1" : @"string1", @"key2" : @(1), @"key3" : @{@"innerKey1" : @"innerString1", @"innerKey2" : @(1)}},
             @{@"key1" : @"string1", @"key2" : @(1), @"key3" : @{@"innerKey1" : @"innerString1", @"innerKey2" : @(1)}},
             @{@"key1" : @"string1", @"key2" : @(1), @"key3" : @{@"innerKey1" : @"innerString1", @"innerKey2" : @(1)}},
             @{@"key1" : @"string1", @"key2" : @(1), @"key3" : @{@"innerKey1" : @"innerString1", @"innerKey2" : @(1)}},
             @{@"key1" : @"string1", @"key2" : @(1), @"key3" : @{@"innerKey1" : @"innerString1", @"innerKey2" : @(1)}}
             ];
}

@end
