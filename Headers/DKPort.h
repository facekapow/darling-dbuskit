/** Interface for DKPort for NSConnection integration.
   Copyright (C) 2010 Free Software Foundation, Inc.

   Written by:  Niels Grewe <niels.grewe@halbordnung.de>
   Created: May 2010

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

#import <Foundation/NSPort.h>

@class DKEndpoint;

/**
 * DKPort is used by the Distributed Objects system to communicate with
 * D-Bus. Unless you have special needs, don't create DKPort instances
 * yourself, but use the interfaces provided by NSConnection instead.
 *
 * This is a class cluster that will return subclass instances connected to
 * specific busses or peers, depending on the way it is initialized. The default
 * +port message will return a port connected to the session bus.
 */
@interface DKPort: NSPort
{
  /** The endpoint doing the connection handling. */
  DKEndpoint *endpoint;

  /**
   * The remote side of the port. Will not be specified for peer-to-peer
   * connections bypassing the bus and for ports used in service connections.
   */
  NSString *remote;
}
@end

@interface DKSessionBusPort: DKPort
{
}
@end

@interface DKSystemBusPort: DKPort
{
}
@end
