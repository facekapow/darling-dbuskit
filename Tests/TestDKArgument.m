/* Unit tests for DKArgument
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

   */
#import <Foundation/NSArray.h>
#import <Foundation/NSDictionary.h>
#import <Foundation/NSEnumerator.h>
#import <Foundation/NSString.h>
#import <Foundation/NSValue.h>
#import <Foundation/NSXMLNode.h>

#import <UnitKit/UnitKit.h>

#import "DBusKit/DKProxy.h"
#import "DBusKit/DKPort.h"
#import "../Source/DKArgument.h"
#import "../Source/DKBoxingUtils.h"

#include <stdint.h>
#include <math.h>
#include <dbus/dbus.h>

@interface DKArgument (ExposeForTest)
/*
 * NOTE: Strictly speaking, this is only implemented by DKVariantTypeArgument.
 *
 */
- (DKArgument*) DKArgumentWithObject: (id)object;
@end

@interface CustomUnboxableObject: NSObject
{
  int32_t foo;
}
- (int32_t)myInt32Value;
@end

@implementation CustomUnboxableObject
- (id) init
{
  if (nil == (self = [super init]))
  {
    return nil;
  }
  foo = 42;
  return self;
}

- (int32_t)myInt32Value
{
  return foo;
}
@end

@interface TestDKArgument: NSObject <UKTest>
@end

static NSArray *basicSigs;
static NSDictionary *basicSigsAndClasses;

@implementation TestDKArgument
+ (void) initialize
{
  if (self == [TestDKArgument class])
  {
    basicSigs = [[NSArray alloc] initWithObjects:
      @"y", @"b", @"n", @"q", @"i", @"u", @"x", @"t", @"d", @"s", @"o", @"g", nil];
    basicSigsAndClasses = [[NSDictionary alloc] initWithObjectsAndKeys:
      [NSNumber class], @"y",
      [NSNumber class], @"b",
      [NSNumber class], @"n",
      [NSNumber class], @"q",
      [NSNumber class], @"i",
      [NSNumber class], @"u",
      [NSNumber class], @"x",
      [NSNumber class], @"t",
      [NSNumber class], @"d",
      [NSString class], @"s",
      [DKProxy class], @"o",
      [DKArgument class], @"g", nil];
  }

}


- (void)testBoxingHelperFunctions
{
  // Equal types fitting (examplary):
  UKTrue(DKDBusTypeFitsIntoObjCType(DBUS_TYPE_STRING,"*"));
  UKTrue(DKObjCTypeFitsIntoDBusType("*",DBUS_TYPE_STRING));
  UKTrue(DKDBusTypeFitsIntoObjCType(DBUS_TYPE_BYTE,"C"));
  UKTrue(DKObjCTypeFitsIntoDBusType("C",DBUS_TYPE_BYTE));

  // Smaller integers fitting into larger ones:
  UKTrue(DKObjCTypeFitsIntoDBusType("l",DBUS_TYPE_INT64));
  UKTrue(DKDBusTypeFitsIntoObjCType(DBUS_TYPE_INT32,"q"));
  UKTrue(DKObjCTypeFitsIntoDBusType("c",DBUS_TYPE_INT32));
  UKTrue(DKDBusTypeFitsIntoObjCType(DBUS_TYPE_INT16, "q"));

  // Larger integers do not fit into smaller ones:
  UKFalse(DKObjCTypeFitsIntoDBusType("q",DBUS_TYPE_INT32));
  UKFalse(DKDBusTypeFitsIntoObjCType(DBUS_TYPE_INT64,"i"));
  UKFalse(DKObjCTypeFitsIntoDBusType("i",DBUS_TYPE_INT16));
  UKFalse(DKDBusTypeFitsIntoObjCType(DBUS_TYPE_INT16, "c"));

  // Smaller unsigned integers fitting into larger signed ones:
  UKTrue(DKObjCTypeFitsIntoDBusType("I",DBUS_TYPE_INT64));
  UKTrue(DKDBusTypeFitsIntoObjCType(DBUS_TYPE_UINT32,"q"));
  UKTrue(DKObjCTypeFitsIntoDBusType("C",DBUS_TYPE_INT32));
  UKTrue(DKDBusTypeFitsIntoObjCType(DBUS_TYPE_UINT16, "q"));

  // Unsigned integers do not fit those only differing in signedness:
  UKFalse(DKObjCTypeFitsIntoDBusType("Q",DBUS_TYPE_INT64));
  UKFalse(DKDBusTypeFitsIntoObjCType(DBUS_TYPE_UINT64,"q"));
  UKFalse(DKObjCTypeFitsIntoDBusType("i",DBUS_TYPE_UINT32));
  UKFalse(DKDBusTypeFitsIntoObjCType(DBUS_TYPE_INT32, "I"));

  // Floating point values fit into larger ones, but not vice versa (NOTE: D-Bus
  // only has a double type.
  UKTrue(DKObjCTypeFitsIntoDBusType("f",DBUS_TYPE_DOUBLE));
  UKFalse(DKDBusTypeFitsIntoObjCType(DBUS_TYPE_DOUBLE,"f"));

  // Floating point types cannot be converted to integers or vice versa:
  UKFalse(DKDBusTypeFitsIntoObjCType(DBUS_TYPE_DOUBLE,"q"));
  UKFalse(DKObjCTypeFitsIntoDBusType("d", DBUS_TYPE_INT64));
  UKFalse(DKDBusTypeFitsIntoObjCType(DBUS_TYPE_INT16,"d"));
  UKFalse(DKObjCTypeFitsIntoDBusType("s", DBUS_TYPE_DOUBLE));
}

/*
 * We shall ignore arguments with an invalid signature.
 */
- (void) testRejectInvalid
{
  UKNil([[DKArgument alloc] initWithDBusSignature: "k"
                                             name: nil
                                           parent: nil]);
}

/*
 * We shall ignore arguments with multiple complete types (unless they are
 * contained somehow).
 */
- (void) testRejectMultiple
{
  UKNil([[DKArgument alloc] initWithDBusSignature: "iiu"
                                             name: nil
                                           parent: nil]);
}

- (void) testInitializerAssignments
{
  DKArgument *fakeParent = [[DKArgument alloc] initWithDBusSignature: "s"
                                                                name: nil
                                                              parent: nil];
  DKArgument *arg = [[DKArgument alloc] initWithDBusSignature: "s"
                                                         name: @"Foo"
                                                       parent: fakeParent];
  UKObjectsEqual(@"Foo",[arg name]);
  UKObjectsEqual(fakeParent, [arg parent]);
  [arg release];
  [fakeParent release];
}

- (void) testSimpleRoundtrip
{
  NSEnumerator *enumerator = [basicSigs objectEnumerator];
  NSString *sig = nil;
  while (nil != (sig = [enumerator nextObject]))
  {
    DKArgument *arg = [[DKArgument alloc] initWithDBusSignature: [sig UTF8String]
                                                          name: nil
                                                        parent: nil];
    UKObjectsEqual([arg DBusTypeSignature],sig);
    [arg release];
  }
}

- (void)testSimpleObjCEquivs
{
  NSEnumerator *enumerator = [basicSigs objectEnumerator];
  NSString *sig = nil;
  while (nil != (sig = [enumerator nextObject]))
  {
    DKArgument *arg = [[DKArgument alloc] initWithDBusSignature: [sig UTF8String]
                                                          name: nil
                                                        parent: nil];
    UKObjectsEqual([basicSigsAndClasses objectForKey: sig] ,[arg objCEquivalent]);
    [arg release];
  }
}

- (void) testArrayTypeRoundtrip
{
  DKArgument *arg = [[DKArgument alloc] initWithDBusSignature: "as"
                                                         name: nil
                                                       parent: nil];
  UKObjectsEqual([arg DBusTypeSignature], @"as");
  [arg release];
}

- (void) testArrayTypeEquiv
{
  DKArgument *arg = [[DKArgument alloc] initWithDBusSignature: "as"
                                                         name: nil
                                                       parent: nil];
  UKObjectsEqual([arg objCEquivalent], [NSArray class]);
  [arg release];
}

- (void) testStructTypeRoundtrip
{
  DKArgument *arg = [[DKArgument alloc] initWithDBusSignature: "(iiu)"
                                                         name: nil
                                                       parent: nil];
  UKObjectsEqual([arg DBusTypeSignature], @"(iiu)");
  [arg release];
}

- (void) testStructTypeEquiv
{
  DKArgument *arg = [[DKArgument alloc] initWithDBusSignature: "(iiu)"
                                                         name: nil
                                                       parent: nil];
  UKObjectsEqual([arg objCEquivalent], [NSArray class]);
  [arg release];
}

- (void) testVariantTypeRoundtrip
{
  // Yes, it is confusing that variant is a container type.
  DKArgument *arg = [[DKArgument alloc] initWithDBusSignature: "v"
                                                         name: nil
                                                       parent: nil];
  UKObjectsEqual([arg DBusTypeSignature], @"v");
  [arg release];
}

- (void) testVariantTypeEquiv
{
  DKArgument *arg = [[DKArgument alloc] initWithDBusSignature: "v"
                                                         name: nil
                                                       parent: nil];
  /* Variant types will be dynamically boxed and unboxed depending on the
   * marshalled value.
   */
  UKNil([arg objCEquivalent]);
  [arg release];
}

- (void) testDictEntryTypeRoundtrip
{
  // Dict entries don't appear on their own
  DKContainerTypeArgument *superArg = (DKContainerTypeArgument*)[[DKArgument alloc] initWithDBusSignature: "a{su}"
                                                                                                     name: nil
                                                                                                   parent: nil];
  DKArgument *arg = [[superArg children] objectAtIndex: 0];
  UKObjectsEqual(@"{su}",[arg DBusTypeSignature]);
  [superArg release];
}

- (void) testDictEntryTypeEquiv
{
  DKContainerTypeArgument *superArg = (DKContainerTypeArgument*)[[DKArgument alloc] initWithDBusSignature: "a{su}"
                                                                                                     name: nil
                                                                                                   parent: nil];
  DKArgument *arg = [[superArg children] objectAtIndex: 0];
  // They are also not supposed to carry their own ObjC equivalent class.
  UKNil([arg objCEquivalent]);
  [superArg release];
}

- (void)testXMLNode
{
  DKContainerTypeArgument *arg = (DKContainerTypeArgument*)[[DKArgument alloc] initWithDBusSignature: "a{su}"
                                                                                                name: @"foo"
                                                                                              parent: nil];
  NSXMLNode *node = [arg XMLNodeForDirection: @"in"];
  UKNotNil(node);
  UKObjectsEqual(@"foo", [[(NSXMLElement*)node attributeForName: @"name"] stringValue]);
  UKObjectsEqual(@"a{su}", [[(NSXMLElement*)node attributeForName: @"type"] stringValue]);
  UKObjectsEqual(@"in", [[(NSXMLElement*)node attributeForName: @"direction"] stringValue]);
}

- (void)testAnnotatedXMLNode
{
  DKArgument *arg = [[DKArgument alloc] initWithDBusSignature: "i"
                                                         name: @"foo"
                                                       parent: nil];
  NSXMLNode *node = nil;
  [arg setAnnotationValue: @"bar"
                   forKey: @"org.gnustep.dbuskit.test"];

  node = [arg XMLNodeForDirection: @"in"];
  UKObjectsEqual(@"foo", [[(NSXMLElement*)node attributeForName: @"name"] stringValue]);
  UKObjectsEqual(@"i", [[(NSXMLElement*)node attributeForName: @"type"] stringValue]);
  UKObjectsEqual(@"in", [[(NSXMLElement*)node attributeForName: @"direction"] stringValue]);
  UKObjectsEqual(@"annotation", [(NSXMLElement*)[node childAtIndex: 0] name]);
  UKObjectsEqual(@"org.gnustep.dbuskit.test", [[(NSXMLElement*)[node childAtIndex: 0] attributeForName: @"name"] stringValue]);
  UKObjectsEqual(@"bar", [[(NSXMLElement*)[node childAtIndex: 0] attributeForName: @"value"] stringValue]);
}

- (void) testDictionaryDetection
{
  DKArgument *arg = [[DKArgument alloc] initWithDBusSignature: "a{su}"
                                                         name: nil
                                                       parent: nil];
  UKObjectsEqual([arg objCEquivalent], [NSDictionary class]);
  [arg release];
}

- (void)testNestedTypeRoundTrip
{
  DKArgument *arg = [[DKArgument alloc] initWithDBusSignature: "(ua{s(iu)}bv)"
                                                         name: nil
                                                       parent: nil];
  UKObjectsEqual([arg DBusTypeSignature], @"(ua{s(iu)}bv)");
  [arg release];
}


- (void)testSimpleBoxingRoundtripDBusString
{
  char *foo = "Foo";
  long long buffer = 0;
  DKArgument *arg = [[DKArgument alloc] initWithDBusSignature: "s"
                                                         name: nil
                                                       parent: nil];
  id boxedFoo = [arg boxedValueForValueAt: (void*)&foo];
  UKObjectsEqual(@"Foo", boxedFoo);

  if ([arg unboxValue: boxedFoo intoBuffer: &buffer])
  {
    UKTrue(0 == strcmp(foo,(char*)(uintptr_t)buffer));
  }
  else
  {
    UKFail();
  }

  [arg release];
}

#define TEST_UNBOX_INTTYPE(x) do { \
  long long buffer = 0; \
  if ([arg unboxValue: boxedFoo intoBuffer: &buffer]) \
    { \
      UKTrue(foo == (x)buffer); \
    } \
    else \
    { \
      UKFail(); \
    } \
  } while (0)


- (void)testSimpleBoxingDBusByte
{
  unsigned char foo = 255;
  DKArgument *arg = [[DKArgument alloc] initWithDBusSignature: "y"
                                                         name: nil
                                                       parent: nil];
  id boxedFoo = [arg boxedValueForValueAt: (void*)&foo];
  UKObjectsEqual([NSNumber numberWithUnsignedChar: 255], boxedFoo);

  TEST_UNBOX_INTTYPE(unsigned char);

  [arg release];

}

- (void)testSimpleBoxingDBusBool
{
  BOOL foo = YES;
  DKArgument *arg = [[DKArgument alloc] initWithDBusSignature: "b"
                                                         name: nil
                                                       parent: nil];
  id boxedFoo = [arg boxedValueForValueAt: (void*)&foo];
  UKObjectsEqual([NSNumber numberWithBool: YES], boxedFoo);

  TEST_UNBOX_INTTYPE(BOOL);

  [arg release];

}

- (void)testSimpleBoxingDBusInt16
{
  int16_t foo = INT16_MAX;
  DKArgument *arg = [[DKArgument alloc] initWithDBusSignature: "n"
                                                         name: nil
                                                       parent: nil];
  id boxedFoo = [arg boxedValueForValueAt: (void*)&foo];
  UKObjectsEqual([NSNumber numberWithInt: INT16_MAX], boxedFoo);

  TEST_UNBOX_INTTYPE(int16_t);

  [arg release];
}

- (void)testSimpleBoxingDBusUInt16
{
  uint16_t foo = UINT16_MAX;
  DKArgument *arg = [[DKArgument alloc] initWithDBusSignature: "q"
                                                         name: nil
                                                       parent: nil];
  id boxedFoo = [arg boxedValueForValueAt: (void*)&foo];
  UKObjectsEqual([NSNumber numberWithUnsignedInt: UINT16_MAX], boxedFoo);

  TEST_UNBOX_INTTYPE(uint16_t);

  [arg release];
}

- (void)testSimpleBoxingDBusInt32
{
  int32_t foo = INT32_MAX;
  DKArgument *arg = [[DKArgument alloc] initWithDBusSignature: "i"
                                                         name: nil
                                                       parent: nil];
  id boxedFoo = [arg boxedValueForValueAt: (void*)&foo];
  UKObjectsEqual([NSNumber numberWithInt: INT32_MAX], boxedFoo);

  TEST_UNBOX_INTTYPE(int32_t);

  [arg release];
}

- (void)testSimpleBoxingDBusUInt32
{
  uint32_t foo = UINT32_MAX;
  DKArgument *arg = [[DKArgument alloc] initWithDBusSignature: "u"
                                                         name: nil
                                                       parent: nil];
  id boxedFoo = [arg boxedValueForValueAt: (void*)&foo];
  UKObjectsEqual([NSNumber numberWithUnsignedInt: UINT32_MAX], boxedFoo);

  TEST_UNBOX_INTTYPE(uint32_t);

  [arg release];
}

- (void)testSimpleBoxingDBusInt64
{
  int64_t foo = INT64_MAX;
  DKArgument *arg = [[DKArgument alloc] initWithDBusSignature: "x"
                                                         name: nil
                                                       parent: nil];
  id boxedFoo = [arg boxedValueForValueAt: (void*)&foo];
  UKObjectsEqual([NSNumber numberWithLongLong: INT64_MAX], boxedFoo);

  TEST_UNBOX_INTTYPE(int64_t);

  [arg release];
}

- (void)testSimpleBoxingDBusUInt64
{
  uint64_t foo = UINT64_MAX;
  DKArgument *arg = [[DKArgument alloc] initWithDBusSignature: "t"
                                                         name: nil
                                                       parent: nil];
  id boxedFoo = [arg boxedValueForValueAt: (void*)&foo];
  UKObjectsEqual([NSNumber numberWithUnsignedLongLong: UINT64_MAX], boxedFoo);

  TEST_UNBOX_INTTYPE(uint64_t);

  [arg release];
}

- (void)testSimpleBoxingDBusDouble
{
  double foo = 1.54E+30;
  long long buffer = 0;
  DKArgument *arg = [[DKArgument alloc] initWithDBusSignature: "d"
                                                         name: nil
                                                       parent: nil];
  id boxedFoo = [arg boxedValueForValueAt: (void*)&foo];
  UKObjectsEqual([NSNumber numberWithDouble: 1.54E+30], boxedFoo);

  if ([arg unboxValue: boxedFoo intoBuffer: &buffer])
  {
    UKFloatsEqual(foo, *(double*)&buffer, 0.0001);
  }
  else
  {
    UKFail();
  }
  [arg release];
}

- (void)testSimpleBoxingDBusSignature
{
  char *foo = "(ss)";
  long long buffer = 0;

  DKArgument *arg = [[DKArgument alloc] initWithDBusSignature: "g"
                                                         name: nil
                                                       parent: nil];
  id boxedFoo = [arg boxedValueForValueAt: (void*)&foo];
  UKObjectsEqual(@"(ss)", [boxedFoo DBusTypeSignature]);

  if ([arg unboxValue: boxedFoo intoBuffer: &buffer])
  {
    UKTrue(0 == strcmp(foo,(char*)(uintptr_t)buffer));
  }
  else
  {
    UKFail();
  }

  [arg release];
}

- (void)testSimpleBoxingDBusObjectPath
{
  char *foo = "/";
  long long buffer = 0;
  NSConnection *conn = nil;
  id initialProxy = nil;
  DKArgument *arg = nil;
  id boxedFoo = nil;

  NSWarnMLog(@"This test is an expected failure if the session message bus is not available!");
  conn = [NSConnection connectionWithReceivePort: [DKPort port]
                                        sendPort: [[DKPort alloc] initWithRemote: @"org.freedesktop.DBus"]];
  initialProxy = [conn rootProxy];
  arg = [[DKArgument alloc] initWithDBusSignature: "o"
                                             name: nil
                                           parent: initialProxy];
  boxedFoo = [arg boxedValueForValueAt: (void*)&foo];
  UKTrue([boxedFoo isKindOfClass: [DKProxy class]]);

  if ([arg unboxValue: boxedFoo intoBuffer: &buffer])
  {
    UKTrue(0 == strcmp(foo,(char*)(uintptr_t)buffer));
  }
  else
  {
    UKFail();
  }

 [arg release];
}

- (void)testCustomUnboxingSelector
{

  DKArgument *arg = [[DKArgument alloc] initWithDBusSignature: "i"
                                                         name: nil
                                                       parent: nil];
  id boxedFoo = [[CustomUnboxableObject alloc] init];
  int32_t foo = [boxedFoo myInt32Value];
  [DKArgument registerUnboxingSelector: @selector(myInt32Value)
                           forDBusType: DBUS_TYPE_INT32];
  TEST_UNBOX_INTTYPE(int32_t);
  [boxedFoo release];
  [arg release];
}

- (void)testGenerateArrayDBusSignatureForVariantType
{
  NSArray *object = [[NSArray alloc] initWithObjects: @"foo", @"bar", nil];
  NSString *theSig = @"as";
  DKArgument *variantArg = [[DKArgument alloc] initWithDBusSignature: "v"
                                                                name: nil
                                                              parent: nil];
  DKArgument *containedArg =  [variantArg DKArgumentWithObject: object];
  UKObjectsEqual(theSig, [containedArg DBusTypeSignature]);
  [object release];
}

- (void)testGenerateDictionaryDBusSignatureForVariantType
{
  NSNumber *one = [[NSNumber alloc] initWithInt: 89];
  NSNumber *two = [[NSNumber alloc] initWithInt: 5879];
  NSDictionary *object = [[NSDictionary alloc] initWithObjectsAndKeys: one, @"foo", two, @"bar", nil];
# ifdef __LP64__
  NSString *theSig = @"a{sx}";
# else
  NSString *theSig = @"a{si}";
# endif

  DKArgument *variantArg = [[DKArgument alloc] initWithDBusSignature: "v"
                                                                name: nil
                                                              parent: nil];
  DKArgument *containedArg =  [variantArg DKArgumentWithObject: object];
  UKObjectsEqual(theSig, [containedArg DBusTypeSignature]);
  [one release];
  [two release];
  [object release];
  [variantArg release];
}
- (void)testGenerateFallbackStructDBusSignatureForVariantType
{
  NSNumber *one = [[NSNumber alloc] initWithInt: 89];
  NSNumber *two = [[NSNumber alloc] initWithInt: 5879];
  NSArray *arrayOne = [[NSArray alloc] initWithObjects: one, nil];
  NSArray *arrayTwo = [[NSArray alloc] initWithObjects: two, nil];
  NSDictionary *object = [[NSDictionary alloc] initWithObjectsAndKeys: @"foo", arrayOne, @"bar", arrayTwo, nil];
# ifdef __LP64__
  NSString *theSig = @"a(axs)";
# else
  NSString *theSig = @"a(ais)";
# endif
  DKArgument *variantArg = [[DKArgument alloc] initWithDBusSignature: "v"
                                                                name: nil
                                                              parent: nil];
  DKArgument *containedArg =  [variantArg DKArgumentWithObject: object];
  UKObjectsEqual(theSig, [containedArg DBusTypeSignature]);
  [arrayOne release];
  [arrayTwo release];
  [one release];
  [two release];
  [object release];
  [variantArg release];
}

- (void)testGenerateVariantDBusSignatureForVariantType
{
  NSNumber *one = [[NSNumber alloc] initWithInt: 89];
  NSNumber *two = [[NSNumber alloc] initWithInt: 5879];
  NSArray *object = [[NSArray alloc] initWithObjects: one, @"foo", two, @"bar", nil];
  NSString *theSig = @"av";
  DKArgument *variantArg = [[DKArgument alloc] initWithDBusSignature: "v"
                                                                name: nil
                                                              parent: nil];
  DKArgument *containedArg =  [variantArg DKArgumentWithObject: object];
  UKObjectsEqual(theSig, [containedArg DBusTypeSignature]);
  [object release];
  [one release];
  [two release];
}

- (void)testNSDataArgument
{
  uint32_t fourbyte = 0xdeadbeef;
  NSData *data = [[NSData alloc] initWithBytes: (void*)&fourbyte length: 4];
  DKArgument *dataArg  = [[DKArgument alloc] initWithDBusSignature: "ay"
                                                              name: nil
                                                            parent: nil];
  [dataArg setAnnotationValue: @"NSData"
                       forKey: @"org.gnustep.objc.class"];
  DBusMessage *theMessage = NULL;
  theMessage = dbus_message_new_method_call("org.gnustep.dummy",
    "/",
    "org.gnustep.dummy",
    "Dummy");
  DBusMessageIter appendIter;
  dbus_message_iter_init_append(theMessage, &appendIter);
  [dataArg marshallObject: data intoIterator: &appendIter];
  DBusMessageIter readIter;
  dbus_message_iter_init(theMessage, &readIter);
  NSData *result = [dataArg unmarshalledObjectFromIterator: &readIter];
  uint32_t outFourbyte = 0;
  [result getBytes: (void*)&outFourbyte length: 4];
  UKIntsEqual(fourbyte, outFourbyte);
  dbus_message_unref(theMessage);
  [data release];
  [dataArg release];
}
@end
