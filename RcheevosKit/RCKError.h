//
//  RCKError.h
//  RcheevosKit
//
//  Created by C.W. Betts on 9/2/23.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

#ifndef RCK_ERROR_ENUM
#define __RCK_ERROR_ENUM_GET_MACRO(_0, _1, _2, NAME, ...) NAME
#if ((__cplusplus && __cplusplus >= 201103L && (__has_extension(cxx_strong_enums) || __has_feature(objc_fixed_enum))) || (!__cplusplus && __has_feature(objc_fixed_enum))) && __has_attribute(ns_error_domain)
#define __RCK_NAMED_ERROR_ENUM(_type, _domain, _name)     enum _name : _type _name; enum __attribute__((ns_error_domain(_domain))) _name : _type
#define __RCK_ANON_ERROR_ENUM(_type, _domain)             enum __attribute__((ns_error_domain(_domain))) : _type
#else
#define __RCK_NAMED_ERROR_ENUM(_type, _domain, _name) NS_ENUM(_type, _name)
#define __RCK_ANON_ERROR_ENUM(_type, _domain) NS_ENUM(_type)
#endif

#define RCK_ERROR_ENUM(...) __RCK_ERROR_ENUM_GET_MACRO(__VA_ARGS__, __RCK_NAMED_ERROR_ENUM, __RCK_ANON_ERROR_ENUM)(__VA_ARGS__)
#endif


FOUNDATION_EXPORT NSErrorDomain const RCKErrorDomain;
/// Internally maps to `rc_error.h`.
typedef RCK_ERROR_ENUM(int, RCKErrorDomain, RCKError) {
	RCKErrorInvalidLuaOperand = -1,
	RCKErrorInvalidMemoryOperand = -2,
	RCKErrorInvalidConstOperand = -3,
	RCKErrorInvalidFPOperand = -4,
	RCKErrorInvalidConditionType = -5,
	RCKErrorInvalidOperator = -6,
	RCKErrorInvalidRequiredHits = -7,
	RCKErrorDuplicatedStart = -8,
	RCKErrorDuplicatedCancel = -9,
	RCKErrorDuplicatedSubmit = -10,
	RCKErrorDuplicatedValue = -11,
	RCKErrorDuplicatedProgress = -12,
	RCKErrorMissingStart = -13,
	RCKErrorMissingCancel = -14,
	RCKErrorMissingSubmit = -15,
	RCKErrorMissingValue = -16,
	RCKErrorInvalidLeaderboardField = -17,
	RCKErrorMissingDisplayString = -18,
	RCKErrorOutOfMemory = -19,
	RCKErrorInvalidValueFlag = -20,
	RCKErrorMissingValueMeasured = -21,
	RCKErrorMultipleMeasured = -22,
	RCKErrorInvalidMeasuredTarget = -23,
	RCKErrorInvalidComparison = -24,
	RCKErrorInvalidState = -25,
	RCKErrorInvalidJSON = -26,
	RCKErrorAPIFailure = -27,
	RCKErrorLoginRequired = -28,
	RCKErrorNoGameLoaded = -29,
	RCKErrorHardcoreDisabled = -30,
	RCKErrorAborted = -31,
	RCKErrorNoResponse = -32,
	RCKErrorAccessDenied = -33,
	RCKErrorInvalidCredentials = -34,
	RCKErrorExpiredToken = -35
};

static const RCKError RCKErrorMissingSubmig API_DEPRECATED_WITH_REPLACEMENT("RCKErrorMissingSubmit", macos(10.13, 11.0), ios(10.13, 11.0), tvos(10.13, 11.0)) = RCKErrorMissingSubmit;

NS_ASSUME_NONNULL_END
