//
//  RCKClientAchievement.swift
//  RcheevosKit
//
//  Created by C.W. Betts on 9/30/23.
//

import Foundation
#if os(OSX)
import Cocoa
#endif
@_implementationOnly import rcheevos
@_implementationOnly import rcheevos.rc_client

public extension Client {
	@objc(RCKClientAchievement) @objcMembers
	final class Achievement: NSObject, Codable, NSSecureCoding {
		@objc(RCKClientAchievementState)
		public enum State : UInt8, @unchecked Sendable, Codable, CustomStringConvertible {
			/// Unprocessed.
			case inactive = 0
			/// Eligible to trigger.
			case active = 1
			/// Earned by user.
			case unlocked = 2
			/// Not supported by this version of the runtime.
			case disabled = 3
			
			public var description: String {
				switch self {
				case .inactive:
					return "Inactive"
				case .active:
					return "Active"
				case .unlocked:
					return "Unlocked"
				case .disabled:
					return "Disabled"
				}
			}
		}
		
		public typealias Category = RCKClientAchievementCategory
		
		@objc(RCKClientAchievementBucketType)
		public enum BucketType : UInt8, @unchecked Sendable, Codable, CustomStringConvertible {
			case unknown = 0
			case locked = 1
			case unlocked = 2
			case unsupported = 3
			case unofficial = 4
			case recentlyUnlocked = 5
			case activeChallenge = 6
			case almostThere = 7
			
			public var description: String {
				switch self {
				case .unknown:
					return "Unknown"
				case .locked:
					return "Locked"
				case .unlocked:
					return "Unlocked"
				case .unsupported:
					return "Unsupported"
				case .unofficial:
					return "Unofficial"
				case .recentlyUnlocked:
					return "Recently Unlocked"
				case .activeChallenge:
					return "Active Challenge"
				case .almostThere:
					return "Almost There"
				}
			}
		}
		
		public typealias Unlocked = RCKClientAchievementUnlocked
		
		@objc(RCKClientAchievementListGrouping)
		public enum ListGrouping : Int32, @unchecked Sendable, Codable {
			case lockState = 0
			case progress = 1
		}

		@nonobjc
		internal init(retroPointer: UnsafePointer<rc_client_achievement_t>, stateIcon: State) {
			var cUrl = [CChar](repeating: 0, count: 512)
			if rc_client_achievement_get_image_url(retroPointer, Int32(stateIcon.rawValue), &cUrl, cUrl.count) == RC_OK {
				let nsURL = String(cString: cUrl)
				currentIconURL = URL(string: nsURL)
			} else {
				currentIconURL = nil
			}
			
			title = String(cString: retroPointer.pointee.title)
			achievementDescription = String(cString: retroPointer.pointee.description)
			do {
				cUrl.withUnsafeMutableBytes { umrbp in
					_=memset(umrbp.baseAddress, 0, umrbp.count)
				}
				var tmpBadgeName = retroPointer.pointee.badge_name
				memcpy(&cUrl, &tmpBadgeName, MemoryLayout.size(ofValue: retroPointer.pointee.badge_name))
				badgeName = String(cString: cUrl)
			}
			do {
				cUrl.withUnsafeMutableBytes { umrbp in
					_=memset(umrbp.baseAddress, 0, umrbp.count)
				}
				var tmpBadgeName = retroPointer.pointee.measured_progress
				memcpy(&cUrl, &tmpBadgeName, MemoryLayout.size(ofValue: retroPointer.pointee.measured_progress))
				measuredProgress = String(cString: cUrl)
			}

			measuredPercent = retroPointer.pointee.measured_percent
			identifier = retroPointer.pointee.id
			points = retroPointer.pointee.points
			if retroPointer.pointee.unlock_time == 0 {
				unlockTime = nil
			} else {
				unlockTime = Date(timeIntervalSince1970: TimeInterval(retroPointer.pointee.unlock_time))
			}
			state = Client.Achievement.State(rawValue: retroPointer.pointee.state)!
			category = Client.Achievement.Category(rawValue: retroPointer.pointee.category)
			bucket = Client.Achievement.BucketType(rawValue: retroPointer.pointee.bucket)!
			unlocked = Client.Achievement.Unlocked(rawValue: retroPointer.pointee.unlocked)
			super.init()
		}
		
		public let title: String
		public let achievementDescription: String
		public let badgeName: String
		public let measuredProgress: String
		public let measuredPercent: Float
		public let identifier: UInt32
		public let points: UInt32
		/// Will be `nil` if the achievement is still locked.
		public let unlockTime: Date?
		public let state: State
		public let category: Category
		public let bucket: BucketType
		public let unlocked: Unlocked
		
		public let currentIconURL: URL?
		
#if os(OSX)
	private(set) public lazy var currentIcon: NSImage? = {
		if let imageURL = self.currentIconURL {
			return NSImage(contentsOf: imageURL)
		}
		return nil
	}()
#endif
		
		public static var supportsSecureCoding: Bool { return true }
		
		public func encode(with coder: NSCoder) {
			coder.encode(Int32(bitPattern: identifier), forKey: Achievement.CodingKeys.identifier.stringValue)
			coder.encode(Int32(bitPattern: points), forKey: Achievement.CodingKeys.points.stringValue)
			coder.encode(title as NSString, forKey: Achievement.CodingKeys.title.stringValue)
			coder.encode(achievementDescription as NSString, forKey: Achievement.CodingKeys.achievementDescription.stringValue)
			coder.encode(badgeName as NSString, forKey: Achievement.CodingKeys.badgeName.stringValue)
			coder.encode(measuredProgress as NSString, forKey: Achievement.CodingKeys.measuredProgress.stringValue)
			coder.encode(measuredPercent, forKey: Achievement.CodingKeys.measuredPercent.stringValue)
			coder.encodeConditionalObject(unlockTime as NSDate?, forKey: Achievement.CodingKeys.unlockTime.stringValue)

			coder.encode(Int32(state.rawValue), forKey: Achievement.CodingKeys.state.stringValue)
			coder.encode(Int32(category.rawValue), forKey: Achievement.CodingKeys.category.stringValue)
			coder.encode(Int32(bucket.rawValue), forKey: Achievement.CodingKeys.bucket.stringValue)
			coder.encode(Int32(unlocked.rawValue), forKey: Achievement.CodingKeys.unlocked.stringValue)
			
			coder.encodeConditionalObject(currentIconURL as NSURL?, forKey: Achievement.CodingKeys.currentIconURL.stringValue)
		}
		
		public required init?(coder: NSCoder) {
			identifier = UInt32(bitPattern: coder.decodeInt32(forKey: Achievement.CodingKeys.identifier.stringValue))
			points = UInt32(bitPattern: coder.decodeInt32(forKey: Achievement.CodingKeys.points.stringValue))
			if let aDate = coder.decodeObject(of: NSDate.self, forKey: Achievement.CodingKeys.unlockTime.stringValue) as Date?  {
				unlockTime = aDate
			} else {
				unlockTime = nil
			}
			guard let preTitle = coder.decodeObject(of: NSString.self, forKey: Achievement.CodingKeys.title.stringValue) as String? else {
				coder.failWithError(CocoaError(.coderValueNotFound))
				return nil
			}
			title = preTitle
			guard let preDes = coder.decodeObject(of: NSString.self, forKey: Achievement.CodingKeys.achievementDescription.stringValue) as String? else {
				coder.failWithError(CocoaError(.coderValueNotFound))
				return nil
			}
			achievementDescription = preDes
			guard let preBadge = coder.decodeObject(of: NSString.self, forKey: Achievement.CodingKeys.badgeName.stringValue) as String? else {
				coder.failWithError(CocoaError(.coderValueNotFound))
				return nil
			}
			badgeName = preBadge
			guard let preProg1 = coder.decodeObject(of: NSString.self, forKey: Achievement.CodingKeys.measuredProgress.stringValue) as String? else {
				coder.failWithError(CocoaError(.coderValueNotFound))
				return nil
			}
			measuredProgress = preProg1
			
			measuredPercent = coder.decodeFloat(forKey: Achievement.CodingKeys.measuredPercent.stringValue)

			do {
				let preconsole = coder.decodeInt32(forKey: Achievement.CodingKeys.state.stringValue)
				guard let preconsole2 = UInt8(exactly: preconsole),
					  let postConsole = State(rawValue: preconsole2) else {
					coder.failWithError(CocoaError(.coderInvalidValue))
					return nil
				}
				state = postConsole
			}
			
			do {
				let preconsole = coder.decodeInt32(forKey: Achievement.CodingKeys.category.stringValue)
				guard let preconsole2 = UInt8(exactly: preconsole) else {
					coder.failWithError(CocoaError(.coderInvalidValue))
					return nil
				}
				category = Category(rawValue: preconsole2)
			}
			
			do {
				let preconsole = coder.decodeInt32(forKey: Achievement.CodingKeys.bucket.stringValue)
				guard let preconsole2 = UInt8(exactly: preconsole),
					let postConsole = BucketType(rawValue: preconsole2) else {
					coder.failWithError(CocoaError(.coderInvalidValue))
					return nil
				}
				bucket = postConsole
			}
			
			do {
				let preconsole = coder.decodeInt32(forKey: Achievement.CodingKeys.unlocked.stringValue)
				guard let preconsole2 = UInt8(exactly: preconsole) else {
					coder.failWithError(CocoaError(.coderInvalidValue))
					return nil
				}
				unlocked = Unlocked(rawValue: preconsole2)
			}
			
			currentIconURL = coder.decodeObject(of: NSURL.self, forKey: Achievement.CodingKeys.currentIconURL.stringValue) as URL?
			
			super.init()
		}
		
		public override var description: String {
			return "\(title): \(achievementDescription)"
		}
	}
}

extension RCKClientAchievementCategory: Codable {}
extension RCKClientAchievementUnlocked: Codable {}
