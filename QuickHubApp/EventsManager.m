//
//  EventsManager.m
//  QuickHub
//
//  Created by Christophe Hamerling on 15/04/12.
//  Copyright 2012 __MyCompanyName__. All rights reserved.
//

#import "EventsManager.h"
#import "Preferences.h"
#import "GrowlManager.h"
#import "QHConstants.h"

@interface EventsManager (Private)
- (void) notifyNewEvent:(NSDictionary *) event;
- (BOOL) notificationActive:(NSString *) eventType;
- (BOOL) isNotificationsActive;

- (NSDictionary *) getCommit:(NSDictionary *)event;
- (NSDictionary *) getCreate:(NSDictionary *)event;
- (NSDictionary *) getDelete:(NSDictionary *)event;
- (NSDictionary *) getDownload:(NSDictionary *)event;
- (NSDictionary *) getFollow:(NSDictionary *)event;
- (NSDictionary *) getFork:(NSDictionary *)event;
- (NSDictionary *) getGist:(NSDictionary *)event;
- (NSDictionary *) getGollum:(NSDictionary *)event;
- (NSDictionary *) getIssueComment:(NSDictionary *)event;
- (NSDictionary *) getIssue:(NSDictionary *)event;
- (NSDictionary *) getMember:(NSDictionary *)event;
- (NSDictionary *) getPublic:(NSDictionary *)event;
- (NSDictionary *) getPull:(NSDictionary *)event;
- (NSDictionary *) getPullReview:(NSDictionary *)event;
- (NSDictionary *) getPush:(NSDictionary *)event;
- (NSDictionary *) getTeam:(NSDictionary *)event;
- (NSDictionary *) getWatch:(NSDictionary *)event;

- (void) updateEventMenu:(NSDictionary *)event;

@end

@implementation EventsManager

@synthesize menuController;

- (id)init
{
    self = [super init];
    if (self) {
        events = [[NSMutableArray alloc] init];
        eventIds = [[NSMutableSet alloc] init];
    }
    
    return self;
}

- (void) addEventsFromDictionary:(NSDictionary *) dict {
    BOOL firstCall = ([events count] == 0);
    
    NSMutableDictionary *arrangedEvents = [[NSMutableDictionary alloc] init];

    NSMutableSet* justGet = [[[NSMutableSet alloc] init] autorelease];
    for (NSDictionary *event in dict) {
        [justGet addObject:[event valueForKey:@"id"]];
        [arrangedEvents setObject:event forKey:[event valueForKey:@"id"]];
    }
    
    // diff events with the already cached ones
    NSMutableSet* newEvents = [NSMutableSet setWithSet:justGet];
    [newEvents minusSet:eventIds];
    
    // cache new events
    for (id eventId in newEvents) {
        [eventIds addObject:eventId];
        [events addObject:[arrangedEvents objectForKey:eventId]];
    }
    
    // TODO : Check if there is something to create array from set
    NSMutableArray *newEventsArray = [NSMutableArray arrayWithCapacity:[newEvents count]];
    for (id eventId in newEvents) {
        [newEventsArray addObject:[arrangedEvents objectForKey:eventId]];
    }
    
    // create an array with the new events and order them by date...
    NSArray *sorted = [[NSMutableArray arrayWithArray:newEventsArray] sortedArrayUsingComparator:^(id a, id b) {
        NSString *first = [a objectForKey:@"created_at"];
        NSString *second = [b objectForKey:@"created_at"];
        return [[first lowercaseString] compare:[second lowercaseString]];
    }];
        
    for (id event in sorted) {
        [self updateEventMenu:event];
    }
    
    if ([sorted count] > 0 && [self isNotificationsActive]) {
        // send some notifications...
        
        int nbEvents = 10;
        if ([sorted count] >= nbEvents) {
            // limit the number of events per configuration...
            
            if (!firstCall) {
                [[GrowlManager get] notifyWithName:@"GitHub Event" desc:[NSString stringWithFormat:@"%d new events...", [newEvents count]] url:nil icon:nil];
            }
        } else {
            // loop...
            // TODO : need to order events by date with the "created_at" element
            for (id event in sorted) {
                [self notifyNewEvent:event];
            }
        }
    }
}

- (NSArray *) getEvents {
    return events;  
}

- (void) clearEvents {
    events = [[NSMutableArray alloc] init];
    eventIds = [[NSMutableSet alloc] init];
}

- (void) notifyNewEvent:(NSDictionary *) event {
    if (!event) {
        return;
    }
    
    NSString *type = [event valueForKey:@"type"];
    
    if (!type) {
        return;
    }
        
    if ([CommitCommentEvent isEqualToString:type]) {
        
        NSString *actorLogin = [[event valueForKey:@"actor"] valueForKey:@"login"];
        NSString *repository = [[event valueForKey:@"repo"] valueForKey:@"name"];
        NSString *message = [NSString stringWithFormat:@"%@ commented on %@", actorLogin, repository];
        NSString *url = [[[event valueForKey:@"payload"] valueForKey:@"comment"] valueForKey:@"html_url"];
        
        if ([self notificationActive:GHCommitCommentEvent]) {
            [[GrowlManager get] notifyWithName:@"GitHub" desc:message url:url icon:nil];
        }
        
    } else if ([CreateEvent isEqualToString:type]) {
                
        NSString *actorLogin = [[event valueForKey:@"actor"] valueForKey:@"login"];
        NSNumber *refType = [[event valueForKey:@"payload"] valueForKey:@"ref_type"];
        NSString *repository = [[event valueForKey:@"repo"] valueForKey:@"name"];
        NSString *message = [NSString stringWithFormat:@"%@ created %@ %@", actorLogin, refType, repository];
         
        if ([self notificationActive:GHCreateEvent]) {
            [[GrowlManager get] notifyWithName:@"GitHub" desc:message url:nil iconName:@"octocat-128"];
        }
        // TODO check message format for repository, branch and tag. This one works for repository
        
    } else if ([DeleteEvent isEqualToString:type]) {
        
        NSString *actorLogin = [[event valueForKey:@"actor"] valueForKey:@"login"];
        NSNumber *refType = [[event valueForKey:@"payload"] valueForKey:@"ref_type"];
        NSString *ref = [[event valueForKey:@"payload"] valueForKey:@"ref"];
        NSString *message = [NSString stringWithFormat:@"%@ deleted %@ from %@", actorLogin, refType, ref];
        
        if ([self notificationActive:GHDeleteEvent]) {
            [[GrowlManager get] notifyWithName:@"GitHub" desc:message url:nil iconName:@"octocat-128"];
        }
        
    } else if ([DownloadEvent isEqualToString:type]) {
        
        NSString *actorLogin = [[event valueForKey:@"actor"] valueForKey:@"login"];
        NSString *filename = [[[event valueForKey:@"payload"] valueForKey:@"download"] valueForKey:@"name"];
        NSString *repository = [[event valueForKey:@"repo"] valueForKey:@"name"];
        NSString *message = [NSString stringWithFormat:@"%@ uploaded %@ to %@", actorLogin, filename, repository];
        
        if ([self notificationActive:GHDownloadEvent]) {
            [[GrowlManager get] notifyWithName:@"GitHub" desc:message url:nil iconName:@"octocat-128"];
        }

    } else if ([FollowEvent isEqualToString:type]) {
        
        NSString *actorLogin = [[event valueForKey:@"actor"] valueForKey:@"login"];
        NSString *target = [[[event valueForKey:@"payload"] valueForKey:@"target"] valueForKey:@"login"];
        NSString *message = [NSString stringWithFormat:@"%@ started following %@", actorLogin, target];
        
        if ([self notificationActive:GHFollowEvent]) {
            [[GrowlManager get] notifyWithName:@"GitHub" desc:message url:nil iconName:@"octocat-128"];
        }
        
    } else if ([ForkEvent isEqualToString:type]) {
        
        NSString *actorLogin = [[event valueForKey:@"actor"] valueForKey:@"login"];
        NSString *repository = [[event valueForKey:@"repo"] valueForKey:@"name"];
        NSString *message = [NSString stringWithFormat:@"%@ forked %@", actorLogin, repository];
        
        if ([self notificationActive:GHForkEvent]) {
            [[GrowlManager get] notifyWithName:@"GitHub" desc:message url:nil iconName:@"octocat-128"];
        }
        
    } else if ([ForkApplyEvent isEqualToString:type]) {
        
        // tested but can not find when it happens
        // forked and merged, nothing...
        /*
        NSString *actorLogin = [[event valueForKey:@"actor"] valueForKey:@"login"];
        NSString *repository = [[event valueForKey:@"repo"] valueForKey:@"name"];
        NSString *message = [NSString stringWithFormat:@"%@ applied fork %@", actorLogin, repository];
        
        if ([self notificationActive:GHForkApplyEvent]) {
            [[GrowlManager get] notifyWithName:@"GitHub" desc:message url:nil iconName:@"octocat-128"];
        }
         */
        
    } else if ([GistEvent isEqualToString:type]) {
        
        NSString *actorLogin = [[event valueForKey:@"actor"] valueForKey:@"login"];
        NSString *action = [[event valueForKey:@"payload"] valueForKey:@"action"];
        NSNumber *gistId = [[[event valueForKey:@"payload"] valueForKey:@"gist"] valueForKey:@"id"];
        NSString *message = [NSString stringWithFormat:@"%@ %@d gist %@", actorLogin, action, gistId];
        NSString *url = [[[event valueForKey:@"payload"] valueForKey:@"gist"] valueForKey:@"html_url"];
        
        if ([self notificationActive:GHGistEvent]) {
            [[GrowlManager get] notifyWithName:@"GitHub" desc:message url:url iconName:@"octocat-128"];
        }
        
    } else if ([GollumEvent isEqualToString:type]) {
        
        NSString *actorLogin = [[event valueForKey:@"actor"] valueForKey:@"login"];
        NSString *repository = [[event valueForKey:@"repo"] valueForKey:@"name"];
        NSArray *pages = [[event valueForKey:@"payload"] valueForKey:@"pages"];
        
        if ([pages count] > 1) {
            NSString *message = [NSString stringWithFormat:@"%@ modified %d pages in the %@ wiki", actorLogin, [pages count], repository];
            
            if ([self notificationActive:GHGollumEvent]) {
                [[GrowlManager get] notifyWithName:@"GitHub" desc:message url:nil iconName:@"octocat-128"];
            }

        } else {
            
            for (NSDictionary *page in pages) {
                NSString *pageName = [page valueForKey:@"page_name"];
                NSString *action = [page valueForKey:@"action"];
                NSString *message = [NSString stringWithFormat:@"%@ %@ the %@ wiki page %@", actorLogin, action, repository, pageName];
                
                if ([self notificationActive:GHGollumEvent]) {
                    [[GrowlManager get] notifyWithName:@"GitHub" desc:message url:nil iconName:@"octocat-128"];
                }
            }
        }
        
    } else if ([IssueCommentEvent isEqualToString:type]) {
        
        NSString *actorLogin = [[event valueForKey:@"actor"] valueForKey:@"login"];
        NSString *action = [[event valueForKey:@"payload"] valueForKey:@"action"];
        NSNumber *issueId = [[[event valueForKey:@"payload"] valueForKey:@"issue"] valueForKey:@"number"];
        NSString *repository = [[event valueForKey:@"repo"] valueForKey:@"name"];
        NSString *message = [NSString stringWithFormat:@"%@ %@ comment on issue %@ on %@", actorLogin, action, issueId, repository];
        NSString *url = [[[event valueForKey:@"payload"] valueForKey:@"issue"] valueForKey:@"html_url"];
        
        if ([self notificationActive:GHIssueCommentEvent]) {
            [[GrowlManager get] notifyWithName:@"GitHub" desc:message url:url iconName:@"octocat-128"];
        }
        
    } else if ([IssuesEvent isEqualToString:type]) {
        
        NSString *actorLogin = [[event valueForKey:@"actor"] valueForKey:@"login"];
        NSString *action = [[event valueForKey:@"payload"] valueForKey:@"action"];
        NSNumber *issueId = [[[event valueForKey:@"payload"] valueForKey:@"issue"] valueForKey:@"number"];
        NSString *repository = [[event valueForKey:@"repo"] valueForKey:@"name"];
        NSString *message = [NSString stringWithFormat:@"%@ %@ issue %@ on %@", actorLogin, action, issueId, repository];
        NSString *url = [[[event valueForKey:@"payload"] valueForKey:@"issue"] valueForKey:@"html_url"];
        
        if ([self notificationActive:GHIssuesEvent]) {
            [[GrowlManager get] notifyWithName:@"GitHub" desc:message url:url iconName:@"octocat-128"];
        }
        
    } else if ([MemberEvent isEqualToString:type]) {

    } else if ([PublicEvent isEqualToString:type]) {
        
    } else if ([PullRequestEvent isEqualToString:type]) {
        
        NSString *actorLogin = [[event valueForKey:@"actor"] valueForKey:@"login"];
        NSString *action = [[event valueForKey:@"payload"] valueForKey:@"action"];
        NSNumber *pullrequestId = [[event valueForKey:@"payload"] valueForKey:@"number"];
        NSString *repository = [[event valueForKey:@"repo"] valueForKey:@"name"];
        NSString *message = [NSString stringWithFormat:@"%@ %@ on pull request %@ on %@", actorLogin, action, pullrequestId, repository];
        NSString *url = [[[event valueForKey:@"payload"] valueForKey:@"pull_request"] valueForKey:@"html_url"];
        
        if ([self notificationActive:GHPullRequestEvent]) {
            [[GrowlManager get] notifyWithName:@"GitHub" desc:message url:url iconName:@"octocat-128"];
        }
            
    } else if ([PullRequestReviewCommentEvent isEqualToString:type]) {

    } else if ([PushEvent isEqualToString:type]) {
        
        NSString *actorLogin = [[event valueForKey:@"actor"] valueForKey:@"login"];
        NSNumber *branch = [[event valueForKey:@"payload"] valueForKey:@"ref"];
        NSString *repository = [[event valueForKey:@"repo"] valueForKey:@"name"];
        NSString *message = [NSString stringWithFormat:@"%@ pushed to %@ at %@", actorLogin, branch, repository];
        
        if ([self notificationActive:GHPushEvent]) {
            [[GrowlManager get] notifyWithName:@"GitHub" desc:message url:nil iconName:@"octocat-128"];
        }
        
    } else if ([TeamAddEvent isEqualToString:type]) {

    } else if ([WatchEvent isEqualToString:type]) {
        
        NSString *actorLogin = [[event valueForKey:@"actor"] valueForKey:@"login"];
        NSString *action = [[event valueForKey:@"payload"] valueForKey:@"action"];
        NSString *repository = [[event valueForKey:@"repo"] valueForKey:@"name"];
        NSString *message = [NSString stringWithFormat:@"%@ %@ watching %@", actorLogin, action, repository];
        
        if ([self notificationActive:GHWatchEvent]) {
            [[GrowlManager get] notifyWithName:@"GitHub" desc:message url:nil iconName:@"octocat-128"];
        }
        
    } else {
        // NOP
    }
}

- (BOOL) notificationActive:(NSString *) eventType {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    BOOL result = YES;
    
    if ([defaults valueForKey:eventType]) {
        result = [defaults boolForKey:eventType];
    } else {
        // if not found, let's say that the notification is active...
        result = YES;
    }
    return result;
}

- (BOOL) isNotificationsActive {
    BOOL result = YES;

    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    if ([defaults valueForKey:GHEventActive]) {
        result = [defaults boolForKey:GHEventActive];
    } else {
        // if not found, let's say that the notification is active...
        result = YES;
    }
    return result;    
}

#pragma mark - Events transformation
- (NSDictionary *) getCommit:(NSDictionary *)event {
    NSMutableDictionary *dict = [NSMutableDictionary dictionaryWithCapacity:2];
    
    NSString *actorLogin = [[event valueForKey:@"actor"] valueForKey:@"login"];
    NSString *repository = [[event valueForKey:@"repo"] valueForKey:@"name"];
    NSString *message = [NSString stringWithFormat:@"%@ commented commit on %@", actorLogin, repository];
    NSString *url = [[[event valueForKey:@"payload"] valueForKey:@"comment"] valueForKey:@"html_url"];
    NSString *details = [NSString stringWithFormat:@"Comment on L%@: %@", [[[event valueForKey:@"payload"] valueForKey:@"comment"] valueForKey:@"line"], [[[event valueForKey:@"payload"] valueForKey:@"comment"] valueForKey:@"body"]];

    [dict setValue:message forKey:@"message"];
    [dict setValue:url forKey:@"url"];
    [dict setValue:details forKey:@"details"];
    
    return dict;
}

- (NSDictionary *) getCreate:(NSDictionary *)event{
    NSMutableDictionary *dict = [NSMutableDictionary dictionaryWithCapacity:2];
        
    NSString *actorLogin = [[event valueForKey:@"actor"] valueForKey:@"login"];
    NSNumber *refType = [[event valueForKey:@"payload"] valueForKey:@"ref_type"];
    NSString *repository = [[event valueForKey:@"repo"] valueForKey:@"name"];
    NSString *message = [NSString stringWithFormat:@"%@ created %@ %@", actorLogin, refType, repository];
    
    [dict setValue:message forKey:@"message"];
    
    return dict;    
}

- (NSDictionary *) getDelete:(NSDictionary *)event{
    NSMutableDictionary *dict = [NSMutableDictionary dictionaryWithCapacity:2];
    
    NSString *actorLogin = [[event valueForKey:@"actor"] valueForKey:@"login"];
    NSNumber *refType = [[event valueForKey:@"payload"] valueForKey:@"ref_type"];
    NSString *ref = [[event valueForKey:@"payload"] valueForKey:@"ref"];
    NSString *message = [NSString stringWithFormat:@"%@ deleted %@ from %@", actorLogin, refType, ref];
    
    [dict setValue:message forKey:@"message"];
    
    return dict;
}

- (NSDictionary *) getDownload:(NSDictionary *)event{
    NSMutableDictionary *dict = [NSMutableDictionary dictionaryWithCapacity:2];
    
    NSString *actorLogin = [[event valueForKey:@"actor"] valueForKey:@"login"];
    NSString *filename = [[[event valueForKey:@"payload"] valueForKey:@"download"] valueForKey:@"name"];
    NSString *repository = [[event valueForKey:@"repo"] valueForKey:@"name"];
    NSString *message = [NSString stringWithFormat:@"%@ uploaded %@ to %@", actorLogin, filename, repository];
    
    [dict setValue:message forKey:@"message"];
    
    return dict;
}

- (NSDictionary *) getFollow:(NSDictionary *)event{
    NSMutableDictionary *dict = [NSMutableDictionary dictionaryWithCapacity:2];
    
    NSString *actorLogin = [[event valueForKey:@"actor"] valueForKey:@"login"];
    NSString *target = [[[event valueForKey:@"payload"] valueForKey:@"target"] valueForKey:@"login"];
    NSString *message = [NSString stringWithFormat:@"%@ started following %@", actorLogin, target];
    
    [dict setValue:message forKey:@"message"];
    
    return dict;
}

- (NSDictionary *) getFork:(NSDictionary *)event{
    NSMutableDictionary *dict = [NSMutableDictionary dictionaryWithCapacity:2];
        
    NSString *actorLogin = [[event valueForKey:@"actor"] valueForKey:@"login"];
    NSString *repository = [[event valueForKey:@"repo"] valueForKey:@"name"];
    NSString *message = [NSString stringWithFormat:@"%@ forked %@", actorLogin, repository]; 
    NSString *details = [NSString stringWithFormat:@"Forked repository is at %@", [[[event valueForKey:@"payload"] valueForKey:@"forkee"] valueForKey:@"name"]];
    NSString *url = [[[event valueForKey:@"payload"] valueForKey:@"forkee"] valueForKey:@"html_url"];
    
    [dict setValue:message forKey:@"message"];
    [dict setValue:details forKey:@"details"];
    [dict setValue:url forKey:@"url"];
    
    return dict;
}

- (NSDictionary *) getGist:(NSDictionary *)event{
    NSMutableDictionary *dict = [NSMutableDictionary dictionaryWithCapacity:2];
    
    NSString *actorLogin = [[event valueForKey:@"actor"] valueForKey:@"login"];
    NSString *action = [[event valueForKey:@"payload"] valueForKey:@"action"];
    NSNumber *gistId = [[[event valueForKey:@"payload"] valueForKey:@"gist"] valueForKey:@"id"];
    NSString *message = [NSString stringWithFormat:@"%@ %@d gist %@", actorLogin, action, gistId];
    NSString *url = [[[event valueForKey:@"payload"] valueForKey:@"gist"] valueForKey:@"html_url"];
    
    [dict setValue:message forKey:@"message"];
    [dict setValue:url forKey:@"url"];
    
    return dict;
}

- (NSDictionary *) getGollum:(NSDictionary *)event{
    NSMutableDictionary *dict = [NSMutableDictionary dictionaryWithCapacity:2];
    
    NSString *actorLogin = [[event valueForKey:@"actor"] valueForKey:@"login"];
    NSString *repository = [[event valueForKey:@"repo"] valueForKey:@"name"];
    NSArray *pages = [[event valueForKey:@"payload"] valueForKey:@"pages"];
    
    NSString *message = nil;
    
    if ([pages count] > 1) {
        message = [NSString stringWithFormat:@"%@ modified %d pages in the %@ wiki", actorLogin, [pages count], repository];
        
    } else {
        
        for (NSDictionary *page in pages) {
            NSString *pageName = [page valueForKey:@"page_name"];
            NSString *action = [page valueForKey:@"action"];
            message = [NSString stringWithFormat:@"%@ %@ the %@ wiki page %@", actorLogin, action, repository, pageName];
        }
    }
    
    [dict setValue:message forKey:@"message"];
    
    return dict;
}

- (NSDictionary *) getIssueComment:(NSDictionary *)event{
    NSMutableDictionary *dict = [NSMutableDictionary dictionaryWithCapacity:2];
    
    NSString *actorLogin = [[event valueForKey:@"actor"] valueForKey:@"login"];
    NSString *action = [[event valueForKey:@"payload"] valueForKey:@"action"];
    NSNumber *issueId = [[[event valueForKey:@"payload"] valueForKey:@"issue"] valueForKey:@"number"];
    NSString *repository = [[event valueForKey:@"repo"] valueForKey:@"name"];
    NSString *message = [NSString stringWithFormat:@"%@ %@ comment on issue %@ on %@", actorLogin, action, issueId, repository];
    NSString *url = [[[event valueForKey:@"payload"] valueForKey:@"issue"] valueForKey:@"html_url"];
    NSString *details = [NSString stringWithFormat:@"%@", [[[event valueForKey:@"payload"] valueForKey:@"comment"] valueForKey:@"body"]];
    
    [dict setValue:message forKey:@"message"];
    [dict setValue:url forKey:@"url"];
    [dict setValue:details forKey:@"details"];
    
    return dict;
}

- (NSDictionary *) getIssue:(NSDictionary *)event{
    NSMutableDictionary *dict = [NSMutableDictionary dictionaryWithCapacity:2];
    
    NSString *actorLogin = [[event valueForKey:@"actor"] valueForKey:@"login"];
    NSString *action = [[event valueForKey:@"payload"] valueForKey:@"action"];
    NSNumber *issueId = [[[event valueForKey:@"payload"] valueForKey:@"issue"] valueForKey:@"number"];
    NSString *repository = [[event valueForKey:@"repo"] valueForKey:@"name"];
    NSString *message = [NSString stringWithFormat:@"%@ %@ issue %@ on %@", actorLogin, action, issueId, repository];
    NSString *url = [[[event valueForKey:@"payload"] valueForKey:@"issue"] valueForKey:@"html_url"];
    NSString *details = [NSString stringWithFormat:@"%@", [[[event valueForKey:@"payload"] valueForKey:@"issue"] valueForKey:@"title"]];
    
    [dict setValue:message forKey:@"message"];
    [dict setValue:url forKey:@"url"];
    [dict setValue:details forKey:@"details"];
    
    return dict;
}

- (NSDictionary *) getMember:(NSDictionary *)event{
    return [NSMutableDictionary dictionary];
}

- (NSDictionary *) getPublic:(NSDictionary *)event{
    return [NSMutableDictionary dictionary];    
}

- (NSDictionary *) getPull:(NSDictionary *)event{
    NSMutableDictionary *dict = [NSMutableDictionary dictionaryWithCapacity:2];
    
    NSString *actorLogin = [[event valueForKey:@"actor"] valueForKey:@"login"];
    NSString *action = [[event valueForKey:@"payload"] valueForKey:@"action"];
    NSNumber *pullrequestId = [[event valueForKey:@"payload"] valueForKey:@"number"];
    NSString *repository = [[event valueForKey:@"repo"] valueForKey:@"name"];
    NSString *message = [NSString stringWithFormat:@"%@ %@ on pull request %@ on %@", actorLogin, action, pullrequestId, repository];
    NSString *url = [[[event valueForKey:@"payload"] valueForKey:@"pull_request"] valueForKey:@"html_url"];
    
    NSString *details = [[[event valueForKey:@"payload"] valueForKey:@"pull_request"] valueForKey:@"title"];
    
    [dict setValue:message forKey:@"message"];
    [dict setValue:url forKey:@"url"];
    [dict setValue:details forKey:@"details"];
    
    return dict;    
}

- (NSDictionary *) getPullReview:(NSDictionary *)event{
    return [NSMutableDictionary dictionary];    
}

- (NSDictionary *) getPush:(NSDictionary *)event{
    NSMutableDictionary *dict = [NSMutableDictionary dictionaryWithCapacity:2];
    
    NSString *actorLogin = [[event valueForKey:@"actor"] valueForKey:@"login"];
    NSNumber *branch = [[event valueForKey:@"payload"] valueForKey:@"ref"];
    NSString *repository = [[event valueForKey:@"repo"] valueForKey:@"name"];
    NSString *message = [NSString stringWithFormat:@"%@ pushed to %@ at %@", actorLogin, branch, repository];
    
    NSNumber *size = [[event valueForKey:@"payload"] valueForKey:@"size"];
    NSString *commit = @"commit";
    if ([size intValue] > 1) {
        commit = @"commits";
    }
    NSString *details = [NSString stringWithFormat:@"%@ new %@", size, commit];
    
    [dict setValue:message forKey:@"message"];
    [dict setValue:details forKey:@"details"];
    
    return dict;    
}

- (NSDictionary *) getTeam:(NSDictionary *)event{
    return [NSMutableDictionary dictionary];    
}

- (NSDictionary *) getWatch:(NSDictionary *)event{
    NSMutableDictionary *dict = [NSMutableDictionary dictionaryWithCapacity:2];
        
    NSString *actorLogin = [[event valueForKey:@"actor"] valueForKey:@"login"];
    NSString *action = [[event valueForKey:@"payload"] valueForKey:@"action"];
    NSString *repository = [[event valueForKey:@"repo"] valueForKey:@"name"];
    NSString *message = [NSString stringWithFormat:@"%@ %@ watching %@", actorLogin, action, repository];
    
    [dict setValue:message forKey:@"message"];
    
    return dict;    
}

- (void) updateEventMenu:(NSDictionary *) event {
    if (!event) {
        return;
    }
    
    NSString *type = [event valueForKey:@"type"];
    
    if (!type) {
        return;
    }
        
    if ([CommitCommentEvent isEqualToString:type]) {
        [menuController addEvent:[self getCommit:event] top:YES];
        
    } else if ([CreateEvent isEqualToString:type]) {
        
        [menuController addEvent:[self getCreate:event] top:YES];
        
    } else if ([DeleteEvent isEqualToString:type]) {
        
        [menuController addEvent:[self getDelete:event] top:YES];
        
    } else if ([DownloadEvent isEqualToString:type]) {
        
        [menuController addEvent:[self getDownload:event] top:YES];
        
    } else if ([FollowEvent isEqualToString:type]) {
        
        [menuController addEvent:[self getFollow:event] top:YES];
        
    } else if ([ForkEvent isEqualToString:type]) {
        
        [menuController addEvent:[self getFork:event] top:YES];
        
    } else if ([ForkApplyEvent isEqualToString:type]) {
        
    } else if ([GistEvent isEqualToString:type]) {
        
        [menuController addEvent:[self getGist:event] top:YES];
        
    } else if ([GollumEvent isEqualToString:type]) {
        
        [menuController addEvent:[self getGollum:event] top:YES];
        
    } else if ([IssueCommentEvent isEqualToString:type]) {
        
        [menuController addEvent:[self getIssueComment:event] top:YES];
        
    } else if ([IssuesEvent isEqualToString:type]) {
        
        [menuController addEvent: [self getIssue:event] top:YES];
        
    } else if ([MemberEvent isEqualToString:type]) {
        
    } else if ([PublicEvent isEqualToString:type]) {
        
    } else if ([PullRequestEvent isEqualToString:type]) {
        
        [menuController addEvent:[self getPull:event] top:YES];
        
    } else if ([PullRequestReviewCommentEvent isEqualToString:type]) {
        
    } else if ([PushEvent isEqualToString:type]) {
        
       [menuController addEvent:[self getPush:event] top:YES];
        
    } else if ([TeamAddEvent isEqualToString:type]) {
        
    } else if ([WatchEvent isEqualToString:type]) {
        
        [menuController addEvent:[self getWatch:event] top:YES];
        
    } else {
        // NOP
    }
}


- (void)dealloc {
    [super dealloc];
}

@end