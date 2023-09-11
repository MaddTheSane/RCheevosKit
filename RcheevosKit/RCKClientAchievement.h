//
//  RCKUser.h
//  RcheevosKit
//
//  Created by C.W. Betts on 8/29/23.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(uint8_t, RCKClientAchievementState) {
	/*! unprocessed */
	RCKClientAchievementStateInactive = 0,
	/*! eligible to trigger */
	RCKClientAchievementStateActive,
	/*! earned by user */
	RCKClientAchievementStateUnlocked,
	/*! not supported by this version of the runtime */
	RCKClientAchievementStateDisabled
} NS_SWIFT_NAME(RCKClientAchievement.State);

typedef NS_OPTIONS(uint8_t, RCKClientAchievementCategory) {
	RCKClientAchievementCategoryNone = 0,
	RCKClientAchievementCategoryCore = 1 << 0,
	RCKClientAchievementCategoryUnofficial = 1 << 1,
	RCKClientAchievementCategoryCoreAndUnofficial = RCKClientAchievementCategoryCore | RCKClientAchievementCategoryUnofficial
} NS_SWIFT_NAME(RCKClientAchievement.Category);

typedef NS_ENUM(uint8_t, RCKClientAchievementBucketType) {
	RCKClientAchievementBucketUnknown = 0,
	RCKClientAchievementBucketLocked,
	RCKClientAchievementBucketUnlocked,
	RCKClientAchievementBucketUnsupported,
	RCKClientAchievementBucketUnofficial,
	RCKClientAchievementBucketRecentlyUnlocked,
	RCKClientAchievementBucketActiveChallenge,
	RCKClientAchievementBucketAlmostThere
} NS_SWIFT_NAME(RCKClientAchievement.BucketType);

typedef NS_OPTIONS(uint8_t, RCKClientAchievementUnlocked) {
	RCKClientAchievementUnlockedNone = 0,
	RCKClientAchievementUnlockedSoftcore = 1 << 0,
	RCKClientAchievementUnlockedHardcore = 1 << 1,
	RCKClientAchievementUnlockedBoth = RCKClientAchievementUnlockedSoftcore | RCKClientAchievementUnlockedHardcore
} NS_SWIFT_NAME(RCKClientAchievement.Unlocked);

@interface RCKClientAchievement : NSObject <NSSecureCoding>

- (instancetype)init UNAVAILABLE_ATTRIBUTE;
- (instancetype)initWithRetroPointer:(const void*)ptr stateIcon:(RCKClientAchievementState)state NS_DESIGNATED_INITIALIZER;
- (nullable instancetype)initWithCoder:(nonnull NSCoder *)coder NS_DESIGNATED_INITIALIZER;

@property (readonly, copy) NSString *title;
@property (readonly, copy) NSString *achievementDescription;
@property (readonly, copy) NSString *badgeName;
@property (readonly, copy) NSString *measuredProgress;
@property (readonly) float measuredPercent;
@property (readonly) uint32_t identifier;
@property (readonly) uint32_t points;
@property (readonly, copy) NSDate *unlockTime;
@property (readonly) RCKClientAchievementState state;
@property (readonly) RCKClientAchievementCategory category;
@property (readonly) RCKClientAchievementBucketType bucket;
@property (readonly) RCKClientAchievementUnlocked unlocked;

@property (readonly, copy, nullable) NSURL *currentIconURL;

@end

NS_ASSUME_NONNULL_END
