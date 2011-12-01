//
//  GithubOAuthClient.h
//  QuickHub
//
//  Created by Christophe Hamerling on 01/12/11.
//  Copyright 2011 christophehamerling.com. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface GithubOAuthClient : NSObject

#pragma mark - OAuth
- (NSString *)getOAuthURL:(NSString *)path;

#pragma mark - Read API

- (BOOL) checkCredentials:(id) sender;

- (NSDictionary*) loadUser:(id) sender;

- (NSDictionary*) loadGHData:(id)sender;
- (NSDictionary*) loadIssues:(id) sender;
- (NSDictionary*) loadGists:(id) sender;
- (NSDictionary*) loadOrganizations:(id) sender;
- (NSDictionary*) loadRepos:(id) sender;
- (NSDictionary*) loadPulls:(id) sender;
- (NSDictionary*) loadFollowers:(id) sender;
- (NSDictionary*) loadFollowings:(id) sender;
- (NSDictionary*) loadWatchedRepos:(id) sender;

# pragma mark - Write API
- (NSString*) createGist:(NSString*) content withDescription:(NSString*) title andFileName:(NSString *) fileName isPublic:(BOOL) pub;

- (NSString*) createRepository:(NSString*) name description:(NSString*)desc homepage:(NSString*) home wiki:(BOOL)wk issues:(BOOL)is downloads:(BOOL)dl isPrivate:(BOOL)privacy;

- (NSDictionary *) getGist:(NSString*)gistId;

- (NSDictionary *)getPullsForRepository:(NSString *)name;

- (NSDictionary *)getReposForOrganization:(NSString *)name;

- (NSMutableSet *)getRepositories:(id)sender;

@end
