/** Implementation of DKArgument class for boxing and unboxing D-Bus types.
   Copyright (C) 2010 Free Software Foundation, Inc.

   Written by:  Niels Grewe <niels.grewe@halbordnung.de>
   Created: June 2010

   This library is free software; you can redistribute it and/or
   modify it under the terms of the GNU Lesser General Public
   License as published by the Free Software Foundation; either
   version 2 of the License, or (at your option) any later version.

   This library is distributed in the hope that it will be useful,
   but WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
   Library General Public License for more details.

   You should have received a copy of the GNU Lesser General Public
   License along with this library; if not, write to the Free
   Software Foundation, Inc., 51 Franklin Street, Fifth Floor,
   Boston, MA 02111 USA.

   <title>DKArgument class reference</title>
   */

#import <Foundation/NSArray.h>
#import <Foundation/NSDebug.h>
#import <Foundation/NSException.h>
#import <Foundation/NSEnumerator.h>
#import <Foundation/NSString.h>
#import <Foundation/NSValue.h>
#import <GNUstepBase/NSDebug+GNUstepBase.h>
#import "DBusKit/DKProxy.h"
#import "DKEndpoint.h"
#import "DKArgument.h"

#include <dbus/dbus.h>

NSString *DKArgumentDirectionIn = @"in";
NSString *DKArgumentDirectionOut = @"out";



static Class
DKObjCClassForDBusType(int type)
{
  switch (type)
  {
    case DBUS_TYPE_BYTE:
    case DBUS_TYPE_BOOLEAN:
    case DBUS_TYPE_INT16:
    case DBUS_TYPE_UINT16:
    case DBUS_TYPE_INT32:
    case DBUS_TYPE_UINT32:
    case DBUS_TYPE_INT64:
    case DBUS_TYPE_UINT64:
    case DBUS_TYPE_DOUBLE:
      return [NSNumber class];
    case DBUS_TYPE_STRING:
      return [NSString class];
    case DBUS_TYPE_OBJECT_PATH:
      return [DKProxy class];
    case DBUS_TYPE_SIGNATURE:
      return [DKArgument class];
    // Some DBUS_TYPE_ARRAYs will actually be dictionaries if they contain
    // DBUS_TYPE_DICT_ENTRies.
    case DBUS_TYPE_ARRAY:
    case DBUS_TYPE_STRUCT:
      return [NSArray class];
    // The following types have no explicit representation, they will either not
    // be handled at all, or their boxing is determined by the container resp.
    // the contained type.
    case DBUS_TYPE_INVALID:
    case DBUS_TYPE_VARIANT:
    case DBUS_TYPE_DICT_ENTRY:
    default:
      break;
  }
  return Nil;
}

static char*
DKUnboxedObjCTypeForDBusType(int type)
{
  switch (type)
  {
    case DBUS_TYPE_BYTE:
      return @encode(char);
    case DBUS_TYPE_BOOLEAN:
      return @encode(BOOL);
    case DBUS_TYPE_INT16:
      return @encode(int16_t);
    case DBUS_TYPE_UINT16:
      return @encode(uint16_t);
    case DBUS_TYPE_INT32:
      return @encode(int32_t);
    case DBUS_TYPE_UINT32:
      return @encode(uint32_t);
    case DBUS_TYPE_INT64:
      return @encode(int64_t);
    case DBUS_TYPE_UINT64:
      return @encode(uint64_t);
    case DBUS_TYPE_DOUBLE:
      return @encode(double);
    case DBUS_TYPE_STRING:
      return @encode(char*);
    // We always box the following types:
    case DBUS_TYPE_OBJECT_PATH:
    case DBUS_TYPE_ARRAY:
    case DBUS_TYPE_STRUCT:
    case DBUS_TYPE_VARIANT:
      return @encode(id);
    // And because we do, the following types will never appear in a signature:
    case DBUS_TYPE_INVALID:
    case DBUS_TYPE_SIGNATURE:
    case DBUS_TYPE_DICT_ENTRY:
    default:
      return '\0';
  }
  return '\0';
}
static size_t
DKUnboxedObjCTypeSizeForDBusType(int type)
{
  switch (type)
  {
    case DBUS_TYPE_BYTE:
      return sizeof(char);
    case DBUS_TYPE_BOOLEAN:
      return sizeof(BOOL);
    case DBUS_TYPE_INT16:
      return sizeof(int16_t);
    case DBUS_TYPE_UINT16:
      return sizeof(uint16_t);
    case DBUS_TYPE_INT32:
      return sizeof(int32_t);
    case DBUS_TYPE_UINT32:
      return sizeof(uint32_t);
    case DBUS_TYPE_INT64:
      return sizeof(int64_t);
    case DBUS_TYPE_UINT64:
      return sizeof(uint64_t);
    case DBUS_TYPE_DOUBLE:
      return sizeof(double);
    case DBUS_TYPE_STRING:
      return sizeof(char*);
    // We always box the following types:
    case DBUS_TYPE_OBJECT_PATH:
    case DBUS_TYPE_ARRAY:
    case DBUS_TYPE_STRUCT:
    case DBUS_TYPE_VARIANT:
      return sizeof(id);
    // And because we do, the following types will never appear in a signature:
    case DBUS_TYPE_INVALID:
    case DBUS_TYPE_SIGNATURE:
    case DBUS_TYPE_DICT_ENTRY:
    default:
      return 0;
  }
  return 0;
}

/*
 * Expose DKProxy privates that we need to access.
 */
@interface DKProxy (Private)
- (NSString*)_path;
- (NSString*)_service;
- (DKEndpoint*)_endpoint;
@end

/**
 *  DKArgument encapsulates D-Bus argument information
 */
@implementation DKArgument
- (id) initWithIterator: (DBusSignatureIter*)iterator
                   name: (NSString*)_name
                 parent: (id)_parent
{
  if (nil == (self = [super init]))
  {
    return nil;
  }

  DBusType = dbus_signature_iter_get_current_type(iterator);

  if ((dbus_type_is_container(DBusType))
    && (![self isKindOfClass: [DKContainerTypeArgument class]]))
  {
    NSDebugMLog(@"Incorrectly initalized a non-container argument with a container type, reinitializing as container type.");
    [self release];
    return [[DKContainerTypeArgument alloc] initWithIterator: iterator
                                                        name: _name
                                                      parent: _parent];
  }
  ASSIGNCOPY(name, _name);
  objCEquivalent = DKObjCClassForDBusType(DBusType);
  parent = _parent;
  return self;
}

- (id)initWithDBusSignature: (const char*)DBusTypeString
                       name: (NSString*)_name
                     parent: (id)_parent
{
  DBusSignatureIter myIter;
  if (!dbus_signature_validate_single(DBusTypeString, NULL))
  {
    NSWarnMLog(@"Not a single D-Bus type signature ('%s'), ignoring argument", DBusTypeString);
    [self release];
    return nil;
  }

  dbus_signature_iter_init(&myIter, DBusTypeString);
  return [self initWithIterator: &myIter
                           name: _name
                         parent: _parent];
}



- (void)setObjCEquivalent: (Class)class
{
  objCEquivalent = class;
}

- (Class) objCEquivalent
{
  return objCEquivalent;
}

- (int) DBusType
{
  return DBusType;
}

- (NSString*)name
{
  return name;
}

- (NSString*) DBusTypeSignature
{
  return [NSString stringWithCharacters: (unichar*)&DBusType length: 1];

}

- (char*) unboxedObjCTypeChar
{
  return DKUnboxedObjCTypeForDBusType(DBusType);
}

- (size_t)unboxedObjCTypeSize
{
  return DKUnboxedObjCTypeSizeForDBusType(DBusType);
}
- (BOOL) isContainerType
{
  return NO;
}

- (id) parent
{
  return parent;
}

/**
 * This method returns the root ancestor in the method/arugment tree if it is a
 * proxy. Otherwise it returns nil. This information is needed for boxing and
 * unboxing values that depend on the object to which a method is associated
 * (i.e. object paths).
 */
- (DKProxy*)proxyParent
{
  id ancestor = [self parent];
  do
  {
    if ([ancestor isKindOfClass: [DKProxy class]])
    {
      return ancestor;
    }
    else if (![ancestor respondsToSelector: @selector(parent)])
    {
      return nil;
    }
  } while (nil != (ancestor = [ancestor parent]));

  return nil;
}


- (BOOL) unboxValue: (id)value
         intoBuffer: (long long*)buffer
{
  switch (DBusType)
  {
    case DBUS_TYPE_BYTE:
       if ([value respondsToSelector: @selector(unsignedCharValue)])
       {
	 *buffer = [value unsignedCharValue];
         return YES;
       }
       break;
    case DBUS_TYPE_BOOLEAN:
       if ([value respondsToSelector: @selector(boolValue)])
       {
	 *buffer = [value boolValue];
	 return YES;
       }
       break;
    case DBUS_TYPE_INT16:
       if ([value respondsToSelector: @selector(shortValue)])
       {
	 *buffer = [value shortValue];
	 return YES;
       }
       break;
    case DBUS_TYPE_INT32:
       if ([value respondsToSelector: @selector(intValue)])
       {
	 *buffer = [value intValue];
	 return YES;
       }
       break;
    case DBUS_TYPE_UINT16:
       if ([value respondsToSelector: @selector(unsignedShortValue)])
       {
	 *buffer = [value unsignedShortValue];
	 return YES;
       }
       break;
    case DBUS_TYPE_UINT32:
       if ([value respondsToSelector: @selector(unsignedIntValue)])
       {
	 *buffer = [value unsignedIntValue];
	 return YES;
       }
       break;
    case DBUS_TYPE_INT64:
       if ([value respondsToSelector: @selector(longLongValue)])
       {
	 *buffer = [value longLongValue];
	 return YES;
       }
       break;
    case DBUS_TYPE_UINT64:
       if ([value respondsToSelector: @selector(unsignedLongLongValue)])
       {
	 *buffer = [value unsignedLongLongValue];
	 return YES;
       }
       break;
    case DBUS_TYPE_DOUBLE:
       if ([value respondsToSelector: @selector(doubleValue)])
       {
	 union fpAndLLRep
	 {
           long long buf;
	   double val;
	 } rep;
	 rep.val = [value doubleValue];
	 *buffer = rep.buf;
	 return YES;
       }
       break;
    case DBUS_TYPE_STRING:
       if ([value respondsToSelector: @selector(UTF8String)])
       {
	 *buffer = (uintptr_t)[value UTF8String];
	 return YES;
       }
       break;
    case DBUS_TYPE_OBJECT_PATH:
    if ([value isKindOfClass: [DKProxy class]])
    {
      /*
       * We need to make sure that the paths are from the same proxy, because
       * that is the widest scope in which they are valid.
       */
      if ([[self proxyParent] hasSameScopeAs: value])
      {
        *buffer = (uintptr_t)[[value _path] UTF8String];
        return YES;
      }
    }
    break;
    case DBUS_TYPE_SIGNATURE:
      if ([value respondsToSelector: @selector(DBusTypeSignature)])
      {
	*buffer = (uintptr_t)[[value DBusTypeSignature] UTF8String];
	return YES;
      }
      break;
    default:
      break;
  }
  return NO;
}

- (id) boxedValueForValueAt: (void*)buffer
{
  switch (DBusType)
  {
    case DBUS_TYPE_BYTE:
      return [objCEquivalent numberWithUnsignedChar: *(unsigned char*)buffer];
    case DBUS_TYPE_BOOLEAN:
      return [objCEquivalent numberWithBool: *(BOOL*)buffer];
    case DBUS_TYPE_INT16:
      return [objCEquivalent numberWithShort: *(int16_t*)buffer];
    case DBUS_TYPE_UINT16:
      return [objCEquivalent numberWithUnsignedShort: *(uint16_t*)buffer];
    case DBUS_TYPE_INT32:
      return [objCEquivalent numberWithInt: *(int32_t*)buffer];
    case DBUS_TYPE_UINT32:
      return [objCEquivalent numberWithUnsignedInt: *(uint32_t*)buffer];
    case DBUS_TYPE_INT64:
      return [objCEquivalent numberWithLongLong: *(int64_t*)buffer];
    case DBUS_TYPE_UINT64:
      return [objCEquivalent numberWithUnsignedLongLong: *(uint64_t*)buffer];
    case DBUS_TYPE_DOUBLE:
      return [objCEquivalent numberWithDouble: *(double*)buffer];
    case DBUS_TYPE_STRING:
      return [objCEquivalent stringWithUTF8String: *(char**)buffer];
    case DBUS_TYPE_OBJECT_PATH:
    {
      /*
       * To handle object-paths, we follow the argument/method tree back to the
       * proxy where it was created and create a new proxy with the proper
       * settings.
       */
      DKProxy *ancestor = [self proxyParent];
      NSString *service = [ancestor _service];
      DKEndpoint *endpoint = [ancestor _endpoint];
      NSString *path = [[NSString alloc] initWithUTF8String: *(char**)buffer];
      DKProxy *newProxy = [objCEquivalent proxyWithEndpoint: endpoint
	                                         andService: service
	                                            andPath: path];
      [path release];
      return newProxy;
    }
    case DBUS_TYPE_SIGNATURE:
      return [[[objCEquivalent alloc] initWithDBusSignature: *(char**)buffer
                                                       name: nil
                                                     parent: nil] autorelease];
    default:
      return nil;
  }
  return nil;
}
- (void)dealloc
{
  parent = nil;
  [name release];
  [super dealloc];
}
@end

@implementation DKContainerTypeArgument

- (id)initWithIterator: (DBusSignatureIter*)iterator
                  name: (NSString*)_name
                parent: (id)_parent
{
  DBusSignatureIter subIterator;
  if (nil == (self = [super initWithIterator: iterator
                                        name: _name
                                      parent: _parent]))
  {
    return nil;
  }
  children = [[NSMutableArray alloc] init];

  /*
   * Shortcut needed for variant types. libdbus classifies them as containers,
   * but it is clearly wrong about that: They have no children and dbus will
   * fail and crash if it tries to loop over their non-existent sub-arguments.
   */
  if (DBUS_TYPE_VARIANT == DBusType)
  {
    return self;
  }

  /*
   * Create an iterator for the immediate subarguments of this argument and loop
   * over it until we have all the constituent types.
   */
  dbus_signature_iter_recurse(iterator, &subIterator);
  do
  {
    Class childClass = Nil;
    DKArgument *subArgument = nil;
    int subType = dbus_signature_iter_get_current_type(&subIterator);

    if (dbus_type_is_container(subType))
    {
       childClass = [DKContainerTypeArgument class];
    }
    else
    {
      childClass = [DKArgument class];
    }

    subArgument = [[childClass alloc] initWithIterator: &subIterator
                                                  name: _name
                                                parent: self];
    if (subArgument)
    {
      [children addObject: subArgument];
      [subArgument release];
    }
  } while (dbus_signature_iter_next(&subIterator));

  /* Be smart: If we are ourselves of DBUS_TYPE_DICT_ENTRY, then a
   * DBUS_TYPE_ARRAY argument above us is actually a dictionary, so we set the
   * type accordingly.
   */
  if (DBUS_TYPE_DICT_ENTRY == DBusType)
  {
    if ([parent isKindOfClass: [DKArgument class]])
    {
      if (DBUS_TYPE_ARRAY == [(id)parent DBusType])
      {
        [(id)parent setObjCEquivalent: [NSDictionary class]];
      }
    }
  }
  return self;
}

/*
 * All container types are boxed.
 */
- (char*) unboxedObjCTypeChar
{
  return @encode(id);
}

- (size_t) unboxedObjCTypeSize
{
  return sizeof(id);
}

- (id) boxedValueForValueAt: (void*)buffer
{
  // It is a bad idea to try this on a container type.
  [self shouldNotImplement: _cmd];
  return nil;
}

- (id) boxedValueByUsingIterator: (DBusMessageIter*)iterator
{
  // This assumes that the iterator has just entered the container and our ivars
  // are all correct.
  if ((DBUS_TYPE_ARRAY == DBusType) && ([NSArray class] == objCEquivalent))
  {
    NSMutableArray *box = [NSMutableArray new];
    [box release];
  }
  //TODO: Implement.
  return nil;
}

- (NSString*) DBusTypeSignature
{
  NSMutableString *sig = [[NSMutableString alloc] init];
  NSString *ret = nil;
  // [[children fold] stringByAppendingString: @""]
  NSEnumerator *enumerator = [children objectEnumerator];
  DKArgument *subArg = nil;
  while (nil != (subArg = [enumerator nextObject]))
  {
    [sig appendString: [subArg DBusTypeSignature]];
  }

  switch (DBusType)
  {
    case DBUS_TYPE_VARIANT:
      [sig insertString: [NSString stringWithUTF8String: DBUS_TYPE_VARIANT_AS_STRING]
                atIndex: 0];
      break;
    case DBUS_TYPE_ARRAY:
      [sig insertString: [NSString stringWithUTF8String: DBUS_TYPE_ARRAY_AS_STRING]
                atIndex: 0];
      break;
    case DBUS_TYPE_STRUCT:
      [sig insertString: [NSString stringWithUTF8String: DBUS_STRUCT_BEGIN_CHAR_AS_STRING]
                                                atIndex: 0];
      [sig appendString: [NSString stringWithUTF8String: DBUS_STRUCT_END_CHAR_AS_STRING]];
      break;
    case DBUS_TYPE_DICT_ENTRY:
      [sig insertString: [NSString stringWithUTF8String: DBUS_DICT_ENTRY_BEGIN_CHAR_AS_STRING]
                                                atIndex: 0];
      [sig appendString: [NSString stringWithUTF8String: DBUS_DICT_ENTRY_END_CHAR_AS_STRING]];
      break;
    default:
      NSAssert(NO, @"Invalid D-Bus type when generating container type signature");
      break;
  }
  ret = [NSString stringWithString: sig];
  [sig release];
  return ret;
}

- (BOOL) isContainerType
{
  return YES;
}

- (NSArray*) children
{
  return children;
}

- (void) dealloc
{
  [children release];
  [super dealloc];
}
@end;
