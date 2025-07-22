//
//  RCKClientSubset.swift
//  RcheevosKit
//
//  Created by C.W. Betts on 7/22/25.
//

import Foundation
#if os(OSX)
import Cocoa
#endif
@_implementationOnly import rcheevos.rc_client

public extension Client {
	@objc(RCKClientSubset) @objcMembers
	final class Subset: NSObject, Codable {
		@nonobjc
		internal init(subset: UnsafePointer<rc_client_subset_t>?) {
			let lb = subset!.pointee
			identifier = lb.id
			title = String(cString: lb.title)
			achievementCount = lb.num_achievements
			leaderboardCount = lb.num_leaderboards
			
			let preBadgeName = [lb.badge_name.0, lb.badge_name.1, lb.badge_name.2, lb.badge_name.3, lb.badge_name.4, lb.badge_name.5, lb.badge_name.6, lb.badge_name.7, lb.badge_name.8, lb.badge_name.9, lb.badge_name.10, lb.badge_name.11, lb.badge_name.12, lb.badge_name.13, lb.badge_name.14, lb.badge_name.15, 0]
			
			badgeName = String(cString: preBadgeName).trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : String(cString: preBadgeName)
			if let preBadgeURL = lb.badge_url {
				let aBadgeURL = String(cString: preBadgeURL)
				badgeURL = aBadgeURL.isEmpty ? nil : URL(string: aBadgeURL)
			} else {
				badgeURL = nil
			}
			
			super.init()
		}

		public let identifier: UInt32
		public let title: String
		
		public let achievementCount: UInt32
		public let leaderboardCount: UInt32
		
		let badgeName: String?
		let badgeURL: URL?
		
#if os(OSX)
	private(set) public lazy var badgeIcon: NSImage? = {
		if let imageURL = self.badgeURL {
			return NSImage(contentsOf: imageURL)
		}
		return nil
	}()
#endif

	}
}
