//
//  RCKUser.h
//  RcheevosKit
//
//  Created by C.W. Betts on 8/29/23.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

typedef NS_OPTIONS(uint8_t, RCKClientAchievementCategory) {
	RCKClientAchievementCategoryNone = 0,
	RCKClientAchievementCategoryCore = 1 << 0,
	RCKClientAchievementCategoryUnofficial = 1 << 1,
	RCKClientAchievementCategoryCoreAndUnofficial = RCKClientAchievementCategoryCore | RCKClientAchievementCategoryUnofficial
};

typedef NS_OPTIONS(uint8_t, RCKClientAchievementUnlocked) {
	RCKClientAchievementUnlockedNone = 0,
	RCKClientAchievementUnlockedSoftcore = 1 << 0,
	RCKClientAchievementUnlockedHardcore = 1 << 1,
	RCKClientAchievementUnlockedBoth = RCKClientAchievementUnlockedSoftcore | RCKClientAchievementUnlockedHardcore
};

NS_ASSUME_NONNULL_END
