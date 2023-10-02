//
//  RCKClientAchievementBucket.swift
//  RcheevosKit
//
//  Created by C.W. Betts on 9/2/23.
//

import Foundation
@_implementationOnly import rcheevos

public extension Client.Achievement {
@objc(RCKClientAchievementBucket) @objcMembers
class Bucket: NSObject {
	public typealias BucketType = Client.Achievement.BucketType
	
	public let label: String
	public let subsetID: UInt32
	public let bucketType: BucketType
	public let achievements: [Client.Achievement]
	public let achievementImageURLs: [URL]
	
	public let achievementsAndImageURLs: [(Client.Achievement, URL?)]
	
	@nonobjc
	internal init(rcheevo: rc_client_achievement_bucket_t) {
		label = String(cString: rcheevo.label)
		subsetID = rcheevo.subset_id
		bucketType = BucketType(rawValue: rcheevo.bucket_type)!
		
		let cAchievements = UnsafeBufferPointer(start: rcheevo.achievements, count: Int(rcheevo.num_achievements))
		achievements = cAchievements.map({Client.Achievement(retroPointer: $0!, stateIcon: Client.Achievement.State(rawValue: $0!.pointee.state) ?? .disabled)})
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
	
	public override var description: String {
		return "\(label), achievements count: \(achievements.count), bucket \(bucketType)"
	}
}
}
