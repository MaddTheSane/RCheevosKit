//
//  GameInfo.swift
//  RcheevosKit
//
//  Created by C.W. Betts on 9/3/23.
//

import Foundation
@_implementationOnly import rcheevos

@objc(RCKGameInfo) @objcMembers
public class GameInfo: NSObject {
	public let identifier: UInt32
	public let consoleID: RCKConsoleIdentifier
	public let title: String
	public let gameHash: String
	public let badgeName: String
	
	public let imageURL: URL?
	
	internal init(gi: UnsafePointer<rc_client_game_t>) {
		var url = [CChar](repeating: 0, count: 1024)
		if rc_client_game_get_image_url(gi, &url, url.count) == RC_OK {
			imageURL = URL(string: String(cString: url))
		} else {
			imageURL = nil
		}
		identifier = gi.pointee.id
		consoleID = RCKConsoleIdentifier(rawValue: Int32(gi.pointee.console_id))!
		title = String(cString: gi.pointee.title)
		gameHash = String(cString: gi.pointee.hash)
		badgeName = String(cString: gi.pointee.badge_name)
	}
}
