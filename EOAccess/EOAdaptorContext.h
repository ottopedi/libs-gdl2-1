/* -*-objc-*-
   EOAdaptorContext.h

   Copyright (C) 2000,2002,2003,2004,2005 Free Software Foundation, Inc.

   Author: Mirko Viviani <mirko.viviani@gmail.com>
   Date: February 2000

   This file is part of the GNUstep Database Library.

   This library is free software; you can redistribute it and/or
   modify it under the terms of the GNU Library General Public
   License as published by the Free Software Foundation; either
   version 3 of the License, or (at your option) any later version.

   This library is distributed in the hope that it will be useful,
   but WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
   Library General Public License for more details.

   You should have received a copy of the GNU Library General Public
   License along with this library; see the file COPYING.LIB.
   If not, write to the Free Software Foundation,
   51 Franklin Street, Fifth Floor, Boston, MA 02110-1301, USA.
*/

#ifndef __EOAdaptorContext_h__
#define __EOAdaptorContext_h__

#ifdef GNUSTEP
#include <Foundation/NSString.h>
#else
#include <Foundation/Foundation.h>
#endif

#include <EOAccess/EODefines.h>


@class NSMutableArray;
@class NSString;

@class EOAdaptor;
@class EOAdaptorChannel;


typedef enum { 
    EODelegateRejects, 
    EODelegateApproves, 
    EODelegateOverrides
} EODelegateResponse;

/* The EOAdaptorContext class could be overriden for a concrete database
   adaptor. You have to override only those methods marked in this header
   with 'override'.
*/

@interface EOAdaptorContext : NSObject
{
    EOAdaptor *_adaptor;
    NSMutableArray *_channels;	// values with channels
    id _delegate;	// not retained

    unsigned short _transactionNestingLevel;
    BOOL _debug;

    /* Flags used to check if the delegate responds to several messages */
    struct {
        unsigned shouldConnect:1;
        unsigned shouldBegin:1;
        unsigned didBegin:1;
        unsigned shouldCommit:1;
        unsigned didCommit:1;
        unsigned shouldRollback:1;
        unsigned didRollback:1;
    } _delegateRespondsTo;
}

+ (EOAdaptorContext *)adaptorContextWithAdaptor: (EOAdaptor *)adaptor;

- (id)initWithAdaptor: (EOAdaptor *)adaptor;

- (EOAdaptor *)adaptor;

- (EOAdaptorChannel *)createAdaptorChannel;	// override

- (NSArray *)channels;
- (BOOL)hasOpenChannels;
- (BOOL)hasBusyChannels;

- (id)delegate;
- (void)setDelegate: (id)delegate;

- (void)handleDroppedConnection;

@end


@interface EOAdaptorContext (EOTransactions)

- (void)beginTransaction;
- (void)commitTransaction;
- (void)rollbackTransaction;

- (void)transactionDidBegin;
- (void)transactionDidCommit;
- (void)transactionDidRollback;

- (BOOL)hasOpenTransaction;

- (BOOL)canNestTransactions;			// override
- (unsigned)transactionNestingLevel; 

+ (void)setDebugEnabledDefault: (BOOL)flag;
+ (BOOL)debugEnabledDefault;
- (void)setDebugEnabled: (BOOL)debugEnabled;
- (BOOL)isDebugEnabled;

@end /* EOAdaptorContext (EOTransactions) */


@interface EOAdaptorContext(Private)

- (void)_channelDidInit: (id)channel;
- (void)_channelWillDealloc: (id)channel;

@end


@interface NSObject (EOAdaptorContextDelegation)

- (BOOL)adaptorContextShouldConnect: (id)context;
- (BOOL)adaptorContextShouldBegin: (id)context;
- (void)adaptorContextDidBegin: (id)context;
- (BOOL)adaptorContextShouldCommit: (id)context;
- (void)adaptorContextDidCommit: (id)context;
- (BOOL)adaptorContextShouldRollback: (id)context;
- (void)adaptorContextDidRollback: (id)context;

@end /* NSObject(EOAdaptorContextDelegate) */

GDL2ACCESS_EXPORT NSString *EOAdaptorContextBeginTransactionNotification;
GDL2ACCESS_EXPORT NSString *EOAdaptorContextCommitTransactionNotification;
GDL2ACCESS_EXPORT NSString *EOAdaptorContextRollbackTransactionNotification;

#endif /* __EOAdaptorContext_h__*/
