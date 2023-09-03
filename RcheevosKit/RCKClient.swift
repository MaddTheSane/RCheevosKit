//
//  RCKClient.swift
//  RcheevosKit
//
//  Created by C.W. Betts on 8/31/23.
//

import Foundation
@_implementationOnly import rcheevos
@_implementationOnly import rcheevos.rc_client

@objc(RCKClientDelegate)
public protocol ClientDelegate: NSObjectProtocol {
	@objc(readMemoryForClient:atAddress:toBuffer:count:)
	func readMemory(client: Client, at address: UInt32, to buffer: UnsafeMutablePointer<UInt8>?, count num_bytes: UInt32) -> UInt32
	
	@objc optional func loginSuccessful(client: Client)
	
	@objc(loginFailedForClient:withError:)
	optional func loginFailed(client: Client, with: Error)
	
	/// Make sure you call `Client.reset()` after the emulator has reset itself.
	func restartEmulationRequested(client: Client)
	
	@objc(gotAchievementForClient:achievement:URLForIcon:)
	optional func gotAchievement(client: Client, _ achievement: RCKClientAchievement, urlForIcon: URL?)
	
	@objc(leaderboardStartedForClient:leaderboard:)
	optional func leaderboardStarted(client: Client, _ leaderboard: Client.Leaderboard)
	
	@objc(leaderboardFailedForClient:leaderboard:)
	optional func leaderboardFailed(client: Client, _ leaderboard: Client.Leaderboard)
	
	@objc(leaderboardSubmittedForClient:leaderboard:)
	optional func leaderboardSubmitted(client: Client, _ leaderboard: Client.Leaderboard)
	
	func gameLoadedSuccessfully(client: Client)
	
	func gameFailedToLoad(client: Client, error: Error)
	
	@objc optional func gameChangedSuccessfully(client: Client)

	@objc optional func gameChangeFailed(client: Client, error: Error)

	@objc optional func gameCompleted(client: Client)
	
	@objc optional func serverError(client: Client, message: String?, api: String?)
}

/// Provides a wrapper around `rc_client_t`.
@objc(RCKClient) @objcMembers
public class Client: NSObject {
	private var _client: OpaquePointer?
	private var session: URLSession!
	public weak var delegate: ClientDelegate?
	
	public override init() {
		super.init()
		
		session = URLSession(configuration: .default)
	}
	
	private func serverCallback(request: UnsafePointer<rc_api_request_t>?,
								callback: rc_client_server_callback_t?,
								callback_data: UnsafeMutableRawPointer?,
								client: OpaquePointer?) {
		guard let theURL = URL(string: String(cString: request!.pointee.url)) else {
			var server_response = rc_api_server_response_t()
			server_response.body = nil
			server_response.body_length = 0
			server_response.http_status_code = 404

			callback?(&server_response, callback_data)
//			rc_api_destroy_request(request)
			return
		}
		var cocoaRequest = URLRequest(url: theURL)
		if let postCStr = request?.pointee.post_data {
			let postStr = String(cString: postCStr)
			cocoaRequest.httpBody = postStr.data(using: .utf8)
			cocoaRequest.httpMethod = "POST"
		}
		let task = session.dataTask(with: cocoaRequest) { dat, response, err in
			let trueResponse = response as! HTTPURLResponse
			var server_response = rc_api_server_response_t()
			server_response.http_status_code = Int32(trueResponse.statusCode)
			if let dat {
				dat.withUnsafeBytes { urbp in
					server_response.body = urbp.baseAddress?.assumingMemoryBound(to: Int8.self)
					server_response.body_length = urbp.count
					callback?(&server_response, callback_data)
				}
			} else {
				server_response.body = nil
				server_response.body_length = 0
				callback?(&server_response, callback_data)
			}
		}
		task.resume()
	}

	/// This is the function the `rc_client` will use to read memory for the emulator.
	private static func read_memory(_ address: UInt32, buffer: UnsafeMutablePointer<UInt8>?, num_bytes: UInt32, client: OpaquePointer?) -> UInt32
	{
		// RetroAchievements addresses start at $00000000, which normally represents the first physical byte
		// of memory for the system. Normally, an emulator stores it's RAM in a singular contiguous buffer,
		// which makes reading from a RetroAchievements address simple:
		//
		//   if (address + num_bytes >= RAM_size)
		//     return 0;
		//   memcpy(buffer, &RAM[address], num_bytes);
		//   return num_bytes;
		//
		// Sometimes an emulator only exposes a virtual BUS. In that case, it may be necessary to translate
		// the RetroAchievements address to a real address.
	//	uint32_t real_address = convert_retroachievements_address_to_real_address(address);
	//	return emulator_read_memory(real_address, buffer, num_bytes);
		guard let usrDat = rc_client_get_userdata(client) else {
			return 0
		}

		let theClass: Client = Unmanaged.fromOpaque(usrDat).takeUnretainedValue()
		if let classDel = theClass.delegate {
			return classDel.readMemory(client: theClass, at: address, to: buffer, count: num_bytes)
		}

		return 0;
	}

	private func leaderboardStarted(_ leaderboard: UnsafePointer<rc_client_leaderboard_t>?) {
		delegate?.leaderboardStarted?(client: self, Leaderboard(leaderboard: leaderboard))
	}
	
	private func leaderboardFailed(_ leaderboard: UnsafePointer<rc_client_leaderboard_t>?) {
		delegate?.leaderboardFailed?(client: self, Leaderboard(leaderboard: leaderboard))
	}

	private func leaderboardSubmitted(_ leaderboard: UnsafePointer<rc_client_leaderboard_t>?) {
		delegate?.leaderboardSubmitted?(client: self, Leaderboard(leaderboard: leaderboard))
	}
	
	public func start() {
		// Create the client instance
		//_client = rc_client_create(Client.read_memory, Client.server_call)
		_client = rc_client_create({ address, buffer, num_bytes, client in
			return Client.read_memory(address, buffer: buffer, num_bytes: num_bytes, client: client)
		}, { request, callback, callbackData, client in
			guard let usrDat = rc_client_get_userdata(client) else {
				return
			}
			let theClass: Client = Unmanaged.fromOpaque(usrDat).takeUnretainedValue()
			theClass.serverCallback(request: request, callback: callback, callback_data: callbackData, client: client)
		})
		
		rc_client_set_userdata(_client, Unmanaged.passUnretained(self).toOpaque())
		
		// Provide an event handler
		rc_client_set_event_handler(_client) { event, client in
			guard let event, let usrDat = rc_client_get_userdata(client) else {
				return
			}
			let aSelf: Client = Unmanaged.fromOpaque(usrDat).takeUnretainedValue()
			
			switch event.pointee.type {
			case UInt32(RC_CLIENT_EVENT_TYPE_NONE):
				//uh, cool?
				break
				
			case UInt32(RC_CLIENT_EVENT_ACHIEVEMENT_TRIGGERED):
				aSelf.achievementTriggered(event.pointee.achievement)
				
			case UInt32(RC_CLIENT_EVENT_LEADERBOARD_STARTED):
				aSelf.leaderboardStarted(event.pointee.leaderboard)
				
			case UInt32(RC_CLIENT_EVENT_LEADERBOARD_FAILED):
				aSelf.leaderboardFailed(event.pointee.leaderboard)
				
			case UInt32(RC_CLIENT_EVENT_LEADERBOARD_SUBMITTED):
				aSelf.leaderboardSubmitted(event.pointee.leaderboard)

			case UInt32(RC_CLIENT_EVENT_ACHIEVEMENT_CHALLENGE_INDICATOR_SHOW):
				break
				
			case UInt32(RC_CLIENT_EVENT_ACHIEVEMENT_CHALLENGE_INDICATOR_HIDE):
				break
				
			case UInt32(RC_CLIENT_EVENT_ACHIEVEMENT_PROGRESS_INDICATOR_SHOW):
				break
				
			case UInt32(RC_CLIENT_EVENT_ACHIEVEMENT_PROGRESS_INDICATOR_HIDE):
				break
				
			case UInt32(RC_CLIENT_EVENT_ACHIEVEMENT_PROGRESS_INDICATOR_UPDATE):
				break
				
			case UInt32(RC_CLIENT_EVENT_LEADERBOARD_TRACKER_SHOW):
				break
				
			case UInt32(RC_CLIENT_EVENT_LEADERBOARD_TRACKER_HIDE):
				break
				
			case UInt32(RC_CLIENT_EVENT_LEADERBOARD_TRACKER_UPDATE):
				break
				
			case UInt32(RC_CLIENT_EVENT_RESET):
				aSelf.delegate?.restartEmulationRequested(client: aSelf)

			case UInt32(RC_CLIENT_EVENT_GAME_COMPLETED):
				aSelf.delegate?.gameCompleted?(client: aSelf)
				
			case UInt32(RC_CLIENT_EVENT_SERVER_ERROR):
				let message: String?
				let api: String?
				if let aMess = event.pointee.server_error.pointee.error_message {
					message = String(cString: aMess)
				} else {
					message = nil
				}
				if let aMess = event.pointee.server_error.pointee.api {
					api = String(cString: aMess)
				} else {
					api = nil
				}

				aSelf.delegate?.serverError?(client: aSelf, message: message, api: api)
				
			default:
				print("Unknown event type \(event.pointee.type)!")
			}
		}
		
		// Disable hardcore - if we goof something up in the implementation, we don't want our
		// account disabled for cheating.
		rc_client_set_hardcore_enabled(_client, 0)
	}
	
	public func stop() {
		if _client != nil {
			// Release resources associated to the client instance
			rc_client_destroy(_client)
			_client = nil
		}
	}
	
	public func reset() {
		rc_client_reset(_client)
	}
	
	private func achievementTriggered(_ achievement: UnsafePointer<rc_client_achievement_t>!) {
		var url = [CChar](repeating: 0, count: 1024)
		var actualURL: URL? = nil
		if (rc_client_achievement_get_image_url(achievement, Int32(RC_CLIENT_ACHIEVEMENT_STATE_UNLOCKED), &url, url.count) == RC_OK),
		   let urlStr = URL(string: String(cString: url)) {
			actualURL = urlStr
		}
		let ach = RCKClientAchievement(retroPointer: achievement!)
		delegate?.gotAchievement?(client: self, ach, urlForIcon: actualURL)
	}
	
	public func attach() {
		
	}
	
	/// Call every frame!
	public func doFrame() {
		rc_client_do_frame(_client)
	}
	
	/// Call when paused.
	public func idling() {
		rc_client_idle(_client)
	}
	
	// MARK: -
	
	private func loadGameCallback(result: CInt, errorMessage: UnsafePointer<CChar>?) {
		if result == RC_OK {
			delegate?.gameLoadedSuccessfully(client: self)
		} else {
			var dict = [String: Any]()
			if let errorMessage {
				dict[NSLocalizedDescriptionKey] = String(cString: errorMessage)
			}
			delegate?.gameFailedToLoad(client: self, error: NSError(domain: RCKErrorDomain, code: Int(result), userInfo: dict))
		}
	}
		
	@objc(loadGameFromURL:console:)
	public func loadGame(from url: URL, console: RCKConsoleIdentifier = .unknown) {
		_ = url.withUnsafeFileSystemRepresentation { up in
			return rc_client_begin_identify_and_load_game(_client, UInt32(console.rawValue), up, nil, 0, { result, errorMessage, client, userData in
				guard let usrDat = rc_client_get_userdata(client) else {
					return
				}
				let aSelf: Client = Unmanaged.fromOpaque(usrDat).takeUnretainedValue()
				aSelf.loadGameCallback(result: result, errorMessage: errorMessage)
			}, nil)
		}
	}
	
	@objc(loadGameFromData:console:)
	public func loadGame(from: Data, console: RCKConsoleIdentifier = .unknown) {
		_ = from.withUnsafeBytes { urbp in
			return rc_client_begin_identify_and_load_game(_client, UInt32(console.rawValue), nil, urbp.baseAddress, urbp.count, { result, errorMessage, client, userdata in
				guard let usrDat = rc_client_get_userdata(client) else {
					return
				}
				let aSelf: Client = Unmanaged.fromOpaque(usrDat).takeUnretainedValue()
				aSelf.loadGameCallback(result: result, errorMessage: errorMessage)
			}, nil)
		}
	}
	
	private func mediaChangedCallback(result: CInt, errorMessage: UnsafePointer<CChar>?, client: OpaquePointer!) {
		// on success, do nothing
		if result == RC_OK {
			delegate?.gameChangedSuccessfully?(client: self)
			return
		}
		
		let err: Error
		
		if result == RC_HARDCORE_DISABLED {
			err = RCKError(.hardcoreDisabled, userInfo: [NSLocalizedDescriptionKey: "Hardcore disabled. Unrecognized media inserted."])
		} else {
			let errMsg = errorMessage ?? rc_error_str(result)!
			let errStr = String(cString: errMsg)
			err = RCKError(RCKError.Code(rawValue: result)!, userInfo: [NSLocalizedDescriptionKey: errStr])
		}
		delegate?.gameChangeFailed?(client: self, error: err)
	}
	
	@objc(changeMediaToURL:)
	public func changeMedia(to url: URL) {
		_ = url.withUnsafeFileSystemRepresentation { up in
			rc_client_begin_change_media(_client, up, nil, 0, { result, errorMessage, client, userData in
				guard let usrDat = rc_client_get_userdata(client) else {
					return
				}
				let aSelf: Client = Unmanaged.fromOpaque(usrDat).takeUnretainedValue()
				aSelf.mediaChangedCallback(result: result, errorMessage: errorMessage, client: client)
			}, nil)
		}
	}
	
	@objc(changeMediaToData:)
	public func changeMedia(to data: Data) {
		_ = data.withUnsafeBytes { urbp in
			rc_client_begin_change_media(_client, nil, urbp.baseAddress, urbp.count, { result, errorMessage, client, userData in
				guard let usrDat = rc_client_get_userdata(client) else {
					return
				}
				let aSelf: Client = Unmanaged.fromOpaque(usrDat).takeUnretainedValue()
				aSelf.mediaChangedCallback(result: result, errorMessage: errorMessage, client: client)
			}, nil)
		}
	}

	// MARK: -
	
	public func captureRetroAchievementsState() throws -> Data {
		guard let _client else {
			throw RCKError(.invalidState)
		}
		let bufferSize = rc_client_progress_size(_client)
		var buffer = Data(count: bufferSize)
		
		let success = buffer.withUnsafeMutableBytes { umrbp in
			return rc_client_serialize_progress(_client, umrbp.baseAddress)
		}
		if success == RC_OK {
			return buffer
		} else {
			throw RCKError(RCKError.Code(rawValue: success) ?? .invalidState)
		}
	}
	
	@objc(restoreRetroAchievementsStateFromData:error:)
	public func restoreRetroAchievementsState(from: Data) throws {
		guard let _client else {
			throw RCKError(.apiFailure)
		}
		
		let result = from.withUnsafeBytes { urbp in
			return rc_client_deserialize_progress(_client, urbp.baseAddress)
		}
		
		guard result == RC_OK else {
			throw RCKError(RCKError.Code(rawValue: result)!)
		}
	}
	
	// MARK: - User Account stuff
	
	private func loginCallback(result: Int32, errorMessage: UnsafePointer<CChar>?, client: OpaquePointer?) {
		if result == RC_OK {
			delegate?.loginSuccessful?(client: self)
		} else {
			var userInfo = [String: Any]()
			if let errorMessage {
				userInfo[NSLocalizedDescriptionKey] = String(cString: errorMessage)
			}
			
			delegate?.loginFailed?(client: self, with: RCKError(RCKError.Code(rawValue: result)!, userInfo: userInfo))
		}
	}
	
	public func loginWith(userName: String, password: String) {
		// This will generate an HTTP payload and call the server_call chain above.
		// Eventually, login_callback will be called to let us know if the login was successful.
		rc_client_begin_login_with_password(_client, userName, password, { result, errorMessage, client, userdata in
			guard let usrDat = rc_client_get_userdata(client) else {
				return
			}
			let aSelf: Client = Unmanaged.fromOpaque(usrDat).takeUnretainedValue()
			aSelf.loginCallback(result: result, errorMessage: errorMessage, client: client)
		}, nil)
	}
	
	public func loginWith(userName: String, token: String) {
		// This is exactly the same functionality as rc_client_begin_login_with_password, but
		// uses the token captured from the first login instead of a password.
		// Note that it uses the same callback.
		rc_client_begin_login_with_token(_client, userName, token, { result, errorMessage, client, userdata in
			guard let usrDat = rc_client_get_userdata(client) else {
				return
			}
			let aSelf: Client = Unmanaged.fromOpaque(usrDat).takeUnretainedValue()
			aSelf.loginCallback(result: result, errorMessage: errorMessage, client: client)
		}, nil)
	}
	
	public func logout() {
		rc_client_logout(_client)
	}
	
	public var isLoggedIn: Bool {
		return rc_client_get_user_info(_client) != nil
	}
	
	/// Will be `nil` if not logged in.
	public var loginToken: String? {
		guard let usrInfo = rc_client_get_user_info(_client),
			  let cToken = usrInfo.pointee.token else {
			return nil
		}
		return String(cString: cToken)
	}
	
	// MARK: -
	
	func userInfo() {
		guard let usrInf = rc_client_get_user_info(_client) else {
			return
		}
		
	}
	
	public func achievementsList() -> [ClientAchievementBucket]? {
		guard let list = rc_client_create_achievement_list(_client, Int32(RC_CLIENT_ACHIEVEMENT_CATEGORY_CORE_AND_UNOFFICIAL), Int32(RC_CLIENT_ACHIEVEMENT_LIST_GROUPING_PROGRESS)) else {
			return nil
		}
		defer {
			rc_client_destroy_achievement_list(list)
		}
		
		let buckets = UnsafeBufferPointer(start: list.pointee.buckets, count: Int(list.pointee.num_buckets))
		return buckets.map({ClientAchievementBucket(rcheevo: $0)})
	}
	
	public func gameInfo() -> GameInfo? {
		guard let gi = rc_client_get_game_info(_client) else {
			return nil
		}
		
		return GameInfo(gi: gi)
	}
}

extension RCKError.Code: CustomStringConvertible {
	public var description: String {
		let des = rc_error_str(self.rawValue)!
		return String(cString: des)
	}
}
