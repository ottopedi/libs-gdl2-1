/* -*-objc-*-
   EOAccessFaultPriv.h

   Copyright (C) 2000,2004,2005 Free Software Foundation, Inc.

   Author: Mirko Viviani <mirko.viviani@rccr.cremona.it>
   Date: July 2000

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
   51 Franklin Street, Fifth Floor, Boston, MA 02110-1301, USA.
*/

#ifndef __EOAccessFaultPriv_h__
#define __EOAccessFaultPriv_h__

@interface EOAccessGenericFaultHandler (EOAccessFaultPrivate)

- (void)_linkNext: (EOAccessGenericFaultHandler *)next;
- (void)_linkPrev: (EOAccessGenericFaultHandler *)prev;

@end

#endif
