/* 
   EOUndoManager.h

   Copyright (C) 2000 Free Software Foundation, Inc.

   Author: Manuel Guesdon <mguesdon@orange-concept.com>
   Date: October 2000

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

#import <Foundation/NSUndoManager.h>

@interface EOUndoManager : NSUndoManager

- (void) forgetAllWithTarget: (id)param0;
- (void) forgetAll;
- (void) registerUndoWithTarget: (id)param0
                       selector: (SEL)param1
                            arg: (id)param2;
- (void) reenableUndoRegistration;

@end
