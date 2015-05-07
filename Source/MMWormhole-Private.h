//
//  MMWormhole-Private.h
//  MMWormhole
//
//  Created by Pierre Houston on 2015-03-11.
//  Copyright (c) 2015 Conrad Stoll. All rights reserved.
//

#import "MMWormhole.h"

@interface MMWormhole (Private)

@property (nonatomic, strong, readonly) NSFileManager *fileManager;

- (NSString *)messagePassingDirectoryPath;
- (NSString *)filePathForIdentifier:(NSString *)identifier;
//- (void)registerForNotificationsWithIdentifier:(NSString *)identifier;
- (void)sendNotificationForMessageWithIdentifier:(NSString *)identifier;
- (void)didReceiveMessageNotification:(NSNotification *)notification;
- (id)listenerBlockForIdentifier:(NSString *)identifier;

@end
