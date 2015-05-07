//
//  ViewController.m
//  MMWormhole
//
//  Created by Conrad Stoll on 12/6/14.
//  Copyright (c) 2014 Conrad Stoll. All rights reserved.
//

#import "ViewController.h"

#import "MMWormhole.h"
#import "MMQueuedWormhole.h"

@interface ViewController ()

@property (nonatomic, weak) IBOutlet UILabel *numberLabel;
@property (nonatomic, weak) IBOutlet UISegmentedControl *segmentedControl;

@property (nonatomic, strong) MMWormhole *wormhole;

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];

    // Initialize the wormhole
#if 0
    self.wormhole = [[MMWormhole alloc] initWithApplicationGroupIdentifier:@"group.com.room1337.mmqueuedwormhole"
                                                         optionalDirectory:@"wormhole"];
    
    // Obtain an initial message from the wormhole
    id messageObject = [self.wormhole messageWithIdentifier:@"button"];
    NSNumber *number = [messageObject valueForKey:@"buttonNumber"];
    
    self.numberLabel.text = [number stringValue];
    
    // Become a listener for changes to the wormhole for the button message
    [self.wormhole listenForMessageWithIdentifier:@"button" listener:^(id messageObject) {
        // The number is identified with the buttonNumber key in the message object
        NSNumber *number = [messageObject valueForKey:@"buttonNumber"];
        self.numberLabel.text = [number stringValue];
    }];
    
#elif 0
    MMQueuedWormhole *queuedWormhole = [[MMQueuedWormhole alloc] initWithApplicationGroupIdentifier:@"group.com.room1337.mmqueuedwormhole"
                                                                                  optionalDirectory:@"wormhole"];
    self.wormhole = queuedWormhole;
    
    // Become a listener for any queued or future button messages to the wormhole
    [self.wormhole listenForMessageWithIdentifier:@"button" listener:^(id messageObject) {
        // The number is identified with the buttonNumber key in the message object
        NSNumber *number = [messageObject valueForKey:@"buttonNumber"];
        
        NSString *labelText = (self.numberLabel.text.length > 0) ? [self.numberLabel.text stringByAppendingString:@" "]: @"";
        self.numberLabel.text = [labelText stringByAppendingString:number ? [number stringValue] : @"?"];
    }];
    
#else
    MMQueuedWormhole *queuedWormhole = [[MMQueuedWormhole alloc] initWithApplicationGroupIdentifier:@"group.com.room1337.mmqueuedwormhole"
                                                                                  optionalDirectory:@"wormhole"];
    self.wormhole = queuedWormhole;
    
    // Become a listener for any queued or future button messages to the wormhole
    [queuedWormhole listenForMessagesWithIdentifier:@"button" listener:^(NSArray *messageObjects) {
        for (id messageObject in messageObjects) {
            // The number is identified with the buttonNumber key in the message object
            NSNumber *number = [messageObject valueForKey:@"buttonNumber"];
            
            NSString *labelText = (self.numberLabel.text.length > 0) ? [self.numberLabel.text stringByAppendingString:@" "]: @"";
            self.numberLabel.text = [labelText stringByAppendingString:number ? [number stringValue] : @"?"];
        }
    }];
#endif
    
    [self segmentedControlValueDidChange:self.segmentedControl];
}

- (IBAction)segmentedControlValueDidChange:(UISegmentedControl *)segmentedControl {
    NSString *title = [segmentedControl titleForSegmentAtIndex:segmentedControl.selectedSegmentIndex];
    
    // Pass a message for the selection identifier. The message itself is a NSCoding compliant object
    // with a single value and key called selectionString.
    [self.wormhole passMessageObject:@{@"selectionString" : title} identifier:@"selection"];
    
    // test -- also send a button message when pressing 3rd segment
    if (segmentedControl.selectedSegmentIndex == 2)
        [self.wormhole passMessageObject:@{@"buttonNumber" : @99} identifier:@"button"];
}

@end
