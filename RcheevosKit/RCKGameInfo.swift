//
//  GameInfo.swift
//  RcheevosKit
//
//  Created by C.W. Betts on 9/3/23.
//

import Foundation
#if os(OSX)
import Cocoa
#endif
@_implementationOnly import rcheevos

@objc(RCKGameInfo) @objcMembers
final public class GameInfo: NSObject, NSSecureCoding, Codable {
	public let identifier: UInt32
	public let consoleID: RCKConsoleIdentifier
	public let title: String
	public let gameHash: String
	public let badgeName: String
	
	public let imageURL: URL?
	
#if os(OSX)
	private(set) public lazy var image: NSImage? = {
		if let imageURL {
			return NSImage(contentsOf: imageURL)
		}
		return nil
	}()
#endif
	
	@nonobjc
	internal init(gi: UnsafePointer<rc_client_game_t>) {
		var url = [CChar](repeating: 0, count: 1024)
		if rc_client_game_get_image_url(gi, &url, url.count) == RC_OK {
			imageURL = URL(string: String(cString: url))
		} else {
			imageURL = nil
		}
		identifier = gi.pointee.id
		consoleID = RCKConsoleIdentifier(rawValue: Int32(bitPattern: gi.pointee.console_id))!
		title = String(cString: gi.pointee.title)
		gameHash = String(cString: gi.pointee.hash)
		badgeName = String(cString: gi.pointee.badge_name)
	}
	
	public override var description: String {
		return "\(title) hash \(gameHash), console \(consoleID.name)"
	}
	
	public static var supportsSecureCoding: Bool {
		return true
	}
	
	public func encode(with coder: NSCoder) {
		coder.encode(Int32(bitPattern: identifier), forKey: GameInfo.CodingKeys.identifier.stringValue)
		coder.encode(consoleID.rawValue, forKey: GameInfo.CodingKeys.consoleID.stringValue)
		coder.encode(title as NSString, forKey: GameInfo.CodingKeys.title.stringValue)
		coder.encode(gameHash as NSString, forKey: GameInfo.CodingKeys.gameHash.stringValue)
		coder.encode(badgeName as NSString, forKey: GameInfo.CodingKeys.badgeName.stringValue)
		coder.encodeConditionalObject(imageURL as NSURL?, forKey: GameInfo.CodingKeys.imageURL.stringValue)
	}
	
	public required init?(coder: NSCoder) {
		identifier = UInt32(bitPattern: coder.decodeInt32(forKey: GameInfo.CodingKeys.identifier.stringValue))
		let preconsole = coder.decodeInt32(forKey: GameInfo.CodingKeys.consoleID.stringValue)
		guard let postConsole = RCKConsoleIdentifier(rawValue: preconsole) else {
			coder.failWithError(CocoaError(.coderInvalidValue))
			return nil
		}
		consoleID = postConsole
		guard let preTitle = coder.decodeObject(of: NSString.self, forKey: GameInfo.CodingKeys.title.stringValue) as String? else {
			coder.failWithError(CocoaError(.coderValueNotFound))
			return nil
		}
		title = preTitle
		guard let preHash = coder.decodeObject(of: NSString.self, forKey: GameInfo.CodingKeys.gameHash.stringValue) as String? else {
			coder.failWithError(CocoaError(.coderValueNotFound))
			return nil
		}
		gameHash = preHash
		guard let preBadge = coder.decodeObject(of: NSString.self, forKey: GameInfo.CodingKeys.badgeName.stringValue) as String? else {
			coder.failWithError(CocoaError(.coderValueNotFound))
			return nil
		}
		badgeName = preBadge
		
		imageURL = coder.decodeObject(of: NSURL.self, forKey: GameInfo.CodingKeys.imageURL.stringValue) as URL?
	}
}
