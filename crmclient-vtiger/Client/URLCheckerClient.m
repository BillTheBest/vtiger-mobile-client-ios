//
//  URLCheckerClient.m
//  VTFunctionalitiesApp
//
//  Created by Giovanni on 1/16/14.
//  Copyright (c) 2014 gixWorks. All rights reserved.
//

#import "URLCheckerClient.h"
#import "GWCertificatesHelper.h"
#import <CocoaLumberjack.h>
#import "DDLogLevel.h"

static BOOL user_wants_to_trust_invalid_certificates = YES;

@interface URLCheckerClient ()
{
    BOOL _using_invalid_certificate;
    BOOL _requested_client_certificate;
	BOOL _requested_basic_auth;
    NSURL *_url;
    NSURLConnection *_connection;
    NSData *_certificateData;
	NSString *_basicHTTPAuthUsername;
	NSString *_basicHTTPAuthPassword;
}

@end

@implementation URLCheckerClient

- (void)startTestingReachability
{
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:_url cachePolicy:NSURLRequestReloadIgnoringLocalAndRemoteCacheData timeoutInterval:10];
    [request setHTTPMethod: @"HEAD"];
    _connection = [NSURLConnection connectionWithRequest:request delegate:self];
    if (!_connection) {
        [self.URLCheckerClientDelegate urlCheckerDidFinishWithError:@"Connection failed" url:_url responseCode:0 invalid_certificate:NO requestedClientCertificate:NO requestedHTTPBasicAuth:NO];
        return;
    }
    [_connection start];
}

- (id)init
{
    [self doesNotRecognizeSelector:_cmd];
    //Init method should not be called
    return self;
}

- (id)initWithDelegate:(id<URLCheckerClientDelegate>)delegate url:(NSURL *)urlToTest certificateData:(NSData*)data basicHTTPUsername:(NSString*)username basicHTTPPassword:(NSString*)password
{
    self = [super init];
    if (self) {
        self.URLCheckerClientDelegate = delegate;
        _url = urlToTest;
        _connection = nil;
        _certificateData = data;
        _using_invalid_certificate = NO; //we start without self-signed certificate
        _requested_client_certificate = NO; //we assume the server has not (yet) requested client certificate
		_requested_basic_auth = NO;
		_basicHTTPAuthUsername = username;
		_basicHTTPAuthPassword = password;
    }
    return self;
}

#pragma mark - NSURLconnection delegate

- (BOOL)connectionShouldUseCredentialStorage:(NSURLConnection *)connection
{
    return NO; //Don't use credential storage. We manage the certificate ourselves
}

- (NSCachedURLResponse *)connection:(NSURLConnection *)connection willCacheResponse:(NSCachedURLResponse *)cachedResponse {
    return nil;
}

- (BOOL)connection:(NSURLConnection *)connection canAuthenticateAgainstProtectionSpace:(NSURLProtectionSpace *)protectionSpace {
#if DEBUG
    NSLog(@"AuthenticationMethod: %@", protectionSpace.authenticationMethod);
#endif
    return ([protectionSpace.authenticationMethod isEqualToString:NSURLAuthenticationMethodServerTrust ] ||
            [protectionSpace.authenticationMethod isEqualToString:NSURLAuthenticationMethodClientCertificate] ||
			[protectionSpace.authenticationMethod isEqualToString:NSURLAuthenticationMethodHTTPBasic] ||
			([protectionSpace.protocol isEqualToString:@"http"] && [protectionSpace.authenticationMethod isEqualToString:NSURLAuthenticationMethodDefault]));
}

- (void)connection:(NSURLConnection *)connection didReceiveAuthenticationChallenge:(NSURLAuthenticationChallenge *)challenge
{
    if ([challenge.protectionSpace.authenticationMethod isEqualToString:NSURLAuthenticationMethodServerTrust]) {
        
        // Verify the certificate sent from the server:
        SecTrustResultType trustResult;
        OSStatus status = SecTrustEvaluate(challenge.protectionSpace.serverTrust, &trustResult);
        BOOL trusted = (status == errSecSuccess) && ((trustResult == kSecTrustResultProceed) || (trustResult == kSecTrustResultUnspecified));
        
        if (trusted) {
            //If it's trusted, proceed safely
            [challenge.sender useCredential:[NSURLCredential credentialForTrust:challenge.protectionSpace.serverTrust]
                 forAuthenticationChallenge:challenge];
            _using_invalid_certificate = NO;
        } else {
            //If it's not trusted, we proceed only if the user wants to trust invalid certificates (such as self-signed ones)
            if (user_wants_to_trust_invalid_certificates) { //always defaulted to YES //GM
                _using_invalid_certificate = YES;
                [challenge.sender useCredential:[NSURLCredential credentialForTrust:challenge.protectionSpace.serverTrust]
                     forAuthenticationChallenge:challenge];
            } else {
                [challenge.sender cancelAuthenticationChallenge:challenge];
            }
        }
    }
    else if([challenge.protectionSpace.authenticationMethod isEqualToString:NSURLAuthenticationMethodClientCertificate]){
        
        //We mark that we have been requested with a client certificate
        _requested_client_certificate = YES;
        
        //Client Certificate
#if DEBUG
        NSLog(@"%@ Client Certificate requested", NSStringFromClass([self class]));
#endif
        if ([_certificateData length] == 0) {
            //We have no certificate data. We perform default handling (this will fail)
            [challenge.sender cancelAuthenticationChallenge:challenge];
        }
        else{
            //we have a identity reference to work with
            SecIdentityRef myIdentity = [GWCertificatesHelper gw_identityFromPersistentRef:_certificateData];
            
            //New initialization
            SecCertificateRef myCertificate;
            
            SecIdentityCopyCertificate(myIdentity, &myCertificate);
            const void *certs[] = { myCertificate };
            CFArrayRef certsArray = CFArrayCreate(NULL, certs, 1, NULL);
            NSURLCredential *credential = [NSURLCredential credentialWithIdentity:myIdentity certificates:(__bridge NSArray*)certsArray persistence:NSURLCredentialPersistenceNone];
            assert(credential != nil);
            [[challenge sender] useCredential:credential forAuthenticationChallenge:challenge];
        }
    }
	else if([challenge.protectionSpace.authenticationMethod isEqualToString:NSURLAuthenticationMethodHTTPBasic] || ([challenge.protectionSpace.protocol isEqualToString:@"http"] && [challenge.protectionSpace.authenticationMethod isEqualToString:NSURLAuthenticationMethodDefault])){
		//HTTP Basic Authentication
#if DEBUG
		NSLog(@"%@ HTTP Basic Auth requested", NSStringFromClass([self class]));
#endif
		_requested_basic_auth = YES;
		if ([_basicHTTPAuthUsername length] > 0 && [_basicHTTPAuthPassword length] > 0) {
			NSURLCredential *newCredential = [NSURLCredential credentialWithUser:_basicHTTPAuthUsername
													   password:_basicHTTPAuthPassword
													persistence:NSURLCredentialPersistenceNone];
			
			[[challenge sender] useCredential:newCredential forAuthenticationChallenge:challenge];
		}
		else{
			[[challenge sender] cancelAuthenticationChallenge:challenge];
		}
	}
    else {
        [challenge.sender performDefaultHandlingForAuthenticationChallenge:challenge];
    }
}

- (void)connection:(NSURLConnection *)connection didFailWithError:(NSError *)error
{
    _connection = nil;
    DDLogDebug(@"%@ %@ connection failed with error: %@", NSStringFromClass([self class]), NSStringFromSelector(_cmd), [error description]);
    [self.URLCheckerClientDelegate urlCheckerDidFinishWithError:[error localizedDescription] url:_url responseCode:-1 invalid_certificate:_using_invalid_certificate requestedClientCertificate:_requested_client_certificate requestedHTTPBasicAuth:_requested_basic_auth];
}

- (void)connection:(NSURLConnection *)connection didReceiveResponse:(NSURLResponse *)response
{
    NSHTTPURLResponse *httpResponse = (NSHTTPURLResponse*)response;
    
    if (httpResponse.statusCode >= 500) {
        //Something is wrong with the url provided by the server
        DDLogDebug(@"%@ %@ The server is not available (Response code %ld)", NSStringFromClass([self class]), NSStringFromSelector(_cmd), (long)httpResponse.statusCode);
        NSString *err = [NSString stringWithFormat:@"The server is not available (Response code %ld)", (long)httpResponse.statusCode];
        [self.URLCheckerClientDelegate urlCheckerDidFinishWithError:err url:_url responseCode:httpResponse.statusCode invalid_certificate:_using_invalid_certificate requestedClientCertificate:_requested_client_certificate requestedHTTPBasicAuth:_requested_basic_auth];
    }
    else if (httpResponse.statusCode == 403) // && requested_client_certificate == YES)
    {
        //Unauthorized (could be due to client certificate but could also be relative to any other authentication failure -e.g. Basic Authentication-)
        NSString *err = [NSString stringWithFormat:@"Unauthorized (Response code %ld)", (long)httpResponse.statusCode];
        [self.URLCheckerClientDelegate urlCheckerDidFinishWithError:err url:_url responseCode:httpResponse.statusCode invalid_certificate:_using_invalid_certificate requestedClientCertificate:_requested_client_certificate requestedHTTPBasicAuth:_requested_basic_auth];
    }
    else if(httpResponse.statusCode == 200){
        //Everything OK - the best outcome
        [self.URLCheckerClientDelegate urlCheckerDidFinishWithError:nil url:_url responseCode:httpResponse.statusCode invalid_certificate:_using_invalid_certificate requestedClientCertificate:_requested_client_certificate requestedHTTPBasicAuth:_requested_basic_auth];
    }
    else{
        //any other error
        DDLogDebug(@"%@ %@ The server is not available (Response code %ld)", NSStringFromClass([self class]), NSStringFromSelector(_cmd), (long)httpResponse.statusCode);
        NSString *err = [NSString stringWithFormat:@"The server is not available (Response code %ld)", (long)httpResponse.statusCode];
        [self.URLCheckerClientDelegate urlCheckerDidFinishWithError:err url:_url responseCode:httpResponse.statusCode invalid_certificate:_using_invalid_certificate requestedClientCertificate:_requested_client_certificate requestedHTTPBasicAuth:_requested_basic_auth];
    }
}


@end
