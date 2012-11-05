//
//  RepoCreateWindowController.h
//  QuickHub
//
//  Created by Christophe Hamerling on 24/11/11.
//  Copyright 2011 christophehamerling.com. All rights reserved.
//

#import <Cocoa/Cocoa.h>

#import "GithubOAuthClient.h"
#import "MenuController.h"

@interface RepoCreateWindowController : NSWindowController {
    GithubOAuthClient *ghClient;
    MenuController *menuController;
    
    IBOutlet NSTextField *nameField;
    IBOutlet NSTextField *descriptionField;
    IBOutlet NSTextField *homePageField;
    IBOutlet NSButton *issuesBox;
    IBOutlet NSButton *downloadBox;
    IBOutlet NSButton *wikiBox;
    IBOutlet NSButton *privateBox;
    IBOutlet NSButton *openBox;
    IBOutlet NSButton *autoInitBox;
    IBOutlet NSProgressIndicator *progress;
    IBOutlet NSButton *createButton;
    IBOutlet NSButton *cancelButton;
}

- (IBAction)createAction:(id)sender;
- (IBAction)cancelAction:(id)sender;

@property (assign) GithubOAuthClient *ghClient;
@property (assign) MenuController *menuController;

@end
