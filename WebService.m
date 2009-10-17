//
//  WebService.m
//  SOAP
//
//  Created by Oliver on 16.10.09.
//  Copyright 2009 Drobnik.com. All rights reserved.
//

#import "WebService.h"
#import "XMLdocument.h"
#import "NSString+Helpers.h"

@implementation WebService

- (NSURLRequest *) makeGETRequestWithLocation:(NSString *)url Parameters:(NSDictionary *)parameters
{
	NSMutableString *query = [NSMutableString string];
	
	for (NSString *oneKey in [parameters allKeys])
	{
		if ([query length])
		{
			[query appendString:@"&"];
		}
		else
		{
			[query appendString:@"?"];
		}

		
		[query appendFormat:@"%@=%@", oneKey, [[parameters objectForKey:oneKey] stringByUrlEncoding]];	
	}
	
	url = [url stringByAppendingString:query];

	return [[[NSURLRequest alloc] initWithURL:[NSURL URLWithString:url]] autorelease];
}


- (NSURLRequest *) makePOSTRequestWithLocation:(NSString *)url Parameters:(NSDictionary *)parameters
{
	NSMutableString *query = [NSMutableString string];
	
	for (NSString *oneKey in [parameters allKeys])
	{
		if ([query length])
		{
			[query appendString:@"&"];
		}
		
		
		[query appendFormat:@"%@=%@", oneKey, [[parameters objectForKey:oneKey] stringByUrlEncoding]];	
	}
	
	NSMutableURLRequest *request = [[[NSMutableURLRequest alloc] initWithURL:[NSURL URLWithString:url]] autorelease];
	
	[request setHTTPMethod:@"POST"];
	[request addValue:@"application/x-www-form-urlencoded" forHTTPHeaderField:@"Content-Type"];
	
	// make body
	NSData *postBody = [NSData dataWithData:[query dataUsingEncoding:NSUTF8StringEncoding]];
	[request setHTTPBody:postBody];
	
	return request;
}

- (NSURLRequest *) makeSOAPRequestWithLocation:(NSString *)url Parameters:(NSArray *)parameters Operation:(NSString *)operation Namespace:(NSString *)namespace Action:(NSString *)action SOAPVersion:(SOAPVersion)soapVersion;
{
	NSMutableString *envelope = [NSMutableString string];
	
	[envelope appendString:@"<?xml version=\"1.0\" encoding=\"utf-8\"?>\n"];
	
	switch (soapVersion) {
		case SOAPVersion1_0:
			[envelope appendString:@"<soap:Envelope xmlns:xsi=\"http://www.w3.org/2001/XMLSchema-instance\" xmlns:xsd=\"http://www.w3.org/2001/XMLSchema\" xmlns:soap=\"http://schemas.xmlsoap.org/soap/envelope/\">\n"];
			break;
		case SOAPVersion1_2:
			[envelope appendString:@"<soap:Envelope xmlns:xsi=\"http://www.w3.org/2001/XMLSchema-instance\" xmlns:xsd=\"http://www.w3.org/2001/XMLSchema\" xmlns:soap=\"http://www.w3.org/2003/05/soap-envelope\">\n"];
			break;
	}
	[envelope appendString:@"<soap:Body>\n"];

	[envelope appendFormat:@"<%@ xmlns=\"%@\">\n", operation, namespace];
	
	for (NSDictionary *oneParameter in parameters)
	{
		[envelope appendFormat:@"<%@>%@</%@>\n", [oneParameter objectForKey:@"name"], [[oneParameter objectForKey:@"value"] stringByReplacingPercentEscapesUsingEncoding:NSUTF8StringEncoding], [oneParameter objectForKey:@"name"]];
	}			
	
	[envelope appendFormat:@"</%@>\n", operation];
	[envelope appendString:@"</soap:Body>\n"];
	[envelope appendString:@"</soap:Envelope>\n"];
	
	NSMutableURLRequest *request = [[[NSMutableURLRequest alloc] initWithURL:[NSURL URLWithString:url]] autorelease];
	
	[request setHTTPMethod:@"POST"];
	[request addValue:@"text/xml; charset=utf-8" forHTTPHeaderField:@"Content-Type"];
	[request addValue:action forHTTPHeaderField:@"SOAPAction"];
	
	// make body
	NSData *postBody = [NSData dataWithData:[envelope dataUsingEncoding:NSUTF8StringEncoding]];
	[request setHTTPBody:postBody];
	
	return request;
}

- (NSString *) returnValueFromSOAPResponse:(XMLdocument *)envelope
{
	XMLelement *body = [envelope.documentRoot getNamedChild:@"Body"];
	XMLelement *response = [body.children lastObject];  // there should be only one

	if (response.children)
	{	
		XMLelement *retChild = [response.children lastObject];
		
		return retChild.text;
	}
	else 
	{
		return nil;
	}
}

@end
