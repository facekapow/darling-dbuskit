/** Implementation of the DKPorperty class encapsulating D-Bus property
    information.
   Copyright (C) 2010 Free Software Foundation, Inc.

   Written by:  Niels Grewe <niels.grewe@halbordnung.de>
   Created: September 2010

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

   */

#import "DKProperty.h"
#import "DKArgument.h"
#import "DKPropertyMethod.h"

#import <Foundation/NSString.h>

@implementation DKProperty

- (id)initWithDBusSignature: (const char*)characters
           accessAttributes: (NSString*)attributes
                       name: (NSString*)aName
                     parent: (NSString*)aParent
{
  if (nil == (self = [super initWithName: aName
                                  parent: aParent]))
  {
    return nil;
  }

  if (NULL == characters)
  {
    [self release];
    return nil;
  }
  type = [[DKArgument alloc] initWithDBusSignature: characters
                                              name: @"value"
                                            parent: self];

  /*
   * Possible attribute strings are "read" "write" and "readwrite", and since
   * both checks will return YES for "readwrite", we cover all three
   * posibilities.
   */
  if ([attributes hasPrefix: @"read"])
  {
    accessor = [[DKPropertyAccessor alloc] initWithProperty: self];
  }
  if ([attributes hasSuffix: @"write"])
  {
    mutator = [[DKPropertyMutator alloc] initWithProperty: self];
  }
  return self;
}
- (DKPropertyMutator*)mutatorMethod
{
  return mutator;
}
- (DKPropertyAccessor*)accessorMethod
{
  return accessor;
}
- (DKArgument*)type
{
  return type;
}

- (BOOL)isReadable
{
  return (nil != accessor);
}

- (BOOL)isWritable
{
  return (nil != mutator);
}

- (NSString*)interface
{
  return [parent name];
}

- (id)copyWithZone: (NSZone*)zone
{
  NSMutableString *accessString = [NSMutableString new];
  DKProperty *newNode = nil;
  if ([self isReadable])
  {
    [accessString appendString: @"read"];
  }
  if ([self isWritable])
  {
    [accessString appendString: @"write"];
  }
  newNode = [[DKProperty allocWithZone: zone] initWithDBusSignature: [[type DBusTypeSignature] UTF8String]
                                                   accessAttributes: accessString
		                                               name: name
		                                             parent: parent];
  return newNode;
}

- (void)dealloc
{
  [type release];
  [mutator release];
  [accessor release];
  [super dealloc];
}
@end
