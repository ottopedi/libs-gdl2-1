/* 
   EONull.h

   Copyright (C) 1996-2002, 2003 Free Software Foundation, Inc.

   Author: Mircea Oancea <mircea@jupiter.elcom.pub.ro>
   Date: 1996

   This file is part of the GNUstep Database Library.

   This library is free software; you can redistribute it and/or
   modify it under the terms of the GNU Library General Public
   License as published by the Free Software Foundation; either
   version 2 of the License, or (at your option) any later version.

   This library is distributed in the hope that it will be useful,
   but WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
   Library General Public License for more details.

   You should have received a copy of the GNU Library General Public
   License along with this library; see the file COPYING.LIB.
   If not, write to the Free Software Foundation,
   59 Temple Place - Suite 330, Boston, MA 02111-1307, USA.
*/

#ifndef __EONull_h__
#define __EONull_h__

#ifndef NeXT_Foundation_LIBRARY
#include <Foundation/NSNull.h>
#else
#include <Foundation/Foundation.h>
#endif

#include "EODefines.h"

@class NSString;

#define EONull NSNull

@interface EONull (EOSQLFormatting)
- (NSString *)sqlString;
@end

@interface NSObject (EONullTest)
- (BOOL)isEONull;
- (BOOL)isNotEONull;
@end

GDL2CONTROL_EXPORT BOOL isNilOrEONull(id v);

#endif /* __EONull_h__ */

