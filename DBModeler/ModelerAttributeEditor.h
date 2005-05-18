#ifndef __ModelerAttributeEditor_H_
#define __ModelerAttributeEditor_H_

/*
    ModelerAttributeEditor.h
 
    Author: Matt Rice <ratmice@yahoo.com>
    Date: Apr 2005

    This file is part of DBModeler.

    DBModeler is free software; you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation; either version 2 of the License, or
    (at your option) any later version.

    DBModeler is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with DBModeler; if not, write to the Free Software
    Foundation, Inc., 51 Franklin St, Fifth Floor, Boston, MA  02110-1301  USA
*/ 

#include "ModelerTableEmbedibleEditor.h"
#include <EOControl/EOObserver.h>

@class NSSplitView;
@class NSTableView;
@class EODisplayGroup;
@class PlusMinusView;

@interface ModelerAttributeEditor : ModelerTableEmbedibleEditor <EOObserving>
{
  NSSplitView *_mainView;
  NSTableView *_attributes_tableView;
  NSTableView *_relationships_tableView;
  EODisplayGroup *_attributes_dg;
  EODisplayGroup *_relationships_dg;
  id _entityToObserve;
  id _attributeToObserve;
}

@end

#endif // __ModelerAttributeEditor_H_
