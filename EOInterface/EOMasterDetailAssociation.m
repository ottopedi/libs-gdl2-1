/**
   EOMasterDetailAssociation.m

   Copyright (C) 2004 Free Software Foundation, Inc.

   Author: David Ayers <d.ayers@inode.at>

   This file is part of the GNUstep Database Library

   The GNUstep Database Library is free software; you can redistribute it 
   and/or modify it under the terms of the GNU Lesser General Public License 
   as published by the Free Software Foundation; either version 2, 
   or (at your option) any later version.

   The GNUstep Database Library is distributed in the hope that it will be 
   useful, but WITHOUT ANY WARRANTY; without even the implied warranty of 
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU 
   Lesser General Public License for more details.

   You should have received a copy of the GNU Lesser General Public License 
   along with the GNUstep Database Library; see the file COPYING. If not, 
   write to the Free Software Foundation, Inc., 
   59 Temple Place - Suite 330, Boston, MA 02111-1307, USA. 
*/

#ifdef GNUSTEP
#include <Foundation/NSString.h>
#include <Foundation/NSArray.h>
#else
#include <Foundation/Foundation.h>
#endif

#include <EOControl/EODetailDataSource.h>

#include "EODisplayGroup.h"
#include "EOMasterDetailAssociation.h"

@implementation EOMasterDetailAssociation

+ (NSArray *)aspects
{
  static NSArray *_aspects = nil;
  if (_aspects == nil)
    {
      _aspects
        = RETAIN ([[super aspects] arrayByAddingObject: @"parent"]);
    }
  return _aspects;
}

+ (NSArray *)aspectSignatures
{
  static NSArray *_signatures = nil;
  if (_signatures == nil)
    {
      _signatures
        = RETAIN ([[super aspectSignatures] arrayByAddingObject: @"1M"]);
    }
  return _signatures;
}

+ (BOOL)isUsableWithObject: (id)object
{
  return [object isKindOfClass: [EODisplayGroup class]]
    && [[object dataSource] isKindOfClass: [EODetailDataSource class]];
}

+ (NSString *)displayName
{
  return @"EOMasterDetailAssoc";
}

+ (NSString *)primaryAspect
{
  return @"parent";
}

- (void)establishConnection
{
}
- (void)breakConnection
{
}

- (void)subjectChanged
{
}

- (EOObserverPriority)priority
{
  return EOObserverPrioritySecond;
}

@end