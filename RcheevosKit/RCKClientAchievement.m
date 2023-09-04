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


@end
