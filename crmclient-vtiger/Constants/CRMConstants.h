//
//  CRMConstants.h
//  ContactiCalVtiger
//
//  Created by Giovanni on 12/04/14.
//  Copyright (c) 2014 gixWorks. All rights reserved.
//

#import <Foundation/Foundation.h>

extern NSString* const kErrorKey;
extern NSString* const kMinimumRequiredVersion;

extern NSString* const kCRMActivityTypeTask;
extern NSString* const kCRMActivityTypeCall;
extern NSString* const kCRMActivityTypeMeeting;

//TODO: These should ideally be loaded into database from the API
extern NSString* const kCRMActivityTaskStatusNotStarted;
extern NSString* const kCRMActivityTaskStatusInProgress;
extern NSString* const kCRMActivityTaskStatusCompleted;
extern NSString* const kCRMActivityTaskStatusPendingInput;
extern NSString* const kCRMActivityTaskStatusDeferred;
extern NSString* const kCRMActivityTaskStatusPlanned;

extern NSString *const kCRMActivityVisibilityPublic;
extern NSString *const kCRMActivityVisibilityPrivate;

extern NSString* const kCRMActivityCallMeetingStatusPlanned;
extern NSString* const kCRMActivityCallMeetingStatusHeld;
extern NSString* const kCRMActivityCallMeetingStatusNotHeld;

//Actions for ModifiedRecords table
extern NSString* const kModifiedRecordActionDELETE;
extern NSString* const kModifiedRecordActionUPDATE;

extern NSString *const kCalendarPrivate;
extern NSString *const kCalendarPublic;

@interface CRMConstants : NSObject

+ (NSArray*)allModules;

@end
