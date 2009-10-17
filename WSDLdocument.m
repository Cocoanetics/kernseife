//
//  WSDLdocument.m
//  SOAP
//
//  Created by Oliver on 14.10.09.
//  Copyright 2009 Drobnik.com. All rights reserved.
//

#import "WSDLdocument.h"
#import "NSArray+XMLelement.h"
#import "NSString+Helpers.h"
#import "NSDate+xml.h"
#import "WebService.h"

@implementation WSDLdocument


- (id) init
{
	if (self = [super init])
	{
		self.delegate = self;
	}
	
	return self;
}

- (NSString *) serviceName
{
	return [service.attributes objectForKey:@"name"];
}

- (NSString *)description
{
	return [documentRoot description];
}

- (void)processingAfterLoading
{
	service = [self.documentRoot getNamedChild:@"service"];
	ports = [service getNamedChildren:@"port"];
	types = [documentRoot getNamedChild:@"types"];
	schema = [types getNamedChild:@"schema"];
}


- (BOOL) namespaceIsXMLSchema:(NSString *)namespace
{
	// expand namespace appreviation
	NSString *longNamespace = [namespaces objectForKey:namespace];
	
	if ([longNamespace isEqualToString:@"http://www.w3.org/2001/XMLSchema"])
	{
		return YES;
	}
	else
	{
		return NO;
	}
}

- (SOAPVersion) versionOfSOAPSchema:(NSString *)namespace
{
	if ([namespace isEqualToString:@"http://schemas.xmlsoap.org/wsdl/soap12/"])
	{
		return SOAPVersion1_2;
	}
	else if ([namespace isEqualToString:@"http://schemas.xmlsoap.org/wsdl/soap/"])
	{
		return SOAPVersion1_0;
	}
	else
	{
		return SOAPVersionNone;
	}
}


- (NSArray *)parametersOfMessage:(XMLelement *)message
{
	//NSString *messageName = [message.attributes objectForKey:@"name"];
	
	NSMutableArray *retArray = [NSMutableArray array];
	
	NSArray *messageParts = [message getNamedChildren:@"part"];
	
	if (!messageParts)
	{
		// NSLog(@"no input parts --- HTML?");
	}
	else
	{
		for (XMLelement *onePart in messageParts)
		{
			NSString *partElementName = [onePart.attributes objectForKey:@"name"];
			NSString *partElementType = [onePart.attributes objectForKey:@"type"];
			
			if (!partElementType)
			{
				// might be an element
				partElementType = [onePart.attributes objectForKey:@"element"];
			}
			
			NSArray *typeParts = [partElementType componentsSeparatedByString:@":"];
			
			if ([typeParts count]==2)
			{
				NSString *namespace = [typeParts objectAtIndex:0];
				NSString *type = [typeParts objectAtIndex:1];
				
				if ([self namespaceIsXMLSchema:namespace])
				{
					// simple standard type
					
					NSDictionary *oneParamter = [NSDictionary dictionaryWithObjectsAndKeys:partElementName, @"name", type, @"type", nil];
					[retArray addObject:oneParamter];
				}
				else
				{
					// must be defined type
					XMLelement *element = [[schema getNamedChildren:@"element" WithAttribute:@"name" HasValue:type] lastObject];
					NSString *elementName = [onePart.attributes objectForKey:@"name"];	
					
					NSString *elementType = [element.attributes objectForKey:@"type"];
					
					if (elementType)
					{
						// simple type
						NSArray *typeParts = [elementType componentsSeparatedByString:@":"];
						
						NSDictionary *oneParamter = [NSDictionary dictionaryWithObjectsAndKeys:elementName, @"name", [typeParts lastObject], @"type", nil];
						[retArray addObject:oneParamter];
					}
					else
					{	
						XMLelement *elementChild = [element.children objectAtIndex:0];
						
						if ([elementChild.name isEqualToString:@"complexType"])
						{
							if ([elementChild.children count]==0)
							{
								// dummy non-parameter
							}
							else
							{
								elementChild = [elementChild.children objectAtIndex:0];
								if ([elementChild.name isEqualToString:@"sequence"])
								{
									// sequence of elements
									
									for (XMLelement *oneElement in elementChild.children)
									{
										NSString *elementName = [oneElement.attributes objectForKey:@"name"];
										NSString *elementType = [oneElement.attributes objectForKey:@"type"];
										
										NSArray *typeParts = [elementType componentsSeparatedByString:@":"];
										
										
										NSDictionary *oneParamter = [NSDictionary dictionaryWithObjectsAndKeys:elementName, @"name", [typeParts lastObject], @"type", nil];
										[retArray addObject:oneParamter];
										
									}
									
								}
							}
						}
						
					}
				}
			}
		}
	}
	
	if ([retArray count])
	{
		return [NSArray arrayWithArray:retArray];
	}
	else
	{
		return nil;
	}
}

- (NSArray *)operationsForPort:(XMLelement *)port
{
	// get the binding
	NSString *portBinding = [port.attributes objectForKey:@"binding"];
	
	NSArray *tmpArray = [portBinding componentsSeparatedByString:@":"];
	
	NSString *bindingType = [tmpArray lastObject];
	
	XMLelement *binding = [[documentRoot getNamedChildren:@"binding" WithAttribute:@"name" HasValue:bindingType] objectAtIndex:0];
	
	
	// get input/output for portType
	
	NSString *port_type = [[[binding.attributes objectForKey:@"type"] componentsSeparatedByString:@":"] lastObject];
	XMLelement *portType = [[documentRoot getNamedChildren:@"portType" WithAttribute:@"name" HasValue:port_type] objectAtIndex:0];
	
	// loop through port operations
	return [portType getNamedChildren:@"operation"];
}


- (NSArray *)portNames
{
	NSMutableArray *tmpArray = [NSMutableArray array];
	
	for (XMLelement *onePort in ports)
	{
		[tmpArray addObject:[onePort.attributes objectForKey:@"name"]];
	}
	
	if ([tmpArray count])
	{
		return [NSArray arrayWithArray:tmpArray];
	}
	else
	{
		return nil;
	}
}

- (NSString *)cocoaTypeForSoapType:(NSString *)soapType
{
	if ([soapType isEqualToString:@"string"])
	{
		return @"NSString *";
	}
	
	if ([soapType isEqualToString:@"boolean"])
	{
		return @"BOOL";
	}
	
	if ([soapType isEqualToString:@"dateTime"])
	{
		return @"NSDate *";
	}
	
	if ([soapType isEqualToString:@"int"])
	{
		return @"NSInteger";
	}
	
	if ([soapType isEqualToString:@"double"])
	{
		return @"double";
	}
	
	
	return @"Unknown";
}


- (NSString *)conversionFromNSStringToType:(NSString *)otherType variable:(NSString *)variable
{
	if ([otherType isEqualToString:@"NSString *"])
	{
		// no conversion necessary
		return variable;
	}
	else if ([otherType isEqualToString:@"NSInteger"])
	{
		// convert to int
		return [NSString stringWithFormat:@"[%@ intValue]", variable];
	}
	else if ([otherType isEqualToString:@"double"])
	{
		// convert to double
		return [NSString stringWithFormat:@"[%@ doubleValue]", variable];
	}
	else if ([otherType isEqualToString:@"NSDate *"])
	{
		// convert to NSDate
		return [NSString stringWithFormat:@"[%@ dateFromISO8601]", variable];
	}
	
	return nil;
}

- (NSString *)conversionFromTypeToNSString:(NSString *)otherType variable:(NSString *)variable
{
	if ([otherType isEqualToString:@"NSString *"])
	{
		// no conversion necessary
		return variable;
	}
	else if ([otherType isEqualToString:@"NSInteger"])
	{
		// convert to int
		return [NSString stringWithFormat:@"[NSString stringWithFormat:@\"%%d\", %@]", variable];
	}
	else if ([otherType isEqualToString:@"double"])
	{
		// convert to double
		return [NSString stringWithFormat:@"[NSString stringWithFormat:@\"%%f\", %@]", variable];
	}
	else if ([otherType isEqualToString:@"NSDate *"])
	{
		// convert to NSDate
		return [NSString stringWithFormat:@"[%@ ISO8601string]", variable];
	}
	
	return nil;
}

/*
- (NSString *)conversionFromCocoaTypeToNSString:(NSString *)cocoaType variable:(NSString *)variable
{
	if ([cocoaType isEqualToString:@"string"])
	{
		// no conversion necessary
		return variable;
	}
	else if ([cocoaType isEqualToString:@"NSInteger"])
	{
		// convert to int
		return [NSString stringWithFormat:@"[%@ intValue]", variable];
	}
	else if ([cocoaType isEqualToString:@"double"])
	{
		// convert to double
		return [NSString stringWithFormat:@"[%@ doubleValue]", variable];
	}
	else if ([cocoaType isEqualToString:@"NSDate *"])
	{
		// convert to NSDate
		return [NSString stringWithFormat:@"[%@ dateFromISO8601]", variable];
	}
	
	return @"Unknown";
}
*/







// constructs objC prototype for .h and .m
- (NSString *)prototypeForOperation:(XMLelement *)operation
{
	NSString *operationName = [operation.attributes objectForKey:@"name"];
	
	NSMutableString *retStr = [NSMutableString string];
	
	// input
	XMLelement *input = [operation getNamedChild:@"input"];
	
	NSString *input_msg = [input.attributes objectForKey:@"message"];
	NSArray *tmpArray = [input_msg componentsSeparatedByString:@":"];
	XMLelement *inputMessage = [[documentRoot getNamedChildren:@"message" WithAttribute:@"name" HasValue:[tmpArray lastObject]] objectAtIndex:0];
	
	NSArray *inputParameters = [self parametersOfMessage:inputMessage];
	
	XMLelement *output = [operation getNamedChild:@"output"];
	NSString *output_msg = [output.attributes objectForKey:@"message"];
	tmpArray = [output_msg componentsSeparatedByString:@":"];
	XMLelement *outputMessage = [[documentRoot getNamedChildren:@"message" WithAttribute:@"name" HasValue:[tmpArray lastObject]] objectAtIndex:0];
	
	NSArray *outputParameters = [self parametersOfMessage:outputMessage];
	
	if ([outputParameters count]>1)
	{
		NSLog(@"Multiple return parameters not supported");
	}
	
	NSDictionary *returnParam = [outputParameters lastObject];
	NSString *returnParamType = [self cocoaTypeForSoapType:[returnParam objectForKey:@"type"]];
	
	[retStr appendFormat:@"- (%@) %@", returnParamType, [operationName stringWithLowercaseFirstLetter]]; 
	
	
	for (int i=0; i<[inputParameters count];i++)
	{
		
		NSDictionary *inParam = [inputParameters objectAtIndex:i];
		NSString *inParamType = [self cocoaTypeForSoapType:[inParam objectForKey:@"type"]];
		NSString *inParamName = [[inParam objectForKey:@"name"] stringWithLowercaseFirstLetter];
		
		// first param with With
		if (!i)
		{
			[retStr appendString:@"With"]; 
			[retStr appendFormat:@"%@:(%@)%@", [inParamName stringWithUppercaseFirstLetter], inParamType, inParamName];
		}
		else 
		{
			[retStr appendString:@" "]; 
			[retStr appendFormat:@"%@:(%@)%@", inParamName, inParamType, inParamName];
		}
	}
	
	return [NSString stringWithString:retStr];
}


- (void)writeClassFilesForPort:(NSString *)portName
{
	XMLelement *port = [ports elementWhereAttribute:@"name" HasValue:portName];
	
	
	if (!port)
	{
		NSLog(@"Invalid port name '%@'", portName);
		return;
	}
	
	NSString *portBinding = [port.attributes objectForKey:@"binding"];
	XMLelement *address = [port getNamedChild:@"address"];
	NSString *address_url = [address.attributes objectForKey:@"location"];
	
	
	//  
	// get the binding
	
	NSArray *tmpArray = [portBinding componentsSeparatedByString:@":"];
	NSString *bindingType = [tmpArray lastObject];
	XMLelement *binding = [[documentRoot getNamedChildren:@"binding" WithAttribute:@"name" HasValue:bindingType] objectAtIndex:0];
	
	XMLelement *subBinding = [binding getNamedChild:@"binding"];
	
	//NSString *transport = [subBinding.attributes objectForKey:@"transport"];
	
	
	
	NSArray *operations = [self operationsForPort:port];
	
	
	NSMutableString *classHeader = [NSMutableString string];
	NSMutableString *classBody = [NSMutableString string];
	
	
	NSString *headerFilename = [NSString stringWithFormat:@"%@.h",[self serviceName]];
	NSString *bodyFilename = [NSString stringWithFormat:@"%@.m", [self serviceName]];
	
	
	// HEADER
	
	[classHeader appendFormat:@"// %@.h \n\n", [self serviceName]];
	[classHeader appendString:@"#import <Foundation/Foundation.h>\n"];
	[classHeader appendString:@"#import \"WebService.h\"\n\n"];
	[classHeader appendString:@"#import \"NSString+Helpers.h\"\n"];
	[classHeader appendString:@"#import \"NSDate+xml.h\"\n\n"];
	[classHeader appendFormat:@"@interface %@ : WebService\n{\n}\n\n", [self serviceName]];
	
	for (XMLelement *oneOperation in operations)
	{
		
		NSString *prototype = [self prototypeForOperation:oneOperation];
		[classHeader appendFormat:@"%@;\n", prototype];
		
	}
	
	[classHeader appendString:@"\n@end"];
	
	
	// BODY
	
	[classBody appendFormat:@"// %@.m \n\n", [self serviceName]];
	[classBody appendFormat:@"#import \"%@.h\"\n", [self serviceName]];
	[classBody appendString:@"#import \"XMLdocument.h\"\n\n"];
	[classBody appendFormat:@"@implementation %@\n\n", [self serviceName]];
	
	for (XMLelement *oneOperation in operations)
	{
		NSString *operationName = [oneOperation.attributes objectForKey:@"name"];
		
		NSString *prototype = [self prototypeForOperation:oneOperation];
		[classBody appendFormat:@"%@\n{\n", prototype];
		
		// get input parameters
		
		// input
		XMLelement *input = [oneOperation getNamedChild:@"input"];
		
		NSString *input_msg = [input.attributes objectForKey:@"message"];
		NSArray *tmpArray = [input_msg componentsSeparatedByString:@":"];
		XMLelement *inputMessage = [[documentRoot getNamedChildren:@"message" WithAttribute:@"name" HasValue:[tmpArray lastObject]] objectAtIndex:0];
		
		NSArray *inputParameters = [self parametersOfMessage:inputMessage];
		
		// output
		XMLelement *output = [oneOperation getNamedChild:@"output"];
		NSString *output_msg = [output.attributes objectForKey:@"message"];
		tmpArray = [output_msg componentsSeparatedByString:@":"];
		XMLelement *outputMessage = [[documentRoot getNamedChildren:@"message" WithAttribute:@"name" HasValue:[tmpArray lastObject]] objectAtIndex:0];
		NSArray *outputParameters = [self parametersOfMessage:outputMessage];
		
		// to know how to encode it we need to look it up in the binding
		XMLelement *operationInBinding = [[binding getNamedChildren:@"operation" WithAttribute:@"name" HasValue:operationName] lastObject];
		XMLelement *suboperation = [operationInBinding getNamedChild:@"operation"];

		SOAPVersion soapVersion = [self versionOfSOAPSchema:suboperation.namespace];
		NSString *resultString;
		
		if (soapVersion!=SOAPVersionNone)
		{
			// SOAP
			NSString *soapAction = [suboperation.attributes objectForKey:@"soapAction"];
			// operationName is set
			// namespace: 
			
			NSString *targetNamespace = [documentRoot.attributes objectForKey:@"targetNamespace"];
			
			[classBody appendFormat:@"\tNSString *location = @\"%@\";\n", address_url];
			
			[classBody appendString:@"\tNSMutableArray *paramArray = [NSMutableArray array];\n"];
			
			
			for (NSDictionary *oneParam in inputParameters)
			{
				NSString *paramName = [oneParam objectForKey:@"name"];
				NSString *paramType = [self cocoaTypeForSoapType:[oneParam objectForKey:@"type"]];
				NSString *methodParamName = [[oneParam objectForKey:@"name"] stringWithLowercaseFirstLetter];
				NSString *convertedVariable = [self conversionFromTypeToNSString:paramType variable:methodParamName];
				
				[classBody appendFormat:@"\t[paramArray addObject:[NSDictionary dictionaryWithObjectsAndKeys:@\"%@\", @\"name\",[%@ description], @\"value\", nil]];\n", paramName, convertedVariable];
			}
			
			if (soapVersion==SOAPVersion1_0)
			{
				[classBody appendFormat:@"\tNSURLRequest *request = [self makeSOAPRequestWithLocation:location Parameters:paramArray Operation:@\"%@\" Namespace:@\"%@\" Action:@\"%@\" SOAPVersion:SOAPVersion1_0];\n", operationName, targetNamespace, soapAction];
			}
			else if (soapVersion==SOAPVersion1_2)
			{
				[classBody appendFormat:@"\tNSURLRequest *request = [self makeSOAPRequestWithLocation:location Parameters:paramArray Operation:@\"%@\" Namespace:@\"%@\" Action:@\"%@\" SOAPVersion:SOAPVersion1_2];\n", operationName, targetNamespace, soapAction];
			}
			
			
			resultString = @"\tNSString *result = [self returnValueFromSOAPResponse:xml];\n";
		}
		else if ([suboperation.namespace isEqualToString:@"http://schemas.xmlsoap.org/wsdl/http/"])
		{
			// HTTP GET / POST
			NSString *verb = [subBinding.attributes objectForKey:@"verb"];	

			if (!verb)
			{
				[classBody appendString:@"#error HTTP Transport specified, but no VERB\n"];
			}
			
			NSString *path = [suboperation.attributes objectForKey:@"location"];
			
			NSString *location = [address_url stringByAppendingString:path];
			[classBody appendFormat:@"\tNSString *location = @\"%@\";\n", location];
			
			[classBody appendString:@"\tNSMutableDictionary *paramDict = [NSMutableDictionary dictionary];\n"];
			
			
			for (NSDictionary *oneParam in inputParameters)
			{
				NSString *paramName = [oneParam objectForKey:@"name"];
				NSString *methodParamName = [[oneParam objectForKey:@"name"] stringWithLowercaseFirstLetter];
				
				[classBody appendFormat:@"\t[paramDict setObject:[%@ description] forKey:@\"%@\"];\n", methodParamName, paramName];
			}
			
			[classBody appendFormat:@"\tNSURLRequest *request = [self make%@RequestWithLocation:location Parameters:paramDict];\n", verb];
			resultString = @"\tNSString *result = xml.documentRoot.text;\n";
		}	
		else
		{
			[classBody appendFormat:@"#error Unknown transport with schema '%@'\n", suboperation.namespace];;
		}

		[classBody appendString:@"\tNSURLResponse *response;\n"];
		[classBody appendString:@"\tNSError *error;\n"];
		[classBody appendString:@"\tNSData *data = [NSURLConnection sendSynchronousRequest:request returningResponse:&response error:&error];\n"];
		[classBody appendString:@"\tXMLdocument *xml = [XMLdocument documentWithData:data];\n"];
		[classBody appendString:resultString];
		
		if (outputParameters)
		{
			NSDictionary *outParam = [outputParameters objectAtIndex:0];
			NSString *outParamType = [self cocoaTypeForSoapType:[outParam objectForKey:@"type"]];
			
			NSString *convertedVariable = [self conversionFromNSStringToType:outParamType variable:@"result"];
			
			if (convertedVariable)
			{
				[classBody appendFormat:@"\treturn %@;\n", convertedVariable];
			}
			else
			{
				[classBody appendFormat:@"#error complex type '%@' not yet implemented\n", [outParam objectForKey:@"type"]];
			}
		}
		
		[classBody appendFormat:@"}\n\n", prototype];
	}
	
	[classBody appendString:@"\n@end"];
	
	
	//NSLog(@"%@", classHeader);
	//NSLog(@"%@", classBody);
	
	// 
	[classHeader writeToFile:headerFilename  atomically:NO encoding:NSUTF8StringEncoding error:nil];
	[classBody writeToFile:bodyFilename atomically:NO encoding:NSUTF8StringEncoding error:nil];
	
}

#pragma mark delegate methods
- (void) xmlDocumentDidFinish:(XMLdocument *)xmlDocuments
{
	[self processingAfterLoading];
}

@end
