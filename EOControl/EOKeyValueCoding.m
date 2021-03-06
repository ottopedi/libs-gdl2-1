
/** 
   EOKeyValueCoding.m <title>EOKeyValueCoding</title>

   Copyright (C) 1996-2002,2003,2004,2005 Free Software Foundation, Inc.

   Author: Mircea Oancea <mircea@jupiter.elcom.pub.ro>
   Date: November 1996

   Author: Mirko Viviani <mirko.viviani@gmail.com>
   Date: February 2000

   Author: Manuel Guesdon <mguesdon@oxymium.net>
   Date: January 2002

   Author: David Ayers <ayers@fsfe.org>
   Date: February 2003-2010

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
#include <Foundation/NSArray.h>
#include <Foundation/NSDebug.h>
#include <Foundation/NSDecimalNumber.h>
#include <Foundation/NSDictionary.h>
#include <Foundation/NSEnumerator.h>
#include <Foundation/NSException.h>
#include <Foundation/NSHashTable.h>
#include <Foundation/NSKeyValueCoding.h>
#include <Foundation/NSMapTable.h>
#include <Foundation/NSObjCRuntime.h>
#include <Foundation/NSString.h>
#include <Foundation/NSValue.h>
#else
#include <Foundation/Foundation.h>
#endif

#ifndef GNUSTEP
#include <GNUstepBase/GNUstep.h>
#include <GNUstepBase/NSDebug+GNUstepBase.h>
#include <GNUstepBase/NSString+GNUstepBase.h>
#endif

#include <EOControl/EOKeyValueCoding.h>
#include <EOControl/EONSAddOns.h>
#include <EOControl/EODebug.h>
#include <EOControl/EONull.h>

#include <GNUstepBase/GSObjCRuntime.h>

#include "EOPrivate.h"

static BOOL    strictWO;
static BOOL initialized=NO;

static inline void
initialize(void)
{
  if (!initialized)
    {
      initialized=YES;
      strictWO = GSUseStrictWO451Compatibility(nil);
      GDL2_PrivateInit();
    }
}

/* This macro is only used locally in defined places so for the sake
   of efficiency, we don't use the do {} while (0) pattern.  */
#define INITIALIZE if (!initialized) initialize();

#ifdef __has_attribute
#if __has_attribute(objc_root_class)
__attribute__((objc_root_class))
#endif
#endif
@interface	GDL2KVCNSObject
@end
@interface	GDL2KVCNSObject (NSKeyValueCoding) <NSObject>
- (void) unableToSetNilForKey: (NSString*)aKey;
- (BOOL) validateValue: (id*)aValue
		forKey: (NSString*)aKey
		 error: (NSError**)anError;
- (BOOL) validateValue: (id*)aValue
	    forKeyPath: (NSString*)aKey
		 error: (NSError**)anError;
- (id) valueForKey: (NSString*)aKey;
- (id) valueForKeyPath: (NSString*)aKey;
- (id) valueForUndefinedKey: (NSString*)aKey;
- (NSDictionary*) valuesForKeys: (NSArray*)keys;
@end

@implementation GDL2KVCNSObject

+ (void)load
{
  GDL2_Activate(GSClassFromName("NSObject"), self);
}

/* This is what -base(add) will call.  It should invoke what the API
   specifies should be overridden.  */
- (void) setNilValueForKey: (NSString*)aKey
{
  [self unableToSetNilForKey: aKey];
}


/* This is what should be overridden according to the API.*/
- (void) unableToSetNilForKey: (NSString *)key
{
  [NSException raise: NSInvalidArgumentException
	       format: @"%@ -- %@ 0x%p: Given nil value to set for key \"%@\"",
	       NSStringFromSelector(_cmd), NSStringFromClass([self class]), 
	       self, key];
}

/* See EODeprecated.h. */
+ (void) flushClassKeyBindings
{
}

/* See header file for documentation. */
+ (void) flushAllKeyBindings
{
}

- (void) takeValue: (id)anObject forKey: (NSString*)aKey
{
  SEL		sel = 0;
  const char	*type = 0;
  int		off = 0;
  unsigned	size = [aKey length];
  id		self_id = self;

  if (size > 0)
    {
      const char	*name;
      char		buf[size+6];
      char		lo;
      char		hi;

      strcpy(buf, "_set");
      [aKey getCString: &buf[4]];
      lo = buf[4];
      hi = islower(lo) ? toupper(lo) : lo;
      buf[4] = hi;
      buf[size+4] = ':';
      buf[size+5] = '\0';

      name = &buf[1];	// setKey:
      type = NULL;
      sel = GSSelectorFromName(name);
      if (sel == 0 || [self respondsToSelector: sel] == NO)
	{
	  name = buf;	// _setKey:
	  sel = GSSelectorFromName(name);
	  if (sel == 0 || [self respondsToSelector: sel] == NO)
	    {
	      sel = 0;
	      if ([[self class] accessInstanceVariablesDirectly] == YES)
		{
		  buf[size+4] = '\0';
		  buf[3] = '_';
		  buf[4] = lo;
		  name = &buf[4];	// key
		  if (GSObjCFindVariable(self, name, &type, &size, &off) == NO)
		    {
		      name = &buf[3];	// _key
		      GSObjCFindVariable(self, name, &type, &size, &off);
		    }
		}
	    }
	}
    }
  GSObjCSetVal(self_id, [aKey UTF8String], anObject, sel, type, size, off);
}


- (void) takeValue: (id)anObject forKeyPath: (NSString*)aKey
{
  NSRange	r = [aKey rangeOfString: @"."];

  if (r.length == 0)
    {
      [self takeValue: anObject forKey: aKey];
    }
  else
    {
      NSString	*key = [aKey substringToIndex: r.location];
      NSString	*path = [aKey substringFromIndex: NSMaxRange(r)];

      [[self valueForKey: key] takeValue: anObject forKeyPath: path];
    }
}


- (void) takeValuesFromDictionary: (NSDictionary*)aDictionary
{
  NSEnumerator	*enumerator = [aDictionary keyEnumerator];
  NSNull	*null = [NSNull null];
  NSString	*key;

  while ((key = [enumerator nextObject]) != nil)
    {
      id obj = [aDictionary objectForKey: key];

      if (obj == null)
	{
	  obj = nil;
	}
      [self takeValue: obj forKey: key];
    }
}

@end


/*
  This declaration is needed by the compiler to state that
  eventhough we know not all objects respond to -compare:,
  we want the compiler to generate code for the given
  prototype when calling -compare: in the following methods.
  We do not put this declaration in a header file to avoid
  the compiler seeing conflicting prototypes in user code.
*/
@interface NSObject (Comparison)
- (NSComparisonResult)compare: (id)other;
@end


@interface	GDL2KVCNSArray : NSObject
@end
@interface GDL2KVCNSArray (NSArray)
- (NSUInteger) count;
- (NSArray *)resultsOfPerformingSelector: (SEL)sel
			      withObject: (NSString *)key
                           defaultResult: (id)defaultResult;
@end
@implementation	GDL2KVCNSArray

+ (void)load
{
  GDL2_Activate(GSClassFromName("NSArray"), self);
}
/**
 * EOKeyValueCoding protocol<br/>
 * This overrides NSObjects implementation of this method.
 * Generally this method returns an array of objects
 * returned by invoking valueForKey:
 * for each item in the receiver, substituting EONull for nil.
 * Keys formated like "@function.someKeyPath" are resolved by invoking
 * <code>NSArray compute<em>Function</em>WithKey:</code> "someKeyPath" on the receiver.
 * If the keyPath is omitted, the function will be called with nil.
 * The following functions are supported by default:
 * <list>
 *  <item>@sum   -> -computeSumForKey:</item>
 *  <item>@avg   -> -computeAvgForKey:</item>
 *  <item>@max   -> -computeMaxForKey:</item>
 *  <item>@min   -> -computeMinForKey:</item>
 *  <item>@count -> -computeCountForKey:</item>
 * </list>
 * Computational components generally expect a keyPath to be passed to
 * the function.  This is not mandatory in which case 'nil' will be supplied.
 * (i.e. you may use "@myFuncWhichCanHandleNil" as a key.)<br/>
 * There is no special handling of EONull.  Therefore expect exceptions
 * on EONull not responding to decimalValue and compare: when the are
 * used with this mechanism. 
 */
- (id)valueForKey: (NSString *)key
{
  id result;

  INITIALIZE;

  if ([key isEqual: @"count"] || [key isEqual: @"@count"])
    {
      result = [NSDecimalNumber numberWithUnsignedInt: [self count]];
    }
  else if ([key hasPrefix:@"@"])
    {
      NSString *selStr;
      NSString *attrStr;
      SEL       sel;
      NSRange   r;

      r = [key rangeOfString:@"."];
      if (r.location == NSNotFound)
	{
	  r.length   = [key length] - 1; /* set length of key (w/o @) */
	  r.location = 1;                /* remove leading '@' */
	  attrStr = nil;
	}
      else
	{
	  r.length  = r.location - 1;    /* set length of key (w/o @) */
	  r.location = 1;                /* remove leading '@' */
                                         /* skip located '.' */
	  attrStr = [key substringFromIndex: NSMaxRange(r) + 1];
	}

      selStr = [NSString stringWithFormat: @"compute%@ForKey:",
		   [[key substringWithRange: r] initialCapitalizedString]];
      sel = NSSelectorFromString(selStr);
      NSAssert2(sel!=NULL,@"Invalid computational key: '%@' Selector: '%@'",
                key,
                selStr);

      result = [self performSelector: sel
		     withObject: attrStr];
    }
  else
    {
      result = [self resultsOfPerformingSelector: @selector(valueForKey:)
		     withObject: key
		     defaultResult: GDL2_EONull];
    }

  return result;
}

/**
 * EOKeyValueCoding protocol<br/>
 * Returns the object returned by invoking valueForKeyPath:
 * on the object returned by invoking valueForKey:
 * on the receiver with the first key component supplied by the key path,
 * with rest of the key path.<br/>
 * If the first component starts with "@", the first component includes the key
 * of the computational key component and as the form "@function.keyPath".
 * If there is only one key component, this method invokes 
 * valueForKey: in the receiver with that component.
 */
- (id)valueForKeyPath: (NSString *)keyPath
{
  NSRange   r;
  id        result;



  if ([keyPath hasPrefix: @"@"] || (r = [keyPath rangeOfString: @"."]).location == NSNotFound)
    {
      result = [self valueForKey: keyPath];
    }
  else
    {
      NSString *key  = [keyPath substringToIndex: r.location];
      NSString *path = [keyPath substringFromIndex: NSMaxRange(r)];

      result = [[self valueForKey: key] valueForKeyPath: path];
    }



  return result;
}

/**
 * Iterates over the objects of the receiver send each object valueForKey:
 * with the parameter.  The decimalValue of the returned object is accumalted.
 * An empty array returns NSDecimalNumber 0.
 */
- (id)computeSumForKey: (NSString *)key
{
  NSDecimalNumber *ret=nil;
  NSDecimal        result, left, right;
  NSRoundingMode   mode;
  unsigned int     count;

  INITIALIZE;

  mode = [[NSDecimalNumber defaultBehavior] roundingMode];
  count = [self count];
  
  // does not seem to exist on snow leopad -- dw
  // NSDecimalFromComponents(&result, 0, 0, NO);

  result = [[NSDecimalNumber zero] decimalValue];
  
  if (count>0)
    {
      unsigned int i=0;
      IMP oaiIMP = [self methodForSelector: @selector(objectAtIndex:)];
      for (i=0; i<count; i++)
        {
          left = result;
          right = [[GDL2_ObjectAtIndexWithImp(self,oaiIMP,i) valueForKeyPath: key] decimalValue];
          NSDecimalAdd(&result, &left, &right, mode);
        }
    };
        
  ret = [NSDecimalNumber decimalNumberWithDecimal: result];

  return ret;
}

/**
 * Iterates over the objects of the receiver send each object valueForKey:
 * with the parameter.  The decimalValue of the returned object is accumalted
 * and then divided by number of objects contained by the receiver as returned
 * by <code>NSArray count</code>.  An empty array returns NSDecimalNumber 0.
 */
- (id)computeAvgForKey: (NSString *)key
{
  NSDecimalNumber *ret = nil;
  NSDecimal        result, left, right;
  NSRoundingMode   mode;
  unsigned int     count = 0;

  INITIALIZE;


  mode = [[NSDecimalNumber defaultBehavior] roundingMode];
  count = [self count];
  
  result = [[NSDecimalNumber zero] decimalValue];

  // not available on snow leo -- dw
  // NSDecimalFromComponents(&result, 0, 0, NO);

  if (count>0)
    {
      unsigned int i=0;
      IMP oaiIMP = [self methodForSelector: @selector(objectAtIndex:)];
      
      for (i=0; i<count; i++)
        {
          left = result;
          right = [[GDL2_ObjectAtIndexWithImp(self,oaiIMP,i) valueForKeyPath: key] decimalValue];
          NSDecimalAdd(&result, &left, &right, mode);
        }
    }
  else
    {
      return [NSDecimalNumber zero];
    }

  left  = result;
  
  right = [[NSNumber numberWithUnsignedLongLong:count] decimalValue];

//  NSDecimalFromComponents(&right, (unsigned long long) count, 0, NO);

  NSDecimalDivide(&result, &left, &right, mode);
        
  ret = [NSDecimalNumber decimalNumberWithDecimal: result];

  return ret;
}

- (id)computeCountForKey: (NSString *)key
{
  NSArray *array;
  id result;


  array = key ? [self valueForKeyPath: key] : self;
  result = [NSDecimalNumber numberWithUnsignedInt: [array count]];


  return result;
}

- (id)computeMaxForKey: (NSString *)key
{
  id result=nil;
  id resultVal=nil;
  unsigned int count=0;

  INITIALIZE;


  count     = [self count];

  if (count > 0)
    {
      unsigned int i=0;
      id           current = nil;
      id	   currentVal = nil;
      IMP          oaiIMP = [self methodForSelector: @selector(objectAtIndex:)];

      for(i=0; i<count && (resultVal == nil || resultVal == GDL2_EONull); i++)
	{
	  result    = GDL2_ObjectAtIndexWithImp(self,oaiIMP,i);
	  resultVal = [result valueForKeyPath: key];
	}          
      for (; i<count; i++)
	{
	  current    = GDL2_ObjectAtIndexWithImp(self,oaiIMP,i);
	  currentVal = [current valueForKeyPath: key];

	  if (currentVal == nil || currentVal == GDL2_EONull)
            continue;
	  
	  if ([(NSObject *)resultVal compare: currentVal] == NSOrderedAscending)
	    {
	      result    = current;
	      resultVal = currentVal;
	    }
	}
    }


  return result;
}

- (id)computeMinForKey: (NSString *)key
{
  id result=nil;
  id resultVal=nil;
  unsigned int   count = 0;

  INITIALIZE;


  count     = [self count];

  if (count > 0)
    {
      id current=nil;
      id currentVal=nil;
      unsigned int i = 0;
      IMP oaiIMP = [self methodForSelector: @selector(objectAtIndex:)];

      for(i=0; i<count && (resultVal == nil || resultVal == GDL2_EONull); i++)
	{
	  result    = GDL2_ObjectAtIndexWithImp(self,oaiIMP,i);
	  resultVal = [result valueForKeyPath: key];
	}          
      for (; i<count; i++)
	{
	  current    = GDL2_ObjectAtIndexWithImp(self,oaiIMP,i);
	  currentVal = [current valueForKeyPath: key];

	  if (currentVal == nil || currentVal == GDL2_EONull) continue;

	  if ([(NSObject *)resultVal compare: currentVal] == NSOrderedDescending)
	    {
	      result    = current;
	      resultVal = currentVal;
	    }
	}
    }


  return result;
}

@end


@interface	GDL2KVCNSDictionary : NSObject
@end
@interface	GDL2KVCNSDictionary (NSDictionary)
- (NSArray*) allKeys;
- (NSArray*) allValues;
- (id) objectForKey: (id)aKey;
- (NSUInteger) count;
- (void)smartTakeValue: (id)object 
            forKeyPath: (NSString *)keyPath;
- (void)takeValue: (id)value
       forKeyPath: (NSString *)keyPath
          isSmart: (BOOL)smartFlag;
@end
@implementation	GDL2KVCNSDictionary

+ (void)load
{
  GDL2_Activate(GSClassFromName("NSDictionary"), self);
}

/**
 * Returns the object stored in the dictionary for this key.
 * Unlike Foundation, this method may return objects for keys other than
 * those explicitly stored in the receiver.  These special keys are
 * 'count', 'allKeys' and 'allValues'.
 * We override the implementation to account for these
 * special keys.
 */
- (id)valueForKey: (NSString *)key
{
  id value;


  //EOFLOGObjectLevelArgs(@"EOKVC", @"key=%@",
  //                      key);

  value = [self objectForKey: key];

  if (!value)
    {
      if ([key isEqualToString: @"allValues"])
	{
#ifndef GNUSTEP
          static BOOL warnedValuesKeys = NO;
          if (warnedValuesKeys == NO)
            {
              warnedValuesKeys = YES;
              NSWarnMLog(@"Foundation does not return a value for the special 'allValues' key", "");
            }
#endif
	  value = [self allValues];
	}
      else if ([key isEqualToString: @"allKeys"])
	{
#ifndef GNUSTEP
          static BOOL warnedAllKeys = NO;
          if (warnedAllKeys == NO)
            {
              warnedAllKeys = YES;
              NSWarnMLog(@"Foundation does not return a value for the special 'allKeys' key", "");
            }
#endif
	  value = [self allKeys];
	}
      else if ([key isEqualToString: @"count"])
	{
#ifndef GNUSTEP
          static BOOL warnedCount = NO;
          if (warnedCount == NO)
            {
              warnedCount = YES;
              NSWarnMLog(@"Foundation does not return a value for the special 'count' key", "");
            }
#endif
	  value = [NSNumber numberWithUnsignedInt: [self count]];
	}
    }

  //EOFLOGObjectLevelArgs(@"EOKVC", @"key=%@ value: %p (class=%@)",
  //                      key, value, [value class]);


  return value;
}

/**
 * Returns the object stored in the dictionary for this key.
 * Unlike Foundation, this method may return objects for keys other than
 * those explicitly stored in the receiver.  These special keys are
 * 'count', 'allKeys' and 'allValues'.
 * We do not simply invoke [NSDictionary-valueForKey:]
 * to avoid recursions in subclasses that might implement
 * [NSDictionary-valueForKey:] by calling [NSDictionary-storedValueForKey:]
 */
- (id)storedValueForKey: (NSString *)key
{
  id value;


  //EOFLOGObjectLevelArgs(@"EOKVC", @"key=%@",
  //                      key);

  value = [self objectForKey: key];

  if (!value)
    {
      if ([key isEqualToString: @"allValues"])
	{
	  value = [self allValues];
	}
      else if ([key isEqualToString: @"allKeys"])
	{
	  value = [self allKeys];
	}
      else if ([key isEqualToString: @"count"])
	{
	  value = [NSNumber numberWithUnsignedInt: [self count]];
	}
    }

  //EOFLOGObjectLevelArgs(@"EOKVC", @"key=%@ value: %p (class=%@)",
  //                      key, value, [value class]);


  return value;
}

/**
 * First checks whether the entire keyPath is contained as a key
 * in the receiver before invoking super's implementation.
 * (The special quoted key handling will probably be moved
 * to a GSWDictionary subclass to be used by GSWDisplayGroup.)
 */
- (id)valueForKeyPath: (NSString*)keyPath
{
  id  value = nil;

  INITIALIZE;


  //EOFLOGObjectLevelArgs(@"EOKVC", @"keyPath=\"%@\"",
  //                      keyPath);

  if ([keyPath hasPrefix: @"'"] && strictWO == NO) //user defined composed key 
    {
      NSMutableArray *keyPathArray = [[[[keyPath stringByDeletingPrefix: @"'"]
					 componentsSeparatedByString: @"."]
					mutableCopy] autorelease];
      NSMutableString *key = [NSMutableString string];

      //

      while ([keyPathArray count] > 0)
        {
          id tmpKey;

          //

          tmpKey = [keyPathArray objectAtIndex: 0];
          //

          [keyPathArray removeObjectAtIndex: 0];

          if ([key length] > 0)
            [key appendString: @"."];
          if ([tmpKey hasSuffix: @"'"])
            {
              tmpKey = [tmpKey stringByDeletingSuffix: @"'"];
              [key appendString: tmpKey];
              break;
            }
          else
	    [key appendString: tmpKey];

          //
        }

      //

      value = [self valueForKey: key];

      //EOFLOGObjectLevelArgs(@"EOKVC",@"key=%@ tmpValue: %p (class=%@)",
      //             key,value,[value class]);

      if (value && [keyPathArray count] > 0)
        {
          NSString *rightKeyPath = [keyPathArray
				     componentsJoinedByString: @"."];

          //EOFLOGObjectLevelArgs(@"EOKVC", @"rightKeyPath=%@",
          //                      rightKeyPath);

          value = [value valueForKeyPath: rightKeyPath];
        }
    }
  else
    {
      /*
       * Return super valueForKeyPath: only 
       * if there's no object for entire key keyPath
       */
      value = [self objectForKey: keyPath];

      EOFLOGObjectLevelArgs(@"EOKVC",@"keyPath=%@ tmpValue: %p (class=%@)",
                   keyPath,value,[value class]);

      if (!value)
        value = [super valueForKeyPath: keyPath];
    }

  //EOFLOGObjectLevelArgs(@"EOKVC",@"keyPath=%@ value: %p (class=%@)",
  //             keyPath,value,[value class]);


  return value;
}

/**
 * First checks whether the entire keyPath is contained as a key
 * in the receiver before invoking super's implementation.
 * (The special quoted key handling will probably be moved
 * to a GSWDictionary subclass to be used by GSWDisplayGroup.)
 */
- (id)storedValueForKeyPath: (NSString*)keyPath
{
  id value = nil;

  INITIALIZE;


  //EOFLOGObjectLevelArgs(@"EOKVC",@"keyPath=\"%@\"",
  //                      keyPath);

  if ([keyPath hasPrefix: @"'"] && strictWO == NO) //user defined composed key 
    {
      NSMutableArray *keyPathArray = [[[[keyPath stringByDeletingPrefix: @"'"]
					 componentsSeparatedByString: @"."]
					mutableCopy] autorelease];
      NSMutableString *key = [NSMutableString string];

      //

      while ([keyPathArray count] > 0)
        {
          id tmpKey;

          //

          tmpKey = [keyPathArray objectAtIndex: 0];
          //

          [keyPathArray removeObjectAtIndex: 0];

          if ([key length] > 0)
            [key appendString: @"."];
          if ([tmpKey hasSuffix: @"'"])
            {
              tmpKey = [tmpKey stringByDeletingSuffix: @"'"];
              [key appendString: tmpKey];
              break;
            }
          else
	    [key appendString: tmpKey];

          //
        }

      //

      value = [self storedValueForKey: key];

      //EOFLOGObjectLevelArgs(@"EOKVC",@"key=%@ tmpValue: %p (class=%@)",
      //             key,value,[value class]);

      if (value && [keyPathArray count] > 0)
        {
          NSString *rightKeyPath = [keyPathArray
				     componentsJoinedByString: @"."];

          EOFLOGObjectLevelArgs(@"EOKVC", @"rightKeyPath=%@",
				rightKeyPath);

          value = [value storedValueForKeyPath: rightKeyPath];
        }
    }
  else
    {
      /*
       * Return super valueForKeyPath: only 
       * if there's no object for entire key keyPath
       */
      value = [self objectForKey: keyPath];

      //EOFLOGObjectLevelArgs(@"EOKVC",@"keyPath=%@ tmpValue: %p (class=%@)",
      //             keyPath,value,[value class]);

      if (!value)
        value = [super storedValueForKeyPath: keyPath];
    }

  //EOFLOGObjectLevelArgs(@"EOKVC",@"keyPath=%@ value: %p (class=%@)",
  //             keyPath,value,[value class]);


  return value;
}

@end


@interface NSMutableDictionary(EOKeyValueCodingPrivate)
- (void)takeValue: (id)value
       forKeyPath: (NSString *)keyPath
          isSmart: (BOOL)smartFlag;
@end

@interface	GDL2KVCNSMutableDictionary : NSDictionary
@end
@interface	GDL2KVCNSMutableDictionary (NSMutableDictionary)
- (void) removeObjectForKey: (id)aKey;
- (void) setObject: (id)anObject forKey: (id)aKey;
- (void)takeValue: (id)value
       forKeyPath: (NSString *)keyPath
          isSmart: (BOOL)smartFlag;
@end
@implementation GDL2KVCNSMutableDictionary

+ (void)load
{
  GDL2_Activate(GSClassFromName("NSMutableDictionary"), self);
}
/**
 * Method to augment the NSKeyValueCoding implementation
 * to account for added functionality such as quoted key paths.
 * (The special quoted key handling will probably be moved
 * to a GSWDictionary subclass to be used by GSWDisplayGroup.
 * this method then becomes obsolete.)
 */
- (void)smartTakeValue: (id)value 
            forKeyPath: (NSString*)keyPath
{
  [self takeValue:value
        forKeyPath:keyPath
        isSmart:YES];
}

/**
 * Overrides gnustep-base and Foundations implementation
 * to account for added functionality such as quoted key paths.
 * (The special quoted key handling will probably be moved
 * to a GSWDictionary subclass to be used by GSWDisplayGroup.
 * this method then becomes obsolete.)
 */
- (void)takeValue: (id)value
       forKeyPath: (NSString *)keyPath
{
  [self takeValue:value
        forKeyPath:keyPath
        isSmart:NO];
}

/**
 * Support method to augment the NSKeyValueCoding implementation
 * to account for added functionality such as quoted key paths.
 * (The special quoted key handling will probably be moved
 * to a GSWDictionary subclass to be used by GSWDisplayGroup.
 * this method then becomes obsolete.)
 */
- (void)takeValue: (id)value
       forKeyPath: (NSString *)keyPath
          isSmart: (BOOL)smartFlag
{

  //EOFLOGObjectLevelArgs(@"EOKVC", @"keyPath=\"%@\"",
  //                      keyPath);

  INITIALIZE;

  if ([keyPath hasPrefix: @"'"] && strictWO == NO) //user defined composed key 
    {
      NSMutableArray *keyPathArray = [[[[keyPath stringByDeletingPrefix: @"'"]
					 componentsSeparatedByString: @"."]
					mutableCopy] autorelease];
      NSMutableString *key = [NSMutableString string];

      unsigned keyPathArrayCount = [keyPathArray count];

      //

      while (keyPathArrayCount > 0)
        {
          id tmpKey;

          //

          tmpKey = RETAIN([keyPathArray objectAtIndex: 0]);
          //

          [keyPathArray removeObjectAtIndex: 0];
          keyPathArrayCount--;

          if ([key length] > 0)
            [key appendString: @"."];
          if ([tmpKey hasSuffix: @"'"])
            {
              ASSIGN(tmpKey, [tmpKey stringByDeletingSuffix: @"'"]);
              [key appendString: tmpKey];
              break;
            }
          else
	    [key appendString: tmpKey];

          RELEASE(tmpKey);

          //
        }

      //
      //EOFLOGObjectLevelArgs(@"EOKVC",@"left keyPathArray=\"%@\"",
      //             keyPathArray);

      if (keyPathArrayCount > 0)
        {
          id obj = [self objectForKey: key];

          if (obj)
            {
              NSString *rightKeyPath = [keyPathArray
					 componentsJoinedByString: @"."];

              //EOFLOGObjectLevelArgs(@"EOKVC",@"rightKeyPath=\"%@\"",
              //             rightKeyPath);

              if (smartFlag)
                [obj smartTakeValue: value
		     forKeyPath: rightKeyPath];
              else
                [obj takeValue: value
		     forKeyPath: rightKeyPath];
            }
        }
      else
        {
          if (value)
            [self setObject: value 
                  forKey: key];
          else
            [self removeObjectForKey: key];
        }
    }
  else
    {
      if (value == nil)
	{
	  [self removeObjectForKey: keyPath];
	}
      else
	{
	  [self setObject: value forKey: keyPath];
	}
     }


}

/**
 * Calls [NSMutableDictionary-setObject:forKey:] using the full keyPath
 * as a key, if the value is non nil.  Otherwise calls
 * [NSDictionary-removeObjectForKey:] with the full keyPath.
 * (The special quoted key handling will probably be moved
 * to a GSWDictionary subclass to be used by GSWDisplayGroup.)
 */
- (void)takeStoredValue: (id)value 
             forKeyPath: (NSString *)keyPath
{

  //EOFLOGObjectLevelArgs(@"EOKVC",@"keyPath=\"%@\"",
  //             keyPath);

  if ([keyPath hasPrefix: @"'"]) //user defined composed key 
    {
      NSMutableArray *keyPathArray = [[[[keyPath stringByDeletingPrefix: @"'"]
					 componentsSeparatedByString: @"."]
					mutableCopy] autorelease];
      NSMutableString *key = [NSMutableString string];

      int keyPathArrayCount=[keyPathArray count];

      //

      while (keyPathArrayCount > 0)
        {
          id tmpKey;

          //

          tmpKey = [keyPathArray objectAtIndex: 0];
          //

          [keyPathArray removeObjectAtIndex: 0];
          keyPathArrayCount--;

          if ([key length] > 0)
            [key appendString: @"."];

          if ([tmpKey hasSuffix: @"'"])
            {
              tmpKey = [tmpKey stringByDeletingSuffix: @"'"];
              [key appendString: tmpKey];
              break;
            }
          else
	    [key appendString: tmpKey];

          //
        }

      //
      //EOFLOGObjectLevelArgs(@"EOKVC",@"left keyPathArray=\"%@\"",
      //             keyPathArray);

      if (keyPathArrayCount > 0)
        {
          id obj = [self objectForKey: key];

          if (obj)
            {
              NSString *rightKeyPath = [keyPathArray
					 componentsJoinedByString: @"."];

              //EOFLOGObjectLevelArgs(@"EOKVC",@"rightKeyPath=\"%@\"",
              //             rightKeyPath);

              [obj  takeStoredValue: value
                    forKeyPath: rightKeyPath];
            }
        }
      else
        {
          if (value)
            [self setObject: value 
                  forKey: key];
          else
            [self removeObjectForKey: key];
        }
    }
  else
    {
      if (value)
        [self setObject: value 
              forKey: keyPath];
      else
        [self removeObjectForKey: keyPath];
    }


}

@end

@implementation NSObject (EOKVCGNUstepExtensions)

/**
 * This is a GDL2 extension.  This convenience method iterates over
 * the supplied keyPaths and determines the corresponding values by invoking
 * valueForKeyPath: on the receiver.  The results are returned an NSDictionary
 * with the keyPaths as keys and the returned values as the dictionary's
 * values.  If valueForKeyPath: returns nil, it is replaced by the shared
 * EONull instance.
 */
- (NSDictionary *)valuesForKeyPaths: (NSArray *)keyPaths
{
  NSDictionary *values = nil;
  int i;
  int n;
  NSMutableArray *newKeyPaths;
  NSMutableArray *newVals;

  INITIALIZE;



  n = [keyPaths count];
  newKeyPaths = AUTORELEASE([[NSMutableArray alloc] initWithCapacity: n]);
  newVals = AUTORELEASE([[NSMutableArray alloc] initWithCapacity: n]);

  for (i = 0; i < n; i++)
    {
      id keyPath = [keyPaths objectAtIndex: i];
      id val = nil;

      NS_DURING //DEBUG Only ?
        {
          val = [self valueForKeyPath: keyPath];
        }
      NS_HANDLER
        {
          NSLog(@"KVC:%@ EXCEPTION %@",
		NSStringFromSelector(_cmd), localException);
          NSDebugMLog(@"KVC:%@ EXCEPTION %@",
		NSStringFromSelector(_cmd), localException);
          [localException raise];
        }
      NS_ENDHANDLER;

      if (val == nil)
	{
	  val = GDL2_EONull;
	}

      [newKeyPaths addObject: keyPath];
      [newVals addObject: val];
    }
  
  values = [NSDictionary dictionaryWithObjects: newVals
			 forKeys: newKeyPaths];



  return values;
}

/**
 * This is a GDL2 extension.  This convenience method retrieves the object
 * obtained by invoking valueForKey: on each path component until the one
 * next to the last.  It then invokes takeStoredValue:forKey: on that object
 * with the last path component as the key.
 */
- (void)takeStoredValue: value 
             forKeyPath: (NSString *)key
{
  NSArray *pathArray;
  NSString *path;
  id obj = self;
  int i, count;



  pathArray = [key componentsSeparatedByString:@"."];
  count = [pathArray count];

  for (i = 0; i < (count - 1); i++)
    {
      path = [pathArray objectAtIndex: i];
      obj = [obj valueForKey: path];
    }

  path = [pathArray lastObject];
  [obj takeStoredValue: value forKey: path];


}

/**
 * This is a GDL2 extension.  This convenience method retrieves the object
 * obtained by invoking valueForKey: on each path component until the one
 * next to the last.  It then invokes storedValue:forKey: on that object
 * with the last path component as the key, returning the result.
 */
- (id)storedValueForKeyPath: (NSString *)key
{
  NSArray *pathArray = nil;
  NSString *path;
  id obj = self;
  int i, count;

  pathArray = [key componentsSeparatedByString:@"."];
  count = [pathArray count];

  for(i=0; i < (count-1); i++)
    {
      path = [pathArray objectAtIndex:i];
      obj = [obj valueForKey:path];
    }

  path = [pathArray lastObject];
  obj=[obj storedValueForKey:path];

  return obj;
}

/**
 * This is a GDL2 extension.  This convenience method iterates over
 * the supplied keyPaths and determines the corresponding values by invoking
 * storedValueForKeyPath: on the receiver.  The results are returned an
 * NSDictionary with the keyPaths as keys and the returned values as the
 * dictionary's values.  If storedValueForKeyPath: returns nil, it is replaced
 * by the shared EONull instance.
 */
- (NSDictionary *)storedValuesForKeyPaths: (NSArray *)keyPaths
{
  NSDictionary *values = nil;
  int i, n;
  NSMutableArray *newKeyPaths = nil;
  NSMutableArray *newVals = nil;

  INITIALIZE;



  n = [keyPaths count];

  newKeyPaths = [[[NSMutableArray alloc] initWithCapacity: n] 
			      autorelease];
  newVals = [[[NSMutableArray alloc] initWithCapacity: n] 
			      autorelease];

  for (i = 0; i < n; i++)
    {
      id keyPath = [keyPaths objectAtIndex: i];
      id val = nil;

      NS_DURING //DEBUG Only ?
        {
          val = [self storedValueForKeyPath: keyPath];
        }
      NS_HANDLER
        {
          NSLog(@"EXCEPTION %@", localException);
          NSDebugMLog(@"EXCEPTION %@", localException);              
          [localException raise];
        }
      NS_ENDHANDLER;
        
      if (val == nil)
	val = GDL2_EONull;
      
      [newKeyPaths addObject: keyPath];
      [newVals addObject: val];
    }
  
  values = [NSDictionary dictionaryWithObjects: newVals
			 forKeys: newKeyPaths];


  return values;
}

/**
 * This is a GDL2 extension.  Simply invokes takeValue:forKey:.
 * This method provides a hook for EOGenericRecords KVC implementation,
 * which takes relationship definitions into account.
 */
- (void)smartTakeValue: (id)anObject 
                forKey: (NSString *)aKey
{
  [self takeValue: anObject
        forKey: aKey];
}

/**
 * This is a GDL2 extension.  This convenience method invokes
 * smartTakeValue:forKeyPath on the object returned by valueForKey: with
 * the first path component. 
 * obtained by invoking valueForKey: on each path component until the one
 * next to the last.  It then invokes storedValue:forKey: on that object
 * with the last path component as the key, returning the result.
 */
- (void)smartTakeValue: (id)anObject 
            forKeyPath: (NSString *)aKeyPath
{
  NSRange r = [aKeyPath rangeOfString: @"."];

  if (r.length == 0)
    {
      [self smartTakeValue: anObject 
            forKey: aKeyPath];
    }
  else
    {
      NSString *key = [aKeyPath substringToIndex: r.location];
      NSString *path = [aKeyPath substringFromIndex: NSMaxRange(r)];

      [[self valueForKey: key] smartTakeValue: anObject 
                               forKeyPath: path];
    }
}


@end
