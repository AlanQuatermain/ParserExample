//
//  TumblrParserDelegate.h
//  ParserExample
//
//  Created by Jim Dovey on 10-12-14.
//  Copyright 2010 Kobo Inc. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "AQXMLParserDelegate.h"

@interface TumblrParserDelegate : AQXMLParserDelegate
@property (nonatomic, readonly, retain) NSManagedObject * tumblog;
@property (nonatomic, retain) NSManagedObjectContext * managedObjectContext;
@end
