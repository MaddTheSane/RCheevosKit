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
	final class Leaderboard: NSObject, Codable {
		
		@objc(RCKClientLeaderboardState)
		public enum State: UInt8, Codable {
			case inactive = 0
			case active
			case tracking
			case disabled
		}
		
		@objc(RCKClientLeaderboardFormat)
		public enum Format: UInt8, Codable {
			case time = 0
			case score
			case value
		}
		
		public let title: String
		public let leaderboardDescription: String
		public let trackerValue: String
		public let identifier: UInt32
		public let state: State
		public let format: Format
		public let lowerIsBetter: Bool

		@nonobjc
		internal init(leaderboard: UnsafePointer<rc_client_leaderboard_t>?) {
			let lb = leaderboard!.pointee
			title = String(cString: lb.title)
			leaderboardDescription = String(cString: lb.description)
			trackerValue = String(cString: lb.tracker_value)
			identifier = lb.id
			state = State(rawValue: lb.state)!
			format = Format(rawValue: lb.format)!
			lowerIsBetter = lb.lower_is_better != 0
			super.init()
		}
		
		public override var description: String {
			return "\(title), \(leaderboardDescription). \(state)"
		}
		
		public override var debugDescription: String {
			return "\(title), \(leaderboardDescription) Tracker value: \(trackerValue) state: \(state)"
		}
		
		@objc(RCKClientLeaderboardScoreboard) @objcMembers
		final public class Scoreboard: NSObject, Codable {
			/// Used for scoreboard events. Contains the response from the server when a leaderboard entry is submitted.
			@objc(RCKClientLeaderboardScoreboardEntry) @objcMembers
			final public class Entry: NSObject, Codable {
				/// The user associated to the entry.
				public let userName: String
				/// The rank of the entry.
				public let rank: UInt32
				/// The value of the entry.
				public let score: String
				
				@nonobjc
				internal init(entry: rc_client_leaderboard_scoreboard_entry_t) {
					userName = String(cString: entry.username)
					rank = entry.rank
					var preScore = entry.score
					var preScore2 = [CChar](repeating: 0, count: Int(RC_CLIENT_LEADERBOARD_DISPLAY_SIZE)+1)
					memcpy(&preScore2, &preScore, MemoryLayout.size(ofValue: entry.score))
					score = String(cString: preScore2)
					
					super.init()
				}
			}
			
			/// The ID of the leaderboard which was submitted.
			public let leaderboardID: UInt32
			/// The value that was submitted.
			public let submittedScore: String
			/// The player's best submitted value.
			public let bestScore: String
			/// The player's new rank within the leaderboard.
			public let newRank: UInt32
			/// The total number of entries in the leaderboard.
			public let totalEntries: Int
			
			/// An array of the top entries for the leaderboard.
			public let topEntries: [Entry]
			
			@nonobjc
			internal init(scoreboard: UnsafePointer<rc_client_leaderboard_scoreboard_t>) {
				leaderboardID = scoreboard.pointee.leaderboard_id
				
				var preScore = scoreboard.pointee.submitted_score
				var preScore2 = [CChar](repeating: 0, count: Int(RC_CLIENT_LEADERBOARD_DISPLAY_SIZE)+1)
				memcpy(&preScore2, &preScore, MemoryLayout.size(ofValue: scoreboard.pointee.submitted_score))
				submittedScore = String(cString: preScore2)

				preScore = scoreboard.pointee.best_score
				preScore2 = [CChar](repeating: 0, count: Int(RC_CLIENT_LEADERBOARD_DISPLAY_SIZE)+1)
				memcpy(&preScore2, &preScore, MemoryLayout.size(ofValue: scoreboard.pointee.submitted_score))
				bestScore = String(cString: preScore2)
				
				newRank = scoreboard.pointee.new_rank
				totalEntries = Int(scoreboard.pointee.num_entries)
				let ourTopEntries = UnsafeBufferPointer(start: scoreboard.pointee.top_entries, count: Int(scoreboard.pointee.num_top_entries))
				topEntries = ourTopEntries.map({Entry(entry: $0)})
			}
		}
	}
}
