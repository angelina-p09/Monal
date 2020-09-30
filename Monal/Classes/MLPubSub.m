//
//  MLPubSub.m
//  monalxmpp
//
//  Created by Thilo Molitor on 20.09.20.
//  Copyright © 2020 Monal.im. All rights reserved.
//

#import "MLPubSub.h"
#import "xmpp.h"


@interface MLPubSub ()
{
    xmpp* _account;
    NSMutableDictionary* _handlers;
    NSMutableDictionary* _cache;
    NSMutableDictionary* _configuredNodes;
}
@end


@implementation MLPubSub

-(id) initWithAccount:(xmpp* _Nonnull) account
{
    self = [super init];
    _account = account;
    _handlers = [[NSMutableDictionary alloc] init];
    _cache = [[NSMutableDictionary alloc] init];
    return self;
}

-(void) registerInterestForNode:(NSString* _Nonnull) node withPersistentCaching:(BOOL) caching
{
    @synchronized(_cache) {
        _configuredNodes[node] = caching ? @YES : @NO;
        _cache[node][@"persistentCache"] = _configuredNodes[node];
        [_account setPubSubNotificationsForNodes:[_configuredNodes allKeys]];
    }
}

-(void) unregisterInterestForNode:(NSString* _Nonnull) node
{
    @synchronized(_cache) {
        //deactivate persistent cache but keep cached data (we always cache data, even for nodes not registered for automatic refres through "+notify")
        if(_cache[node])
            _cache[node][@"persistentCache"] = @NO;
        [_configuredNodes removeObjectForKey:node];
    }
}

-(void) registerHandler:(monal_pubsub_handler_t) handler forNode:(NSString* _Nonnull) node andBareJid:(NSString* _Nullable) jid
{
    //empty jid means "all jids"
    if(!jid)
        jid = @"";
    
    //sanity check
    NSSet* desiredNodeList = [[NSSet alloc] initWithArray:[MLPubSub getDesiredNodesList]];
    if(![desiredNodeList containsObject:node])
        @throw [NSException exceptionWithName:@"RuntimeException" reason:@"PubSub node '%@' can not be registered because it is not listed in the PubSub getDesiredNodesList array!" userInfo:@{
            @"desiredNodeList": desiredNodeList,
            @"node": [node stringByAppendingString:@"+notify"]
        }];
    
    //save handler
    if(!_handlers[node])
        _handlers[node] = [[NSMutableDictionary alloc] init];
    _handlers[node][jid] = handler;
    
    //call handlers directly if we have already cached data
    [self callHandlersForNode:node andJid:jid];
}

-(void) unregisterHandlerForNode:(NSString* _Nonnull) node andBareJid:(NSString* _Nullable) jid
{
    //empty jid means "all jids"
    if(!jid)
        jid = @"";
    
    if(!_handlers[node])
        return;
    [_handlers[node] removeObjectForKey:jid];
}

-(NSDictionary* _Nullable) getCachedDataForNode:(NSString* _Nonnull) node andBareJid:(NSString* _Nonnull) jid
{
    @synchronized(_cache) {
        if(_cache[node] && _cache[node][@"data"][jid])
            return [[NSDictionary alloc] initWithDictionary:_cache[node][@"data"][jid] copyItems:YES];
        return nil;
    }
}

-(void) forceRefreshForNode:(NSString* _Nonnull) node andBareJid:(NSString* _Nonnull) jid withCompletion:(monal_pubsub_fetch_completion_t _Nullable) completion
{
    XMPPIQ* query = [[XMPPIQ alloc] initWithType:kiqGetType to:jid];
    [query addChild:[[MLXMLNode alloc] initWithElement:@"pubsub" andNamespace:@"http://jabber.org/protocol/pubsub" withAttributes:@{} andChildren:@[
        [[MLXMLNode alloc] initWithElement:@"items" withAttributes:@{@"node": node} andChildren:@[] andData:nil]
    ] andData:nil]];
    [_account sendIq:query withResponseHandler:^(XMPPIQ* result) {
        [self handleItems:[result find:@"{http://jabber.org/protocol/pubsub#event}event/items"] fromJid:result.fromUser];
        if(completion)
            completion(YES, result);
    } andErrorHandler:^(XMPPIQ* error) {
        if(completion)
            completion(NO, error);
    }];
}

-(void) publish:(NSArray* _Nonnull) items onNode:(NSString* _Nonnull) node
{
    XMPPIQ* query = [[XMPPIQ alloc] initWithType:kiqSetType];
    [query addChild:[[MLXMLNode alloc] initWithElement:@"pubsub" andNamespace:@"http://jabber.org/protocol/pubsub" withAttributes:@{} andChildren:@[
        [[MLXMLNode alloc] initWithElement:@"publish" withAttributes:@{@"node": node} andChildren:items andData:nil]
    ] andData:nil]];
    [_account sendIq:query withResponseHandler:^(XMPPIQ* result) {
        //ignore publish result
    } andErrorHandler:^(XMPPIQ* error){
        //ignore publish errors for now
    }];
}

//*** framework methods below

-(NSDictionary*) getInternalData
{
    @synchronized(_cache) {
        return [[NSDictionary alloc] initWithDictionary:_cache copyItems:YES];
    }
}

-(void) setInternalData:(NSDictionary*) data
{
    @synchronized(_cache) {
        _cache = [NSMutableDictionary dictionaryWithDictionary:data];
    }
}

-(void) invalidateCache
{
    @synchronized(_cache) {
        //only invalidate non-persistent items in cache
        for(NSString* node in _cache)
            if(!_cache[node][@"persistentCache"])
                [_cache removeObjectForKey:node];
    }
}

-(void) handleHeadlineMessage:(XMPPMessage* _Nonnull) messageNode
{
    //TODO: handle node deletion as well
    [self handleItems:[messageNode findFirst:@"/<type=headline>/{http://jabber.org/protocol/pubsub#event}event/items"] fromJid:messageNode.fromUser];
}

//*** internal methods below

-(void) handleItems:(MLXMLNode* _Nullable) items fromJid:(NSString* _Nullable) jid
{
    if(!items)
        return;
    
    //default from is own account
    if(!jid)
        jid = _account.connectionProperties.identity.jid;
    
    NSString* node = [items findFirst:@"/@node"];
    
    @synchronized(_cache) {
        if(!_cache[node])
        {
            _cache[node] = [[NSMutableDictionary alloc] init];
            _cache[node][@"persistentCache"] = _configuredNodes[node] ? @YES : @NO;
            _cache[node][@"data"] = [[NSMutableDictionary alloc] init];
        }
        if(!_cache[node][@"data"][jid])
            _cache[node][@"data"][jid] = [[NSMutableDictionary alloc] init];
        for(MLXMLNode* item in [items find:@"item"])
        {
            NSString* itemId = [item findFirst:@"/@id"];
            if(!itemId)
                itemId = @"";
            _cache[node][@"data"][jid][itemId] = item;
        }
    }
    
    //call handlers for this node/jid combination
    [self callHandlersForNode:node andJid:jid];
}

-(void) callHandlersForNode:(NSString*) node andJid:(NSString*) jid
{
    @synchronized(_cache) {
        if(!_cache[node] || !_cache[node][jid])
            return;
        
        if(_handlers[node])
        {
            if(_handlers[node][jid])
                ((monal_pubsub_handler_t)_handlers[node][jid])([self getCachedDataForNode:node andBareJid:jid]);
            if(_handlers[node][@""])
                ((monal_pubsub_handler_t)_handlers[node][@""])([self getCachedDataForNode:node andBareJid:jid]);
        }
    }
}

@end
