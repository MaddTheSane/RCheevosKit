//
//  RCKClientAchievementBucket.swift
//  RcheevosKit
//
//  Created by C.W. Betts on 9/2/23.
//

import Foundation
@_implementationOnly import rcheevos

@objc(RCKClientAchievementBucket) @objcMembers
public class ClientAchievementBucket: NSObject {
	public typealias BucketType = RCKClientAchievement.BucketType
	
	public let label: String
	public let subsetID: UInt32
	public let bucketType: BucketType
	public let achievements: [RCKClientAchievement]
	public let achievementImageURLs: [URL]
	
	public let achievementsAndImageURLs: [(RCKClientAchievement, URL?)]
	
	internal init(rcheevo: rc_client_achievement_bucket_t) {
		label = String(cString: rcheevo.label)
		subsetID = rcheevo.subset_id
		bucketType = BucketType(rawValue: rcheevo.bucket_type)!
		
		let cAchievements = UnsafeBufferPointer(start: rcheevo.achievements, count: Int(rcheevo.num_achievements))
		achievements = cAchievements.map({RCKClientAchievement(retroPointer: $0!, stateIcon: RCKClientAchievement.State(rawValue: $0!.pointee.state) ?? .disabled)})
		let aURLs = cAchievements.map { achieve -> URL? in
			var url = [CChar](repeating: 0, count: 1024)
			var actualURL: URL? = nil

			if rc_client_achievement_get_image_url(achieve, Int32(achieve!.pointee.state), &url, url.count) == RC_OK {
				actualURL = URL(string: String(cString: url))
			}
			return actualURL
		}
		achievementsAndImageURLs = Array(zip(achievements, aURLs))
		achievementImageURLs = aURLs.map({$0 ?? URL(fileURLWithPath: "/dev/null")})
	}
}
