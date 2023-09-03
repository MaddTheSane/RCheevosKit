//
//  RCKClientLeaderboard.swift
//  RcheevosKit
//
//  Created by C.W. Betts on 9/1/23.
//

import Foundation
@_implementationOnly import rcheevos.rc_client

public extension Client {
	@objc(RCKClientLeaderboard) @objcMembers
	class Leaderboard: NSObject, Codable {
		
		@objc(RCKClientLeaderboardState)
		public enum State: UInt8, Codable {
			case inactive = 0
			case active
			case tracking
			case disabled
		}
		
		public let title: String
		public let leaderboardDescription: String
		public let trackerValue: String
		public let identifier: UInt32
		public let state: State
		public let lowerIsBetter: Bool

		internal init(leaderboard: UnsafePointer<rc_client_leaderboard_t>?) {
			let lb = leaderboard!.pointee
			title = String(cString: lb.title)
			leaderboardDescription = String(cString: lb.description)
			trackerValue = String(cString: lb.tracker_value)
			identifier = lb.id
			state = State(rawValue: lb.state)!
			lowerIsBetter = lb.lower_is_better != 0
			super.init()
		}
		
		public override var description: String {
			return "\(title), \(leaderboardDescription). \(state)"
		}
		
		public override var debugDescription: String {
			return "\(title), \(leaderboardDescription) Tracker value: \(trackerValue)"
		}
	}
}
