
#import <SenTestingKit/SenTestingKit.h>
#import <OCMock/OCMock.h>
#import "CCMPreferencesController.h"


@interface CCMPreferencesControllerTest : SenTestCase 
{
	CCMPreferencesController *controller;
	OCMockObject *defaultsManagerMock;
}

@end
