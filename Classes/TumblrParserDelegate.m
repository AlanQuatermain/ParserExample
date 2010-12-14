//
//  TumblrParserDelegate.m
//  ParserExample
//
//  Created by Jim Dovey on 10-12-14.
//  Copyright 2010 Kobo Inc. All rights reserved.
//

#import "TumblrParserDelegate.h"
#import "ParserExampleAppDelegate.h"

#define GetManagedObjectContext()   [(ParserExampleAppDelegate*)[[UIApplication sharedApplication] delegate] managedObjectContext]
#define GetManagedObjectModel()     [(ParserExampleAppDelegate*)[[UIApplication sharedApplication] delegate] managedObjectModel]
#define AssertEntityType(type)      NSAssert([[[self.currentPost entity] name] isEqualToString: type], @"Invalid Entity")

static inline NSManagedObject * TumblogWithName( NSString * name )
{
    NSManagedObjectContext * moc = GetManagedObjectContext();
    NSManagedObjectModel * mom = GetManagedObjectModel();
    NSFetchRequest * req = [mom fetchRequestFromTemplateWithName: @"tumblogWithName"
                                           substitutionVariables: [NSDictionary dictionaryWithObject: name forKey: @"NAME"]];
    [req setFetchLimit: 1];
    
    NSArray * result = [moc executeFetchRequest: req error: NULL];
    return ( [result lastObject] );
}

static inline NSManagedObject * PostWithID( NSString * postID )
{
    NSManagedObjectContext * moc = GetManagedObjectContext();
    NSManagedObjectModel * mom = GetManagedObjectModel();
    NSFetchRequest * req = [mom fetchRequestFromTemplateWithName: @"postWithID"
                                           substitutionVariables: [NSDictionary dictionaryWithObject: postID forKey: @"POSTID"]];
    [req setFetchLimit: 1];
    
    NSArray * result = [moc executeFetchRequest: req error: NULL];
    return ( [result lastObject] );
}

static inline NSManagedObject * TagWithName( NSString * name )
{
    NSManagedObjectContext * moc = GetManagedObjectContext();
    NSManagedObjectModel * mom = GetManagedObjectModel();
    NSFetchRequest * req = [mom fetchRequestFromTemplateWithName: @"tagWithName"
                                           substitutionVariables: [NSDictionary dictionaryWithObject: name forKey: @"NAME"]];
    [req setFetchLimit: 1];
    
    NSArray * result = [moc executeFetchRequest: req error: NULL];
    return ( [result lastObject] );
}

@interface TumblrParserDelegate ()
@property (nonatomic, readwrite, retain) NSManagedObject * tumblog;
@property (nonatomic, retain) NSManagedObject * currentPost;
@property (nonatomic, copy) NSString * photoWidth;
@end

@implementation TumblrParserDelegate

@synthesize managedObjectContext, tumblog, currentPost, photoWidth;

- (void) dealloc
{
    [managedObjectContext release];
    [tumblog release];
    [currentPost release];
    [photoWidth release];
    [super dealloc];
}

- (NSManagedObject *) tumblogWithName: (NSString *) name
{
    NSManagedObjectModel * mom = [[self.managedObjectContext persistentStoreCoordinator] managedObjectModel];
    NSFetchRequest * req = [mom fetchRequestFromTemplateWithName: @"tumblogWithName"
                                           substitutionVariables: [NSDictionary dictionaryWithObject: name forKey: @"NAME"]];
    [req setFetchLimit: 1];
    
    NSArray * result = [self.managedObjectContext executeFetchRequest: req error: NULL];
    return ( [result lastObject] );
}

- (NSManagedObject *) postWithID: (NSString *) postID
{
    NSManagedObjectModel * mom = [[self.managedObjectContext persistentStoreCoordinator] managedObjectModel];
    NSFetchRequest * req = [mom fetchRequestFromTemplateWithName: @"postWithID"
                                           substitutionVariables: [NSDictionary dictionaryWithObject: postID forKey: @"POSTID"]];
    [req setFetchLimit: 1];
    
    NSArray * result = [self.managedObjectContext executeFetchRequest: req error: NULL];
    return ( [result lastObject] );
}

- (NSManagedObject *) tagWithName: (NSString *) name
{
    NSManagedObjectModel * mom = [[self.managedObjectContext persistentStoreCoordinator] managedObjectModel];
    NSFetchRequest * req = [mom fetchRequestFromTemplateWithName: @"tagWithName"
                                           substitutionVariables: [NSDictionary dictionaryWithObject: name forKey: @"NAME"]];
    [req setFetchLimit: 1];
    
    NSArray * result = [self.managedObjectContext executeFetchRequest: req error: NULL];
    return ( [result lastObject] );
}

- (void) endTumblr
{
    [self.managedObjectContext save: NULL];
}

- (void) startTumblelogWithAttributes: (NSDictionary *) attrs
{
    NSManagedObject * obj = [self tumblogWithName: [attrs objectForKey: @"name"]];
    if ( obj == nil )
        obj = [NSEntityDescription insertNewObjectForEntityForName: @"Tumblelog"
                                            inManagedObjectContext: self.managedObjectContext];
    
    self.tumblog = obj;
    
    [self.tumblog setValue: [attrs objectForKey: @"name"] forKey: @"name"];
    [self.tumblog setValue: [attrs objectForKey: @"title"] forKey: @"title"];
    [self.tumblog setValue: [attrs objectForKey: @"timezone"] forKey: @"timezone"];
}

- (void) startPostWithAttributes: (NSDictionary *) attrs
{
    NSAssert(self.tumblog != nil, @"No tumblog encountered by parser");
    
    NSManagedObject * obj = [self postWithID: [attrs objectForKey: @"id"]];
    if ( obj == nil )
    {
        NSString * entityName = [[attrs objectForKey: @"type"] capitalizedString];
        obj = [NSEntityDescription insertNewObjectForEntityForName: entityName
                                            inManagedObjectContext: self.managedObjectContext];
    }
    
    self.currentPost = obj;
    [self.currentPost setValue: self.tumblog forKey: @"tumblelog"];
    
    [self.currentPost setValue: [attrs objectForKey: @"id"] forKey: @"postID"];
    [self.currentPost setValue: [attrs objectForKey: @"slug"] forKey: @"slug"];
    [self.currentPost setValue: [attrs objectForKey: @"format"] forKey: @"format"];
    
    // complex attributes
    @try
    {
        NSURL * url = [NSURL URLWithString: [attrs objectForKey: @"url"]];
        [self.currentPost setValue: url forKey: @"url"];
        
        NSDate * date = [NSDate dateWithTimeIntervalSince1970: [[attrs objectForKey: @"unix-timestamp"] doubleValue]];
        [self.currentPost setValue: date forKey: @"timeStamp"];
    }
    @catch ( NSException * e )
    {
        NSLog( @"Exception caught in -startPostWithAttributes:, attributes = %@", attrs );
        NSLog( @"%@, %@\n%@", [e name], [e reason], [e callStackSymbols] );
    }
}

- (void) endTag
{
    NSAssert(self.currentPost != nil, @"No post encountered by parser");
    
    NSString * name = self.characters;
    NSManagedObject * obj = [self tagWithName: name];
    if ( obj == nil )
    {
        obj = [NSEntityDescription insertNewObjectForEntityForName: @"Tag" inManagedObjectContext: self.managedObjectContext];
        [obj setValue: name forKey: @"name"];
    }
    
    [[self.currentPost mutableSetValueForKey: @"tags"] addObject: obj];
}

- (void) endQuoteText
{
    AssertEntityType(@"Quote");
    [self.currentPost setValue: self.characters forKey: @"text"];
}

- (void) endQuoteSource
{
    AssertEntityType(@"Quote");
    [self.currentPost setValue: self.characters forKey: @"source"];
}

- (void) endPhotoCaption
{
    AssertEntityType(@"Photo");
    [self.currentPost setValue: self.characters forKey: @"caption"];
}

- (void) startPhotoUrlWithAttributes: (NSDictionary *) attrs
{
    AssertEntityType(@"Photo");
    self.photoWidth = [attrs objectForKey: @"max-width"];
}

- (void) endPhotoUrl
{
    AssertEntityType(@"Photo");
    NSAssert(self.photoWidth != nil, @"No photo-width encountered by parser");
    NSString * key = [NSString stringWithFormat: @"url%@", self.photoWidth];
    
    @try
    {
        NSURL * url = [NSURL URLWithString: self.characters];
        [self.currentPost setValue: url forKey: key];
    }
    @catch (NSException * e)
    {
        NSLog( @"Exception caught in -endPhotoUrl" );
        NSLog( @"%@, %@\n%@", [e name], [e reason], [e callStackSymbols] );
    }
}

- (void) endRegularTitle
{
    AssertEntityType(@"Regular");
    [self.currentPost setValue: self.characters forKey: @"title"];
}

- (void) endRegularBody
{
    AssertEntityType(@"Regular");
    [self.currentPost setValue: self.characters forKey: @"body"];
}

- (void) endLinkText
{
    AssertEntityType(@"Link");
    [self.currentPost setValue: self.characters forKey: @"text"];
}

- (void) endLinkUrl
{
    AssertEntityType(@"Link");
    
    @try
    {
        NSURL * url = [NSURL URLWithString: self.characters];
        [self.currentPost setValue: url forKey: @"linkUrl"];
    }
    @catch (NSException * e)
    {
        NSLog( @"Exception caught in -endLinkUrl" );
        NSLog( @"%@, %@\n%@", [e name], [e reason], [e callStackSymbols] );
    }
}

- (void) endLinkDescription
{
    AssertEntityType(@"Link");
    [self.currentPost setValue: self.characters forKey: @"theDescription"];
}

- (void) endQuestion
{
    AssertEntityType(@"Answer");
    [self.currentPost setValue: self.characters forKey: @"question"];
}

- (void) endAnswer
{
    AssertEntityType(@"Answer");
    [self.currentPost setValue: self.characters forKey: @"answer"];
}

- (void) endVideoSource
{
    AssertEntityType(@"Video");
    [self.currentPost setValue: self.characters forKey: @"source"];
}

- (void) endVideoPlayer
{
    AssertEntityType(@"Video");
    [self.currentPost setValue: self.characters forKey: @"player"];
}

@end
