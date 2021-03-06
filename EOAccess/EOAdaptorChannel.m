/** 
   EOAdaptorChannel.m <title>EOAdaptorChannel</title>

   Copyright (C) 2000,2002,2003,2004,2005 Free Software Foundation, Inc.

   Author: Mirko Viviani <mirko.viviani@gmail.com>
   Date: February 2000

   $Revision$
   $Date$

   <abstract></abstract>

   This file is part of the GNUstep Database Library.

   <license>
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
   </license>
**/

#include "config.h"

#ifdef GNUSTEP
#include <Foundation/NSString.h>
#include <Foundation/NSArray.h>
#include <Foundation/NSDictionary.h>
#include <Foundation/NSEnumerator.h>
#include <Foundation/NSException.h>
#include <Foundation/NSZone.h>
#include <Foundation/NSObjCRuntime.h>
#include <Foundation/NSDebug.h>
#else
#include <Foundation/Foundation.h>
#endif

#ifndef GNUSTEP
#include <GNUstepBase/GNUstep.h>
#include <GNUstepBase/NSDebug+GNUstepBase.h>
#include <GNUstepBase/NSObject+GNUstepBase.h>
#endif

#include <EOControl/EOMutableKnownKeyDictionary.h>
#include <EOControl/EOFetchSpecification.h>
#include <EOControl/EONSAddOns.h>
#include <EOControl/EODebug.h>

#include <EOAccess/EOEntity.h>
#include <EOAccess/EOAttribute.h>
#include <EOAccess/EOAdaptor.h>
#include <EOAccess/EOAdaptorContext.h>
#include <EOAccess/EOAdaptorChannel.h>
#include <EOAccess/EOSQLExpression.h>
#include <EOAccess/EODatabaseOperation.h>

#include "EOPrivate.h"
#include "EOEntityPriv.h"


NSString *EOAdaptorOperationsKey = @"EOAdaptorOperationsKey";
NSString *EOFailedAdaptorOperationKey = @"EOFailedAdaptorOperationKey";
NSString *EOAdaptorFailureKey = @"EOAdaptorFailureKey";
NSString *EOAdaptorOptimisticLockingFailure = @"EOAdaptorOptimisticLockingFailure";


@implementation EOAdaptorChannel

+ (EOAdaptorChannel *)adaptorChannelWithAdaptorContext: (EOAdaptorContext *)adaptorContext
{
  return [[[self alloc] initWithAdaptorContext: adaptorContext] autorelease];
}

- (id) initWithAdaptorContext: (EOAdaptorContext *)adaptorContext
{
  if ((self = [super init]))
    {
      ASSIGN(_context, adaptorContext);
      [_context _channelDidInit: self]; //TODO it's _registerAdaptorChannel:
    }

  return self;
}

- (void)dealloc
{
  [_context _channelWillDealloc: self];
  DESTROY(_context);

  [super dealloc];
}

- (void)openChannel
{
  [self subclassResponsibility: _cmd];
}

- (void)closeChannel
{
  [self subclassResponsibility: _cmd];
}

- (void)insertRow: (NSDictionary *)row
        forEntity: (EOEntity *)entity
{
  [self subclassResponsibility: _cmd];
}

- (void)updateValues: (NSDictionary *)values
inRowDescribedByQualifier: (EOQualifier *)qualifier
	      entity: (EOEntity *)entity
{
  NSUInteger rows;

  rows = [self updateValues: values
	       inRowsDescribedByQualifier: qualifier
	       entity: entity];

  if(rows != 1)
    [NSException raise: NSInvalidArgumentException
                 format: @"%@ -- %@ 0x%p: updated %"PRIuPTR" rows",
                 NSStringFromSelector(_cmd),
                 NSStringFromClass([self class]),
                 self,
                 rows];
}

- (NSUInteger) updateValues: (NSDictionary *)values
 inRowsDescribedByQualifier: (EOQualifier *)qualifier
                     entity: (EOEntity *)entity
{
  [self subclassResponsibility: _cmd];
  return 0;
}

- (void)deleteRowDescribedByQualifier: (EOQualifier *)qualifier
			       entity: (EOEntity *)entity
{
  NSUInteger rows = 0;

  rows = [self deleteRowsDescribedByQualifier: qualifier
               entity: entity];

  if (rows != 1)
    [NSException raise: NSInvalidArgumentException
                 format: @"%@ -- %@ 0x%p: deleted %"PRIuPTR" rows",
                 NSStringFromSelector(_cmd),
                 NSStringFromClass([self class]), 
                 self,
                 rows];
}

- (NSUInteger) deleteRowsDescribedByQualifier: (EOQualifier *)qualifier
                                      entity: (EOEntity *)entity
{
  [self subclassResponsibility: _cmd];
  return 0;
}

- (void)selectAttributes: (NSArray *)attributes
      fetchSpecification: (EOFetchSpecification *)fetchSpecification
                    lock: (BOOL)flag
                  entity: (EOEntity *)entity
{
  [self subclassResponsibility: _cmd];
}

- (void)lockRowComparingAttributes: (NSArray *)attrs
                            entity: (EOEntity *)entity
                         qualifier: (EOQualifier *)qualifier
                          snapshot: (NSDictionary *)snapshot
{
  EOFetchSpecification *fetch = nil;
  NSDictionary *row = nil;
  NSEnumerator *attrsEnum = nil;
  EOAttribute *attr = nil;
  NSMutableArray *attributes = nil;
  BOOL isEqual = YES;


  EOFLOGObjectLevelArgs(@"gsdb", @"attrs=%@", attrs);
  EOFLOGObjectLevelArgs(@"gsdb", @"entity=%@", entity);
  EOFLOGObjectLevelArgs(@"gsdb", @"qualifier=%@" ,qualifier);
  EOFLOGObjectLevelArgs(@"gsdb", @"snapshot=%@", snapshot);

  if (attrs)
    attributes = [[attrs mutableCopy] autorelease];

  if(attributes == nil)
    attributes = [NSMutableArray array];

  [attributes removeObjectsInArray: [entity primaryKeyAttributes]];
  [attributes addObjectsFromArray: [entity primaryKeyAttributes]];

  fetch = [EOFetchSpecification fetchSpecificationWithEntityName: [entity name]
				qualifier: qualifier
				sortOrderings: nil];

  [self selectAttributes: attributes
	fetchSpecification: fetch
	lock: YES
	entity: entity];

  row = [self fetchRowWithZone: NULL];

  EOFLOGObjectLevelArgs(@"gsdb", @"row=%@", row);

  if(row == nil || [self fetchRowWithZone: NULL] != nil)
    {
      [NSException raise: EOGeneralAdaptorException
                   format: @"%@ -- %@ 0x%p: cannot lock row for entity '%@' with qualifier: %@",
                   NSStringFromSelector(_cmd),
                   NSStringFromClass([self class]),
                   self,
                   [entity name],
                   qualifier];
    }

  attrsEnum = [attributes objectEnumerator];

  while((attr = [attrsEnum nextObject]))
    {
      NSString *name;

      name = [attr name];
      if([[row objectForKey: name]
	   isEqual: [snapshot objectForKey:name]] == NO)
	{
	  isEqual = NO;
	  break;
	}
    }

  if(isEqual == NO)
    {
      [NSException raise: EOGeneralAdaptorException
                   format: @"%@ -- %@ 0x%p: cannot lock row for entity '%@' with qualifier: %@",
                   NSStringFromSelector(_cmd),
                   NSStringFromClass([self class]),
                   self,
                   [entity name],
                   qualifier];
    }


}

- (void)evaluateExpression: (EOSQLExpression *)expression
{
  [self subclassResponsibility: _cmd];
}

- (BOOL)isFetchInProgress
{
  [self subclassResponsibility: _cmd];
  return NO;
}

- (NSArray *)describeResults
{
  [self subclassResponsibility: _cmd];
  return nil;
}

- (NSMutableDictionary *)fetchRowWithZone: (NSZone *)zone
{
  [self subclassResponsibility: _cmd];
  return nil;
}

- (void)setAttributesToFetch: (NSArray *)attributes
{
  [self subclassResponsibility: _cmd];
}

- (NSArray *)attributesToFetch
{
  [self subclassResponsibility: _cmd];
  return nil;
}

- (void)cancelFetch
{
  [self subclassResponsibility: _cmd];
}

- (NSDictionary *)primaryKeyForNewRowWithEntity: (EOEntity *)entity
{
  [self subclassResponsibility: _cmd];
  return nil;
}

- (NSArray *)primaryKeysForNewRowsWithEntity:(EOEntity *)entity count:(NSUInteger)count
{
  NSMutableArray * array = [NSMutableArray array];
  NSUInteger       i;
  
  for (i = 0; i < count; i++) {
    NSDictionary * newDict = [self primaryKeyForNewRowWithEntity:entity];
    if (newDict) {
      [array addObject: newDict];
    }
  }
  
  return array;
}

- (NSArray *)describeTableNames
{
  [self subclassResponsibility: _cmd];
  return nil;
}

- (NSArray *)describeStoredProcedureNames
{
  [self subclassResponsibility: _cmd];
  return nil;
}

- (EOModel *)describeModelWithTableNames: (NSArray *)tableNames
{
  [self subclassResponsibility: _cmd];
  return nil;
}

- (void)addStoredProceduresNamed: (NSArray *)storedProcedureNames
                         toModel: (EOModel *)model
{
  [self subclassResponsibility: _cmd];
}

- (void)setDebugEnabled: (BOOL)flag
{
  _debug = flag;
}

- (BOOL)isDebugEnabled
{
  return _debug;
}

- delegate
{
  return _delegate;
}

- (void)setDelegate:delegate
{
  _delegate = delegate;

  _delegateRespondsTo.willPerformOperations = 
    [_delegate respondsToSelector:
		 @selector(adaptorChannel:willPerformOperations:)];
  _delegateRespondsTo.didPerformOperations = 
    [_delegate respondsToSelector:
		 @selector(adaptorChannel:didPerformOperations:exception:)];
  _delegateRespondsTo.shouldSelectAttributes =
    [_delegate respondsToSelector:
		 @selector(adaptorChannel:shouldSelectAttributes:fetchSpecification:lock:)];
  _delegateRespondsTo.didSelectAttributes =
    [_delegate respondsToSelector:
		 @selector(adaptorChannel:didSelectAttributes:fetchSpecification:lock:)];
  _delegateRespondsTo.willFetchRow =
    [_delegate respondsToSelector:
		 @selector(adaptorChannelWillFetchRow:)];
  _delegateRespondsTo.didFetchRow =
    [_delegate respondsToSelector:
		 @selector(adaptorChannel:didFetchRow:)];
  _delegateRespondsTo.didChangeResultSet =
    [_delegate respondsToSelector:
		 @selector(adaptorChannelDidChangeResultSet:)];
  _delegateRespondsTo.didFinishFetching =
    [_delegate respondsToSelector:
		 @selector(adaptorChannelDidFinishFetching:)];
  _delegateRespondsTo.shouldEvaluateExpression =
    [_delegate respondsToSelector:
		 @selector(adaptorChannel:shouldEvaluateExpression:)];
  _delegateRespondsTo.didEvaluateExpression =
    [_delegate respondsToSelector:
		 @selector(adaptorChannel:didEvaluateExpression:)];
  _delegateRespondsTo.shouldExecuteStoredProcedure =
    [_delegate respondsToSelector:
		 @selector(adaptorChannel:shouldExecuteStoredProcedure:withValues:)];
  _delegateRespondsTo.didExecuteStoredProcedure =
    [_delegate respondsToSelector:
		 @selector(adaptorChannelDidExecuteStoredProcedure:withValues:)];
  _delegateRespondsTo.shouldConstructStoredProcedureReturnValues =
    [_delegate respondsToSelector:
		 @selector(adaptorChannelShouldConstructStoredProcedureReturnValues:)];
  _delegateRespondsTo.shouldReturnValuesForStoredProcedure =
    [_delegate respondsToSelector:
		 @selector(adaptorChannel:shouldReturnValuesForStoredProcedure:)];
}

- (NSMutableDictionary *)dictionaryWithObjects: (id *)objects 
                                 forAttributes: (NSArray *)attributes
                                          zone: (NSZone *)zone
{
  //OK (can be improved by calling EOMutableKnownKeyDictionary iini with objects but the order may be different
  EOMutableKnownKeyDictionary *dict=nil;
  EOAttribute *anAttribute=[attributes firstObject];

  NSAssert(anAttribute, @"No attribute");

  if (anAttribute)
    {
      EOEntity *entity = [anAttribute entity];
      EOMKKDInitializer *initializer;
      int i = 0;
      int count = [attributes count];

      // We may not have entity for direct SQL calls
      // We may not have entity for direct SQL calls
      if (entity)
        {
	  //NSArray *attributesToFetch = [entity _attributesToFetch];
	  initializer = [entity _adaptorDictionaryInitializer];
        }
      else
        {
	  initializer = [EOMKKDInitializer initializerFromKeyArray: 
                                             [attributes resultsOfPerformingSelector:
                                                           @selector(name)]];
        };

      EOFLOGObjectLevelArgs(@"gsdb",
                   @"\ndictionaryWithObjects:forAttributes:zone: attributes=%@ objects=%p\n",
                   attributes,objects);
      NSAssert(initializer,@"No initializer");
          
      EOFLOGObjectLevelArgs(@"gsdb", @"initializer=%@", initializer);
      
      dict = [[[EOMutableKnownKeyDictionary allocWithZone: zone]
                initWithInitializer:initializer] autorelease];
      
      EOFLOGObjectLevelArgs(@"gsdb", @"dict=%@", dict);

      for(i = 0; i < count; i++)
        {
          EOAttribute *attribute = (EOAttribute *)[attributes objectAtIndex: i];
          
          EOFLOGObjectLevelArgs(@"gsdb", @"Attribute=%@ value=%@", attribute, objects[i]);
          
          [dict setObject: objects[i]
                forKey: [attribute name]];
        }
    }

  return dict;
}

- (EOAdaptorContext *)adaptorContext
{
  return _context;
}

- (BOOL)isOpen
{
  [self subclassResponsibility: _cmd];
  return NO;
}

@end /* EOAdaptorChannel */


@implementation EOAdaptorChannel (EOStoredProcedures)

- (void)executeStoredProcedure: (EOStoredProcedure *)storedProcedure
                    withValues: (NSDictionary *)values
{
  [self subclassResponsibility: _cmd];
}

- (NSDictionary *)returnValuesForLastStoredProcedureInvocation
{
  [self subclassResponsibility: _cmd];
  return nil;
}

@end


@implementation EOAdaptorChannel (EOBatchProcessing)

//MG2014: OK
- (void)performAdaptorOperation: (EOAdaptorOperation *)adaptorOperation
{
  EOAdaptorContext *adaptorContext = [self adaptorContext];
  EOEntity *entity = nil;
  EOAdaptorOperator operator;

  if (![adaptorContext hasOpenTransaction])
    [adaptorContext beginTransaction];

  EOFLOGObjectLevelArgs(@"gsdb", @"adaptorOperation=%@", adaptorOperation);

  entity = [adaptorOperation entity];
  operator = [adaptorOperation adaptorOperator];
  EOFLOGObjectLevelArgs(@"gsdb", @"ad op: %d %@", operator, [entity name]);

  switch(operator)
    {
    case EOAdaptorLockOperator:
      EOFLOGObjectLevel(@"gsdb", @"EOAdaptorLockOperator");
      
      [self lockRowComparingAttributes: [adaptorOperation attributes]
	    entity: entity
	    qualifier: [adaptorOperation qualifier]
	    snapshot: [adaptorOperation changedValues]];
      break;
      
    case EOAdaptorInsertOperator:
      EOFLOGObjectLevel(@"gsdb", @"EOAdaptorInsertOperator");
      [self insertRow: [adaptorOperation changedValues]
	    forEntity: entity];
      break;
      
    case EOAdaptorUpdateOperator:
      EOFLOGObjectLevel(@"gsdb", @"EOAdaptorUpdateOperator");
      [self updateValues: [adaptorOperation changedValues]
	    inRowDescribedByQualifier: [adaptorOperation qualifier]
	    entity: entity];
      break;
      
    case EOAdaptorDeleteOperator:
      EOFLOGObjectLevel(@"gsdb", @"EOAdaptorDeleteOperator");
      [self deleteRowDescribedByQualifier: [adaptorOperation qualifier]
	    entity: entity];
      break;
      
    case EOAdaptorStoredProcedureOperator:
      EOFLOGObjectLevel(@"gsdb", @"EOAdaptorStoredProcedureOperator");
      [self executeStoredProcedure: [adaptorOperation storedProcedure]
	    withValues: [adaptorOperation changedValues]];
      [self returnValuesForLastStoredProcedureInvocation];
      break;
      
    case EOAdaptorUndefinedOperator:
      EOFLOGObjectLevel(@"gsdb", @"EOAdaptorUndefinedOperator");
      
    default:
      [NSException raise: NSInvalidArgumentException
		   format: @"%@ -- %@ 0x%p: Operator %d is not defined",
		   NSStringFromSelector(_cmd),
		   NSStringFromClass([self class]),
		   self,
		   (int)operator];
      break;
    }
}

- (void)performAdaptorOperations: (NSArray *)adaptorOperations
{
  int i = 0;
  int count = 0;

  if (_delegateRespondsTo.willPerformOperations)
      adaptorOperations=[_delegate adaptorChannel: self 
				   willPerformOperations: adaptorOperations];

  count=[adaptorOperations count];

  for(i = 0; i < count; i++)
    {
      EOAdaptorOperation *operation = [adaptorOperations objectAtIndex:i];

      NS_DURING
	[self performAdaptorOperation: operation];
      NS_HANDLER
	{
	  NSException *exp = nil;
          NSMutableDictionary *userInfo = nil;
          EOAdaptorOperator operator = 0;

          NSDebugMLog(@"EXCEPTION %@", localException);

	  operator = [operation adaptorOperator];

	  userInfo = [NSMutableDictionary dictionaryWithCapacity: 3];

	  [userInfo setObject: adaptorOperations
		    forKey: EOAdaptorOperationsKey];
	  [userInfo setObject: operation
		    forKey: EOFailedAdaptorOperationKey];

	  if(operator == EOAdaptorLockOperator
	     || operator == EOAdaptorUpdateOperator)
	    [userInfo setObject: EOAdaptorOptimisticLockingFailure
		      forKey: EOAdaptorFailureKey];

	  exp = [NSException exceptionWithName: EOGeneralAdaptorException
			     reason: [NSString stringWithFormat:@"%@ -- %@ 0x%p: failed with exception name:%@ reason:\"%@\"",
                             NSStringFromSelector(_cmd),
                             NSStringFromClass([self class]),
                             self,
                             [localException name],
                             [localException reason]]
                   userInfo: userInfo];
	  [exp raise];
	}
      NS_ENDHANDLER;
    }


}

@end
