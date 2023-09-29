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
	/// RetroAchievements addresses start at `$00000000`, which normally represents the first physical byte
	/// of memory for the system.
	///
	/// Normally, an emulator stores it's RAM in a singular contiguous buffer,
	/// which makes reading from a RetroAchievements address simple:
	///
	/// ```
	/// if (address + num_bytes >= RAM_size)
	///   return 0;
	/// memcpy(buffer, &RAM[address], num_bytes);
	/// return num_bytes;
	/// ```
	///
	/// Sometimes an emulator only exposes a virtual BUS. In that case, it may be necessary to translate
	/// the RetroAchievements address to a real address.
	@objc(readMemoryForClient:atAddress:count:)
	func readMemory(client: Client, at address: UInt32, count num_bytes: UInt32) -> Data
	
	/// Log-in succeeded.
	@objc(loginSuccessfulForClient:)
	func loginSuccessful(client: Client)
	
	/// Log-in failed.
	@objc(loginFailedForClient:withError:)
	func loginFailed(client: Client, with: Error)
	
	/// Called when the runtime wants the emulator reset.
	///
	/// Usually called when the user wants to enable hardcore mode when a game is running.
	/// Make sure you call `Client.reset()` after the emulator has reset itself.
	@objc(restartEmulationRequestedByClient:)
	func restartEmulationRequested(client: Client)
	
	/// The user got an achievement!
	@objc(client:gotAchievement:)
	func client(_ client: Client, got achievement: RCKClientAchievement)
	
	@objc(leaderboardStartedForClient:leaderboard:)
	optional func leaderboardStarted(client: Client, _ leaderboard: Client.Leaderboard)
	
	@objc(leaderboardFailedForClient:leaderboard:)
	optional func leaderboardFailed(client: Client, _ leaderboard: Client.Leaderboard)
	
	@objc(leaderboardSubmittedForClient:leaderboard:)
	optional func leaderboardSubmitted(client: Client, _ leaderboard: Client.Leaderboard)
	
	/// Find the currently visible tracker by ID and update what's being displayed.
	/// The display text buffer is guaranteed to live for as long as the game is loaded,
	/// but it may be updated in a non-thread safe manner within `Client.doFrame()`, so
	/// we create a copy for the rendering code to read.
	@objc
	optional func updateLeaderboardTracker(client: Client, tracker: Client.LeaderboardTracker)
	
	/// The actual implementation of converting a `LeaderboardTracker` to
	/// an on-screen widget is going to be client-specific. The provided tracker object
	/// has a unique identifier for the tracker and a string to be displayed on-screen.
	/// The string should be displayed using a fixed-width font to eliminate jittering
	/// when timers are updated several times a second.
	@objc
	optional func showLeaderboardTracker(client: Client, tracker: Client.LeaderboardTracker)
	
	/// This tracker is no longer needed
	@objc
	optional func hideLeaderboardTracker(client: Client, tracker: Client.LeaderboardTracker)
	
	/// Multiple challenge indicators may be shown, but only one per achievement, so key the list on the achievement ID
	@objc
	optional func showChallengeIndicator(client: Client, identifier: UInt32, imageURL: URL?)
	
	/// The challenge indicator is no longer needed
	@objc
	optional func hideChallengeIndicator(client: Client, identifier: UInt32)

	/// The *UPDATE* event assumes the indicator is already visible, and just asks us to update the image/text.
	@objc
	optional func updateProgressIndicator(client: Client, achievement: RCKClientAchievement)
	
	/// The *SHOW* event tells us the indicator was not visible, but should be now.
	@objc
	optional func showProgressIndicator(client: Client, achievement: RCKClientAchievement)
	
	/// The hide event indicates the indicator should no longer be visible.
	@objc
	optional func hideProgressIndicator(client: Client)

	/// Game has finished loading.
	func gameLoadedSuccessfully(client: Client)
	
	/// Error loading the game.
	func gameFailedToLoad(client: Client, error: Error)
	
	/// Game was changed successfully.
	@objc optional func gameChangedSuccessfully(client: Client)

	/// There was an error changing the game.
	@objc optional func gameChangeFailed(client: Client, error: Error)

	/// User has completed all achievements!
	@objc func gameCompleted(client: Client)
	
	@objc func serverError(client: Client, message: String?, api: String?)
}

private var _initErrors: () = {
	NSError.setUserInfoValueProvider(forDomain: RCKError.errorDomain) { err1, userInfo in
		guard let err = err1 as? RCKError else {
			return nil
		}
		
		if userInfo == NSDebugDescriptionErrorKey {
			let des = rc_error_str(err.code.rawValue)!
			return String(cString: des)
		} else if userInfo == NSLocalizedDescriptionKey {
			//TODO: localize!
			let des = rc_error_str(err.code.rawValue)!
			return String(cString: des)
		}
		
		return nil
	}
}()

/// Provides a wrapper around `rc_client_t`.
@objc(RCKClient) @objcMembers
public class Client: NSObject {
	private var _client: OpaquePointer?
	private var session: URLSession!
	/// The delegate for the client to call.
	public weak var delegate: ClientDelegate?
	
	public override init() {
		_ = _initErrors
		rc_hash_init_default_cdreader()
		super.init()
		
		session = URLSession(configuration: .default)
	}
	
	deinit {
		stop()
	}
	
	private func serverCallback(request: UnsafePointer<rc_api_request_t>?,
								callback: rc_client_server_callback_t?,
								callback_data: UnsafeMutableRawPointer?) {
		guard let cURL = request?.pointee.url,
			  let theURL = URL(string: String(cString: cURL)) else {
			var server_response = rc_api_server_response_t()
			server_response.body = nil
			server_response.body_length = 0
			server_response.http_status_code = 400

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
			if let dat, !dat.isEmpty {
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
	private static func read_memory(_ address: UInt32, buffer: UnsafeMutablePointer<UInt8>?, num_bytes: UInt32, client: OpaquePointer?) -> UInt32 {
		guard let usrDat = rc_client_get_userdata(client) else {
			return 0
		}

		let theClass: Client = Unmanaged.fromOpaque(usrDat).takeUnretainedValue()
		if let classDel = theClass.delegate {
			let dat = classDel.readMemory(client: theClass, at: address, count: num_bytes)
			if dat.count > 0 {
				dat.withUnsafeBytes { urbp in
					_=memcpy(buffer, urbp.baseAddress, min(urbp.count, Int(num_bytes)))
				}
			}
			return min(UInt32(dat.count), num_bytes)
		}

		return 0
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
	
	private func leaderboard_tracker_show(tracker: UnsafePointer<rc_client_leaderboard_tracker_t>?) {
		delegate?.showLeaderboardTracker?(client: self, tracker: LeaderboardTracker(tracker: tracker!))
	}
	
	private func leaderboard_tracker_update(tracker: UnsafePointer<rc_client_leaderboard_tracker_t>?) {
		delegate?.updateLeaderboardTracker?(client: self, tracker: LeaderboardTracker(tracker: tracker!))
	}
	
	private func leaderboard_tracker_hide(tracker: UnsafePointer<rc_client_leaderboard_tracker_t>?) {
		delegate?.hideLeaderboardTracker?(client: self, tracker: LeaderboardTracker(tracker: tracker!))
	}
	
	public func start() {
		// Create the client instance
		// But only if it isn't created yet!
		guard _client == nil else {
			return
		}
		
		_client = rc_client_create({ address, buffer, num_bytes, client in
			return Client.read_memory(address, buffer: buffer, num_bytes: num_bytes, client: client)
		}, { request, callback, callbackData, client in
			guard let usrDat = rc_client_get_userdata(client) else {
				return
			}
			let theClass: Client = Unmanaged.fromOpaque(usrDat).takeUnretainedValue()
			theClass.serverCallback(request: request, callback: callback, callback_data: callbackData)
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
				aSelf.showChallengeIndicator(achievement: event.pointee.achievement)
				
			case UInt32(RC_CLIENT_EVENT_ACHIEVEMENT_CHALLENGE_INDICATOR_HIDE):
				aSelf.hideChallengeIndicator(achievement: event.pointee.achievement)
				
			case UInt32(RC_CLIENT_EVENT_ACHIEVEMENT_PROGRESS_INDICATOR_SHOW):
				aSelf.showProgressIndicator(achievement: event.pointee.achievement)
				
			case UInt32(RC_CLIENT_EVENT_ACHIEVEMENT_PROGRESS_INDICATOR_HIDE):
				aSelf.delegate?.hideProgressIndicator?(client: aSelf)
				
			case UInt32(RC_CLIENT_EVENT_ACHIEVEMENT_PROGRESS_INDICATOR_UPDATE):
				aSelf.updateProgressIndicator(achievement: event.pointee.achievement)
				
			case UInt32(RC_CLIENT_EVENT_LEADERBOARD_TRACKER_SHOW):
				aSelf.leaderboard_tracker_show(tracker: event.pointee.leaderboard_tracker)
				
			case UInt32(RC_CLIENT_EVENT_LEADERBOARD_TRACKER_HIDE):
				aSelf.leaderboard_tracker_hide(tracker: event.pointee.leaderboard_tracker)
				
			case UInt32(RC_CLIENT_EVENT_LEADERBOARD_TRACKER_UPDATE):
				aSelf.leaderboard_tracker_update(tracker: event.pointee.leaderboard_tracker)
				
			case UInt32(RC_CLIENT_EVENT_RESET):
				aSelf.delegate?.restartEmulationRequested(client: aSelf)

			case UInt32(RC_CLIENT_EVENT_GAME_COMPLETED):
				aSelf.delegate?.gameCompleted(client: aSelf)
				
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

				aSelf.delegate?.serverError(client: aSelf, message: message, api: api)
				
			default:
				print("Unknown event type \(event.pointee.type)!")
			}
		}
		
		// Disable hardcore for now - if we goof something up in the implementation, we don't want our
		// account disabled for cheating.
		rc_client_set_hardcore_enabled(_client, 0)
	}
	
	/// Stops the client.
	public func stop() {
		if _client != nil {
			// Release resources associated to the client instance
			rc_client_destroy(_client)
			_client = nil
		}
	}
	
	/// Informs the runtime that the emulator has been reset.
	///
	/// Will reset all achievements and leaderboards to their initial state (includes hiding indicators/trackers).
	public func reset() {
		rc_client_reset(_client)
	}
	
	private func achievementTriggered(_ achievement: UnsafePointer<rc_client_achievement_t>!) {
		let ach = RCKClientAchievement(retroPointer: achievement!, stateIcon: .unlocked)
		delegate?.client(self, got: ach)
	}
	
	/// Processes achievements for the current frame.
	///
	/// Call every frame!
	public func doFrame() {
		rc_client_do_frame(_client)
	}
	
	/// Processes the periodic queue.
	///
	/// Called internally by `rc_client_do_frame`. Should be explicitly called if `doFrame()`
	/// is not being called because emulation is paused.
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
				let tmpStr = String(cString: errorMessage)
				dict[NSLocalizedDescriptionKey] = tmpStr
				dict[NSDebugDescriptionErrorKey] = tmpStr
			}
			delegate?.gameFailedToLoad(client: self, error: NSError(domain: RCKErrorDomain, code: Int(result), userInfo: dict))
		}
	}
	
	/// Begin loading a game from the selected URL.
	@objc(loadGameFromURL:console:)
	public func loadGame(from url: URL, console: RCKConsoleIdentifier = .unknown) {
		_ = url.withUnsafeFileSystemRepresentation { up in
			return rc_client_begin_identify_and_load_game(_client, UInt32(console.rawValue), up, nil, 0, { result, errorMessage, client, _ in
				guard let usrDat = rc_client_get_userdata(client) else {
					return
				}
				let aSelf: Client = Unmanaged.fromOpaque(usrDat).takeUnretainedValue()
				aSelf.loadGameCallback(result: result, errorMessage: errorMessage)
			}, nil)
		}
	}
	
	/// Begin loading a game from the passed-in data.
	@objc(loadGameFromData:console:)
	public func loadGame(from: Data, console: RCKConsoleIdentifier = .unknown) {
		_ = from.withUnsafeBytes { urbp in
			return rc_client_begin_identify_and_load_game(_client, UInt32(console.rawValue), nil, urbp.baseAddress, urbp.count, { result, errorMessage, client, _ in
				guard let usrDat = rc_client_get_userdata(client) else {
					return
				}
				let aSelf: Client = Unmanaged.fromOpaque(usrDat).takeUnretainedValue()
				aSelf.loadGameCallback(result: result, errorMessage: errorMessage)
			}, nil)
		}
	}
	
	private func mediaChangedCallback(result: CInt, errorMessage: UnsafePointer<CChar>?) {
		if result == RC_OK {
			delegate?.gameChangedSuccessfully?(client: self)
			return
		}
		
		let err: Error
		
		if result == RC_HARDCORE_DISABLED {
			err = RCKError(.hardcoreDisabled, userInfo: [NSLocalizedDescriptionKey: "Hardcore disabled. Unrecognized media inserted.",
														NSDebugDescriptionErrorKey: "Hardcore disabled. Unrecognized media inserted."])
		} else {
			let errMsg = errorMessage ?? rc_error_str(result)!
			let errStr = String(cString: errMsg)
			err = RCKError(RCKError.Code(rawValue: result)!, userInfo: [NSLocalizedDescriptionKey: errStr,
																	   NSDebugDescriptionErrorKey: errStr])
		}
		delegate?.gameChangeFailed?(client: self, error: err)
	}
	
	@objc(changeMediaToURL:)
	public func changeMedia(to url: URL) {
		_ = url.withUnsafeFileSystemRepresentation { up in
			return rc_client_begin_change_media(_client, up, nil, 0, { result, errorMessage, client, _ in
				guard let usrDat = rc_client_get_userdata(client) else {
					return
				}
				let aSelf: Client = Unmanaged.fromOpaque(usrDat).takeUnretainedValue()
				aSelf.mediaChangedCallback(result: result, errorMessage: errorMessage)
			}, nil)
		}
	}
	
	@objc(changeMediaToData:)
	public func changeMedia(to data: Data) {
		_ = data.withUnsafeBytes { urbp in
			return rc_client_begin_change_media(_client, nil, urbp.baseAddress, urbp.count, { result, errorMessage, client, _ in
				guard let usrDat = rc_client_get_userdata(client) else {
					return
				}
				let aSelf: Client = Unmanaged.fromOpaque(usrDat).takeUnretainedValue()
				aSelf.mediaChangedCallback(result: result, errorMessage: errorMessage)
			}, nil)
		}
	}

	// MARK: -
	
	/// Serializes the runtime state into a `Data` object.
	///
	/// Throws on error.
	public func captureRetroAchievementsState() throws -> Data {
		guard let _client else {
			throw RCKError(.apiFailure)
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
	
	/// Deserializes the runtime state from a `Data` object.
	///
	/// Throws on error.
	@objc(restoreRetroAchievementsStateFromData:error:)
	public func restoreRetroAchievementsState(from: Data) throws {
		guard let _client else {
			throw RCKError(.apiFailure)
		}
		
		let result = from.withUnsafeBytes { urbp in
			return rc_client_deserialize_progress(_client, urbp.baseAddress)
		}
		
		guard result == RC_OK else {
			throw RCKError(RCKError.Code(rawValue: result) ?? .invalidState)
		}
	}
	
	private func showChallengeIndicator(achievement: UnsafePointer<rc_client_achievement_t>!) {
		var imageURL: URL? = nil
		var cUrl = [CChar](repeating: 0, count: 512)
		if (rc_client_achievement_get_image_url(achievement, Int32(RC_CLIENT_ACHIEVEMENT_STATE_UNLOCKED), &cUrl, cUrl.count) == RC_OK) {
			let urlString = String(cString: cUrl)
			imageURL = URL(string: urlString)
		}
		delegate?.showChallengeIndicator?(client: self, identifier: achievement.pointee.id, imageURL: imageURL)
	}
	
	private func hideChallengeIndicator(achievement: UnsafePointer<rc_client_achievement_t>!) {
		delegate?.hideChallengeIndicator?(client: self, identifier: achievement.pointee.id)
	}
	
	// The UPDATE event assumes the indicator is already visible, and just asks us to update the image/text.
	private func updateProgressIndicator(achievement: UnsafePointer<rc_client_achievement_t>!) {
		let achieve = RCKClientAchievement(retroPointer: achievement, stateIcon: .active)
		delegate?.updateProgressIndicator?(client: self, achievement: achieve)
	}
	
	// The SHOW event tells us the indicator was not visible, but should be now.
	private func showProgressIndicator(achievement: UnsafePointer<rc_client_achievement_t>!) {
		let achieve = RCKClientAchievement(retroPointer: achievement, stateIcon: .active)
		delegate?.showProgressIndicator?(client: self, achievement: achieve)
	}
	
	// MARK: - User Account stuff
	
	private func loginCallback(result: Int32, errorMessage: UnsafePointer<CChar>?) {
		if result == RC_OK {
			delegate?.loginSuccessful(client: self)
		} else {
			var userInfo = [String: Any]()
			if let errorMessage {
				let tmpStr = String(cString: errorMessage)
				userInfo[NSLocalizedDescriptionKey] = tmpStr
				userInfo[NSDebugDescriptionErrorKey] = tmpStr
			}
			
			delegate?.loginFailed(client: self, with: RCKError(RCKError.Code(rawValue: result)!, userInfo: userInfo))
		}
	}
	
	/// Login with a user name and a password.
	public func loginWith(userName: String, password: String) {
		// This will generate an HTTP payload and call the server_call chain above.
		// Eventually, login_callback will be called to let us know if the login was successful.
		rc_client_begin_login_with_password(_client, userName, password, { result, errorMessage, client, _ in
			guard let usrDat = rc_client_get_userdata(client) else {
				return
			}
			let aSelf: Client = Unmanaged.fromOpaque(usrDat).takeUnretainedValue()
			aSelf.loginCallback(result: result, errorMessage: errorMessage)
		}, nil)
	}
	
	/// Login with a user name and a previously-generated token.
	public func loginWith(userName: String, token: String) {
		// This is exactly the same functionality as rc_client_begin_login_with_password, but
		// uses the token captured from the first login instead of a password.
		// Note that it uses the same callback.
		rc_client_begin_login_with_token(_client, userName, token, { result, errorMessage, client, _ in
			guard let usrDat = rc_client_get_userdata(client) else {
				return
			}
			let aSelf: Client = Unmanaged.fromOpaque(usrDat).takeUnretainedValue()
			aSelf.loginCallback(result: result, errorMessage: errorMessage)
		}, nil)
	}
	
	/// Logout of the current user account.
	public func logout() {
		rc_client_logout(_client)
	}
	
	/// Is the user logged in?
	public var isLoggedIn: Bool {
		return rc_client_get_user_info(_client) != nil
	}
	
	/// The log-in token needed to conveniently log into Rcheevos.
	///
	/// Will be `nil` if not logged in.
	public var loginToken: String? {
		guard let usrInfo = rc_client_get_user_info(_client),
			  let cToken = usrInfo.pointee.token else {
			return nil
		}
		return String(cString: cToken)
	}
	
	/// Returns the current user information.
	///
	/// Will be `nil` if not logged in.
	func userInfo() -> UserInfo? {
		guard let usrInf = rc_client_get_user_info(_client) else {
			return nil
		}
		
		return UserInfo(user: usrInf)
	}
	
	// MARK: - getters/setters

	/// Gets/sets whether hardcore is enabled (off by default).
	///
	/// Can be called with a game loaded.
	/// Enabling hardcore with a game loaded will call `Delegate.restartEmulationRequested(client: Client)`
	/// event. Processing will be disabled until `Client.reset()` is called.
	public var hardcoreMode: Bool {
		get {
			return (rc_client_get_hardcore_enabled(_client) != 0)
		}
		set {
			rc_client_set_hardcore_enabled(_client, newValue ? 1 : 0)
		}
	}
	
	/// Gets/sets whether encore mode is enabled (off by default).
	///
	/// Evaluated when loading a game. Has no effect while a game is loaded.
	public var encoreMode: Bool {
		get {
			return (rc_client_get_encore_mode_enabled(_client) != 0)
		}
		set {
			rc_client_set_encore_mode_enabled(_client, newValue ? 1 : 0)
		}
	}
	
	/// Gets/sets whether unofficial achievements should be loaded.
	///
	/// Evaluated when loading a game. Has no effect while a game is loaded.
	public var useUnofficialAchievements: Bool {
		get {
			return (rc_client_get_unofficial_enabled(_client) != 0)
		}
		set {
			rc_client_set_unofficial_enabled(_client, newValue ? 1 : 0)
		}
	}
	
	/// Sets whether spectator mode is enabled (off by default).
	///
	/// If enabled, events for achievement unlocks and leaderboard submissions will be
	/// raised, but server calls to actually perform the unlock/submit will not occur.
	/// Can be modified while a game is loaded. Evaluated at unlock/submit time.
	/// Cannot be modified if disabled before a game is loaded.
	public var spectatorMode: Bool {
		get {
			return (rc_client_get_spectator_mode_enabled(_client) != 0)
		}
		set {
			rc_client_set_spectator_mode_enabled(_client, newValue ? 1 : 0)
		}
	}
	
	// MARK: -
	
	/// Returns the achievement list of the current game.
	public func achievementsList(category: RCKClientAchievement.Category = .coreAndUnofficial, grouping: RCKClientAchievement.ListGrouping = .progress) -> [ClientAchievementBucket]? {
		guard let list = rc_client_create_achievement_list(_client, Int32(category.rawValue), grouping.rawValue) else {
			return nil
		}
		defer {
			rc_client_destroy_achievement_list(list)
		}
		
		let buckets = UnsafeBufferPointer(start: list.pointee.buckets, count: Int(list.pointee.num_buckets))
		return buckets.map({ClientAchievementBucket(rcheevo: $0)})
	}
	
	/// Get information about the current game.
	///
	/// Returns `nil` if no game is loaded.
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

extension RCKConsoleIdentifier: CustomStringConvertible, Codable {
	@inlinable public var description: String {
		return self.name
	}
}


//Additional classes
public extension Client {
	/// The user info.
	@objc(RCKClientUserInfo) @objcMembers
	class UserInfo: NSObject, Codable {
		/// The display name of the user.
		public let displayName: String
		/// The user name.
		public let userName: String
		/// Log-in token for quick log-in instead of using a password.
		public let token: String
		/// Hardcore score.
		public let score: UInt32
		/// Softcore score.
		public let softcoreScore: UInt32
		/// The number of unread messages.
		public let countOfUnreadMessages: UInt32
		/// The current icon URL of the user. May be `nil` if there was a problem parsing the URL.
		public let iconURL: URL?

		fileprivate init(user hi: UnsafePointer<rc_client_user_t>) {
			displayName = String(cString: hi.pointee.display_name)
			userName = String(cString: hi.pointee.username)
			token = String(cString: hi.pointee.token)
			score = hi.pointee.score
			softcoreScore = hi.pointee.score_softcore
			countOfUnreadMessages = hi.pointee.num_unread_messages
			
			do {
				var trueURL: URL? = nil
				var cUrl = [CChar](repeating: 0, count: 512)
				if rc_client_user_get_image_url(hi, &cUrl, cUrl.count) == RC_OK {
					let str = String(cString: cUrl)
					trueURL = URL(string: str)
				}
				iconURL = trueURL
			}
		}
		
		public override var description: String {
			return "\(displayName) (\(userName)), score: \(score) (softcore: \(softcoreScore))"
		}
	}

	@objc(RCKLeaderboardTracker) @objcMembers
	class LeaderboardTracker: NSObject {
		public let display: String
		public let identifier: UInt32
		
		fileprivate init(tracker: UnsafePointer<rc_client_leaderboard_tracker_t>) {
			//TODO: would memcpy be faster?
			let dis = tracker.pointee.display
			let preDisplay: [CChar] = [dis.0, dis.1, dis.2, dis.3, dis.4, dis.5, dis.6, dis.7, dis.8, dis.9, dis.10, dis.11, dis.12, dis.13, dis.14, dis.15, dis.16, dis.17, dis.18, dis.19, dis.20, dis.21, dis.22, dis.23, 0]
			display = String(cString: preDisplay)
			identifier = tracker.pointee.id
		}
		
		public override var hash: Int {
			var aHash = Hasher()
			identifier.hash(into: &aHash)
			return aHash.finalize()
		}
		
		public override var description: String {
			return "ID ‘\(identifier)’, \(display)"
		}
	}
}
