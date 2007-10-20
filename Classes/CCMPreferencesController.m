
#import "CCMPreferencesController.h"
#import "CCMUserDefaultsManager.h"
#import "CCMConnection.h"
#import "CCMServer.h"
#import "NSArray+CCMAdditions.h"
#import <EDCommon/EDCommon.h>

#define WINDOW_TITLE_HEIGHT 78

NSString *CCMPreferencesChangedNotification = @"CCMPreferencesChangedNotification";


@implementation CCMPreferencesController

- (NSURL *)getServerURL
{
	NSString *serverUrl = [serverUrlComboBox stringValue];
	if(![serverUrl hasPrefix:@"http://"])
	{
		serverUrl = [@"http://" stringByAppendingString:serverUrl];
		[serverUrlComboBox setStringValue:serverUrl];
	}
	NSArray *allFilenames = [NSArray arrayWithObjects:@"cctray.xml", @"xml", @"XmlStatusReport.aspx", @"XmlStatusReport.aspx", @"", nil];
	NSString *filename = [allFilenames objectAtIndex:[serverTypeMatrix selectedTag]];
	if(([serverUrl length] > 0) && (![serverUrl hasSuffix:filename]))
	{
		if(![serverUrl hasSuffix:@"/"])
			serverUrl = [serverUrl stringByAppendingString:@"/"];
		serverUrl = [serverUrl stringByAppendingString:filename];
	}
	return [NSURL URLWithString:serverUrl];
}

- (void)showWindow:(id)sender
{
	if(preferencesWindow == nil)
	{
		[NSBundle loadNibNamed:@"Preferences" owner:self];
		[preferencesWindow center];
		[preferencesWindow setToolbar:[self createToolbarWithName:@"Preferences"]];
		[[preferencesWindow toolbar] setSelectedItemIdentifier:@"Projects"];
		[self switchPreferencesPane:self];
		[versionField setStringValue:[[[NSBundle mainBundle] infoDictionary] objectForKey:@"CFBundleVersion"]];
	}
	[NSApp activateIgnoringOtherApps:YES];
	[preferencesWindow makeKeyAndOrderFront:self];	
}

- (void)switchPreferencesPane:(id)sender
{
	NSString *selectedIdentifier = [[preferencesWindow toolbar] selectedItemIdentifier];
	int index = [[self toolbarDefaultItemIdentifiers:nil] indexOfObject:selectedIdentifier];
	NSArray *allViews = [NSArray arrayWithObjects:projectsView, notificationPrefsView, advancedPrefsView, nil];
	NSView *prefView = [allViews objectAtIndex:index];
	NSDictionary *itemDef = [[toolbarDefinition objectForKey:@"itemInfoByIdentifier"] objectForKey:selectedIdentifier];
	[preferencesWindow setTitle:[itemDef objectForKey:@"label"]]; 

	NSRect windowFrame = [preferencesWindow frame];
	windowFrame.size.height = [prefView frame].size.height + WINDOW_TITLE_HEIGHT;
	windowFrame.size.width = [prefView frame].size.width;
	windowFrame.origin.y = NSMaxY([preferencesWindow frame]) - ([prefView frame].size.height + WINDOW_TITLE_HEIGHT);
	
	if([[paneHolderView subviews] count] > 0)
		[[[paneHolderView subviews] firstObject] removeFromSuperview];
	[preferencesWindow setFrame:windowFrame display:YES animate:(sender != self)];
	
	[paneHolderView setFrame:[prefView frame]];
	[paneHolderView addSubview:prefView];
}

- (void)addProjects:(id)sender
{
	NSArray *urls = [defaultsManager serverURLHistory];
	if([urls count] > 0)
	{
		[serverUrlComboBox removeAllItems];
		urls = [urls sortedArrayUsingSelector:@selector(caseInsensitiveCompare:)];
		[serverUrlComboBox addItemsWithObjectValues:urls];
	}
	[sheetTabView selectFirstTabViewItem:self];
	[NSApp beginSheet:addProjectsSheet modalForWindow:preferencesWindow modalDelegate:self 
		didEndSelector:@selector(addProjectsSheetDidEnd:returnCode:contextInfo:) contextInfo:nil];
}


- (NSArray *)convertProjectInfos:(NSArray *)projectInfos withServerUrl:(NSString *)serverUrl 
{
	NSMutableArray *result = [NSMutableArray array];
	NSEnumerator *projectInfoEnum = [projectInfos objectEnumerator];
	NSDictionary *projectInfo;
	while((projectInfo = [projectInfoEnum nextObject]) != nil)
	{
		NSMutableDictionary *listEntry = [NSMutableDictionary dictionary];
		NSString *projectName = [projectInfo objectForKey:@"name"];
		[listEntry setObject:projectName forKey:@"name"];
		if([defaultsManager projectListContainsProject:projectName onServerWithURL:serverUrl])
			[listEntry setObject:[NSColor disabledControlTextColor] forKey:@"textColor"];
		[result addObject:listEntry];
	}
	return result;
}

- (void)chooseProjects:(id)sender
{
	@try 
	{
		[testServerProgressIndicator startAnimation:self];
		NSURL *serverUrl = [self getServerURL];
		CCMConnection *connection = [[[CCMConnection alloc] initWithURL:serverUrl] autorelease];
		NSArray *projectInfos = [connection getProjectInfos];
		[testServerProgressIndicator stopAnimation:self];
		[chooseProjectsViewController setContent:[self convertProjectInfos:projectInfos withServerUrl:[serverUrl absoluteString]]];
		[sheetTabView selectNextTabViewItem:self];
	}
	@catch(NSException *exception) 
	{
		[testServerProgressIndicator stopAnimation:self];
		NSRunAlertPanel(@"Connection failure", @"Could not connect to server. %@", @"Cancel", nil, nil, [exception reason]);
	}
}

- (void)closeAddProjectsSheet:(id)sender
{
	[NSApp endSheet:addProjectsSheet returnCode:[sender tag]];
}

- (void)addProjectsSheetDidEnd:(NSWindow *)sheet returnCode:(int)returnCode contextInfo:(void *)contextInfo
{
	[addProjectsSheet orderOut:self];
	if(returnCode == 0)
		return;

	NSEnumerator *selectionEnum = [[chooseProjectsViewController selectedObjects] objectEnumerator];
	NSDictionary *entry;
	NSString *serverUrl = [[self getServerURL] absoluteString];
	while((entry = [selectionEnum nextObject]) != nil)
		[defaultsManager addProject:[entry objectForKey:@"name"] onServerWithURL:serverUrl];
	[defaultsManager addServerURLToHistory:serverUrl];
	[self preferencesChanged:self];
}

- (IBAction)removeProjects:(id)sender
{
	[allProjectsViewController remove:sender];
	[self preferencesChanged:sender];
}

- (void)preferencesChanged:(id)sender
{
	[[NSNotificationCenter defaultCenter] postNotificationName:CCMPreferencesChangedNotification object:sender];
}

- (IBAction)updateIntervalChanged:(id)sender
{
	[updater scheduleCheckWithInterval:[sender selectedTag]];
}

- (IBAction)checkForUpdateNow:(id)sender
{
	[updater checkForUpdates:sender];
}

@end
