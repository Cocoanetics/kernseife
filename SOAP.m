#import <Foundation/Foundation.h>

#import "WSDLdocument.h"
//#import "AppNotifications.h"

//#import "APIAPPlyzer.h"
#import "NSString+Helpers.h"
//#import "NSData+Helpers.h"
//#import "DDData.h"


void showUsage()
{
	printf("SOAP objC Proxy Class Builder\n");
	printf("Usage: SOAP <source>\n");
	printf("   <source> path or URL\n\n");
}


int main (int argc, const char * argv[]) {
    NSAutoreleasePool * pool = [[NSAutoreleasePool alloc] init];

	
	if (argc<2)
	{
		showUsage();
		exit(1);
	}
	
	NSString *source = [NSString stringWithCString:argv[1] encoding:NSUTF8StringEncoding];
	
	// try as URL
	NSURL *url = [NSURL URLWithString:source];
	
	if (!url)
	{
		// try as file
		url = [NSURL fileURLWithPath:source];
	}
	
	if (!url)
	{
		printf("ERROR: URL '%s' is not a file or URL\n", [source UTF8String]);
		exit(1);
	}
	
	WSDLdocument *wsdl = [[[WSDLdocument alloc] initWithContentsOfURL:url] autorelease];
	
	NSArray *ports = [wsdl portNames];
	
	if ([ports count]==0)
	{
		printf("ERROR: No ports found in WSDL\n");
		exit(1);
	}
	
	
	printf("These ports where found:\n");
	
	for (NSString *onePortName in ports)
	{
		printf("- %s", [onePortName UTF8String]);
	}
	
	printf("\n");
		
	
	printf("Writing class files for first port\n");
	
	[wsdl writeClassFilesForPort:[ports objectAtIndex:0]];
	
	printf("Done. \n");
	
    [pool drain];
    return 0;
}
