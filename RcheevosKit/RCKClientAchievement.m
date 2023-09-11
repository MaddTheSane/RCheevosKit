//
//  RCKUser.m
//  RcheevosKit
//
//  Created by C.W. Betts on 8/29/23.
//

#import "RCKClientAchievement.h"
#include "rc_client.h"

@implementation RCKClientAchievement

- (instancetype)initWithRetroPointer:(const void*)ptr stateIcon:(RCKClientAchievementState)state
{
	if (self = [super init]) {
		const rc_client_achievement_t* rcChev = ptr;
		char url[1024] = {0};
		if (rc_client_achievement_get_image_url(rcChev, state, url, sizeof(url))) {
			NSString *nsURL = @(url);
			_currentIconURL = [NSURL URLWithString:nsURL];
		}
		_title = @(rcChev->title);
		_achievementDescription = @(rcChev->description);
		_badgeName = @(rcChev->badge_name);
		_measuredProgress = @(rcChev->measured_progress);
		_measuredPercent = rcChev->measured_percent;
		_identifier = rcChev->id;
		_points = rcChev->points;
		_unlockTime = [NSDate dateWithTimeIntervalSince1970:rcChev->unlock_time];
		_state = rcChev->state;
		_category = rcChev->category;
		_bucket = rcChev->bucket;
		_unlocked = rcChev->unlocked;
	}
	return self;
}

#define TITLE_KEY @"RCKTitle"
#define ACHIEVEMENT_DESCRIPTION_KEY @"RCKAchievementDescription"
#define BADGE_NAME_KEY @"RCKBadgeName"
#define MEASURED_PROGRESS_KEY @"RCKMeasuredProgress"
#define MEASURED_PERCENT_KEY @"RCKMeasuredPercent"
#define IDENTIFIER_KEY @"RCKIdentifier"
#define POINTS_KEY @"RCKpoints"
#define UNLOCK_TIME_KEY @"RCKUnlockTime"
#define STATE_KEY @"RCKState"
#define CATEGORY_KEY @"RCKCategory"
#define BUCKET_KEY @"RCKBucket"
#define UNLOCKED_KEY @"RCKUnlocked"
#define CURRENT_ICON_URL_KEY @"RCKCurrentIconURL"

- (void)encodeWithCoder:(nonnull NSCoder *)coder {
	[coder encodeObject:_title forKey:TITLE_KEY];
	[coder encodeObject:_achievementDescription forKey:ACHIEVEMENT_DESCRIPTION_KEY];
	[coder encodeObject:_badgeName forKey:BADGE_NAME_KEY];
	[coder encodeObject:_measuredProgress forKey:MEASURED_PROGRESS_KEY];
	[coder encodeFloat:_measuredPercent forKey:MEASURED_PERCENT_KEY];
	[coder encodeInt32:_identifier forKey:IDENTIFIER_KEY];
	[coder encodeInt32:_points forKey:POINTS_KEY];
	[coder encodeObject:_unlockTime forKey:UNLOCK_TIME_KEY];
	[coder encodeInt:_state forKey:STATE_KEY];
	[coder encodeInt:_category forKey:CATEGORY_KEY];
	[coder encodeInt:_bucket forKey:BUCKET_KEY];
	[coder encodeInt:_unlocked forKey:UNLOCKED_KEY];

	[coder encodeConditionalObject:_currentIconURL forKey:CURRENT_ICON_URL_KEY];
}

- (nullable instancetype)initWithCoder:(nonnull NSCoder *)coder {
	if (self = [super init]) {
		//TODO: error checking
		_title = [coder decodeObjectOfClass:[NSString class] forKey:TITLE_KEY];
		_achievementDescription = [coder decodeObjectOfClass:[NSString class] forKey:ACHIEVEMENT_DESCRIPTION_KEY];
		_badgeName = [coder decodeObjectOfClass:[NSString class] forKey:BADGE_NAME_KEY];
		_measuredProgress = [coder decodeObjectOfClass:[NSString class] forKey:MEASURED_PROGRESS_KEY];
		_measuredPercent = [coder decodeFloatForKey:MEASURED_PERCENT_KEY];
		_identifier = [coder decodeInt32ForKey:IDENTIFIER_KEY];
		_points = [coder decodeInt32ForKey:POINTS_KEY];
		_unlockTime = [coder decodeObjectOfClass:[NSDate class] forKey:UNLOCK_TIME_KEY];
		_state = [coder decodeIntForKey:STATE_KEY];
		_category = [coder decodeIntForKey:CATEGORY_KEY];
		_bucket = [coder decodeIntForKey:BUCKET_KEY];
		_unlocked = [coder decodeIntForKey:UNLOCKED_KEY];
		
		_currentIconURL = [coder decodeObjectOfClass:[NSURL class] forKey:CURRENT_ICON_URL_KEY];
	}
	return self;
}

+ (BOOL)supportsSecureCoding {
	return YES;
}

@end
