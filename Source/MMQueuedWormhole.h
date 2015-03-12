//
//  MMQueuedWormhole.h
//  MMWormhole
//
//  Created by Pierre Houston on 2015-03-11.
//  Copyright (c) 2015 Conrad Stoll. All rights reserved.
//

#import "MMWormhole.h"

/**
 This subclass of MMWormhole ensures every message sent to the wormhole will be received in order
 by the recipient even while its not listening. The only changes are:
   1. The messageWithIdentifier: method can be called repeatedly to get each of the sent messages,
      and it will return nil when there are none remaining. This constrast with the base class
      which only saves the most recent message and returns it over and over on repeated calls.
   2. When the listener block is called with a message, there may be messages preceeding it that
      haven't been received yet. However when the listener block returns it and all the
      preceeding messages will be deleted.
      If the listener doesn't want to miss any messages, then it must make calls to
      messageWithIdentifier: itself to receive them. The passed-in message will be amongst those
      messages returned (in fact, the last of them).
[ OR:
      a. If the listener desires to handle this message out of order then it can do so. After the
         listener blocks returns, only the passed-in message will be removed.
      b. If the listener desires to handle messages exclusively in order, then it can make
         calls to messageWithIdentifier: to do so. The passed-in message will be amongst those
         messages returned (presumably at the end). But note, if the listener doesn't make enough
         calls to messageWithIdentifier: to receive every message, when it returns the message
         that was passed in will still be removed. ]
 */
@interface MMQueuedWormhole : MMWormhole

@end
