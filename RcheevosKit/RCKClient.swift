//
//  RCKClient.swift
//  RcheevosKit
//
//  Created by C.W. Betts on 8/31/23.
//

import Foundation
@_implementationOnly import rcheevos
@_implementationOnly import rcheevos.rc_client

/// Delegate for ``Client``
@objc(RCKClientDelegate)
public protocol ClientDelegate: NSObjectProtocol {
	/// RetroAchievements addresses start at `$00000000`, which normally represents the first physical byte
	/// of memory for the system.
	///
	/// Normally, an emulator stores its RAM in a singular contiguous buffer,
	/// which makes reading from a RetroAchievements address simple:
	///
	/// ```objc
	/// if (address + num_bytes >= RAM_size)
	///   return [NSData data];
	/// return [NSData dataWithBytes:&RAM[address] length:num_bytes]
	/// ```
	///
	/// Sometimes an emulator only exposes a virtual BUS. In that case, it may be necessary to translate
	/// the RetroAchievements address to a real address.
	@objc(readMemoryForClient:atAddress:count:)
	func readMemory(client: Client, at address: UInt32, count num_bytes: UInt32) -> Data
	
	/// Called when the runtime wants the emulator reset.
	///
	/// Usually called when the user wants to enable hardcore mode when a game is running.
	/// Make sure you call ``Client/reset()`` after the emulator has reset itself.
	@objc(restartEmulationRequestedByClient:)
	func restartEmulationRequested(client: Client)
	
	/// The user got an achievement!
	@objc(client:gotAchievement:)
	func client(_ client: Client, got achievement: Client.Achievement)
	
	@objc(leaderboardStartedForClient:leaderboard:)
	optional func leaderboardStarted(client: Client, _ leaderboard: Client.Leaderboard)
	
	@objc(leaderboardFailedForClient:leaderboard:)
	optional func leaderboardFailed(client: Client, _ leaderboard: Client.Leaderboard)
	
	@objc(leaderboardSubmittedForClient:leaderboard:)
	optional func leaderboardSubmitted(client: Client, _ leaderboard: Client.Leaderboard)
	
	/// Find the currently visible tracker by ID and update what's being displayed.
	///
	/// The display text buffer is guaranteed to live for as long as the game is loaded,
	/// but it may be updated in a non-thread safe manner within ``Client/doFrame()``, so
	/// we create a copy for the rendering code to read.
	@objc(updateLeaderboardTrackerForClient:usingTracker:)
	optional func updateLeaderboardTracker(client: Client, tracker: Client.LeaderboardTracker)
	
	/// The actual implementation of converting a ``Client/LeaderboardTracker`` to
	/// an on-screen widget is going to be client-specific.
	///
	/// The provided tracker object
	/// has a unique identifier for the tracker and a string to be displayed on-screen.
	/// The string should be displayed using a fixed-width font to eliminate jittering
	/// when timers are updated several times a second.
	@objc(showLeaderboardTrackerForClient:tracker:)
	optional func showLeaderboardTracker(client: Client, tracker: Client.LeaderboardTracker)
	
	/// This tracker is no longer needed
	@objc(hideLeaderboardTrackerForClient:tracker:)
	optional func hideLeaderboardTracker(client: Client, tracker: Client.LeaderboardTracker)
	
	/// Multiple challenge indicators may be shown, but only one per achievement, so key the list on the achievement ID
	@objc(showChallengeIndicatorForClient:referencingAchievement:imageURL:)
	optional func showChallengeIndicator(client: Client, referencing achievement: Client.Achievement, imageURL: URL?)
	
	/// The challenge indicator is no longer needed
	@objc(hideChallengeIndicatorForClient:referencingAchievement:)
	optional func hideChallengeIndicator(client: Client, referencing achievement: Client.Achievement)

	/// The *UPDATE* event assumes the indicator is already visible, and just asks us to update the image/text.
	@objc(updateProgressIndicatorForClient:referencingAchievement:)
	optional func updateProgressIndicator(client: Client, referencing achievement: Client.Achievement)
	
	/// The *SHOW* event tells us the indicator was not visible, but should be now.
	@objc(showProgressIndicatorForClient:referencingAchievement:)
	optional func showProgressIndicator(client: Client, referencing achievement: Client.Achievement)
	
	/// The hide event indicates the indicator should no longer be visible.
	@objc(hideProgressIndicatorForClient:)
	optional func hideProgressIndicator(client: Client)

	/// User has completed all achievements!
	@objc(gameCompletedWithClient:)
	func gameCompleted(with: Client)
	
	@objc(serverErrorFromClient:message:api:)
	func serverError(from: Client, message: String?, api: String?)
	
	/// Possibly-new ranking received for leaderboard.
	@objc(scoreBoardForClient:updated:)
	optional func scoreBoard(for: Client, updated: Client.Leaderboard.Scoreboard)
	
	/// An unlock request could not be completed and is pending.
	@objc optional func clientDisconnected(_ client: Client)
	
	/// All pending unlocks have been completed.
	@objc optional func clientReconnected(_ client: Client)
	
	/// All achievements for the subset have been earned.
	@objc(clientCleared:eventSubset:)
	optional func clientCleared(_ client: Client, event subset: Client.Subset)

	/// Callback for logging or displaying a message.
	@objc(client:receivedMessage:)
	optional func client(_ client: Client, receivedMessage: String)
}

private let _initErrors: () = {
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
final public class Client: NSObject {
	private var _client: OpaquePointer?
	private var session: URLSession!
	/// The delegate for the client to call.
	///
	/// This should be set before ``Client/loadGame(from:console:)-6fzag`` or
	/// ``Client/loadGame(from:console:)-6gm0s`` is called.
	public weak var delegate: ClientDelegate?
	
	public override init() {
		_ = _initErrors
		rc_hash_init_default_cdreader()
		super.init()
		
		session = URLSession(configuration: .default)
		start()
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
			return
		}
		var cocoaRequest = URLRequest(url: theURL)
		if let postCStr = request!.pointee.post_data {
			let dat1 = UnsafeBufferPointer(start: postCStr, sentinel: {0 == $0})
			cocoaRequest.httpBody = Data(buffer: dat1)
			cocoaRequest.httpMethod = "POST"
			if let aCStr = request!.pointee.content_type {
				cocoaRequest.setValue(String(cString: aCStr), forHTTPHeaderField: "Content-Type")
			}
		}
		var userAgentClause: [Int8] = [Int8](repeating: 0, count: 52)
		//TODO: store this? Is the overhead of having it constantly created worth storing it?
		rc_client_get_user_agent_clause(_client, &userAgentClause, userAgentClause.count)
		cocoaRequest.setValue(String(cString: userAgentClause), forHTTPHeaderField: "User-Agent")
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
	
	private func start() {
		// Create the client instance
		// But only if it isn't created yet!
		guard _client == nil else {
			return
		}
		
		_client = rc_client_create({ address, buffer, num_bytes, client in
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
				return UInt32(min(dat.count, Int(num_bytes)))
			}

			return 0
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
				aSelf.delegate?.gameCompleted(with: aSelf)
				
			case UInt32(RC_CLIENT_EVENT_LEADERBOARD_SCOREBOARD):
				aSelf.delegate?.scoreBoard?(for: aSelf, updated: Leaderboard.Scoreboard(scoreboard: event.pointee.leaderboard_scoreboard))
				
			case UInt32(RC_CLIENT_EVENT_SERVER_ERROR):
				let message: String?
				let api: String?
				if let aMess = event.pointee.server_error?.pointee.error_message {
					message = String(cString: aMess)
				} else {
					message = nil
				}
				if let aMess = event.pointee.server_error?.pointee.api {
					api = String(cString: aMess)
				} else {
					api = nil
				}

				aSelf.delegate?.serverError(from: aSelf, message: message, api: api)
				
			case UInt32(RC_CLIENT_EVENT_DISCONNECTED):
				aSelf.delegate?.clientDisconnected?(aSelf)
				
			case UInt32(RC_CLIENT_EVENT_RECONNECTED):
				aSelf.delegate?.clientReconnected?(aSelf)
				
			case UInt32(RC_CLIENT_EVENT_SUBSET_COMPLETED):
				aSelf.delegate?.clientCleared?(aSelf, event: Subset(subset: event.pointee.subset))

			default:
				print("RcheevosKit: Unknown event type \(event.pointee.type)!")
			}
		}
		
		// Disable hardcore for now - if we goof something up in the implementation, we don't want our
		// account disabled for cheating.
		rc_client_set_hardcore_enabled(_client, 0)
	}
	
	/// Stops the client.
	private func stop() {
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
	
	/// Determines if a sufficient amount of frames have been processed since the last call to ``clientCanPause(remainingFrames:)``.
	/// Should not be called unless the client is trying to pause.
	///
	/// If `false` is returned, and `remainingFrames` is not `nil`, `remainingFrames` will be set to the number of frames
	/// still required before pause is allowed, which can be converted to a time in seconds for displaying to the user.
	public func clientCanPause(remainingFrames: UnsafeMutablePointer<UInt32>? = nil) -> Bool {
		return rc_client_can_pause(_client, remainingFrames) != 0
	}
	
	@objc(subsetInfoForID:)
	public func subsetInfo(_ id: UInt32) -> Subset? {
		guard let aSub = rc_client_get_subset_info(_client, id) else {
			return nil
		}
		return Subset(subset: aSub)
	}
	
	private func achievementTriggered(_ achievement: UnsafePointer<rc_client_achievement_t>!) {
		let ach = Client.Achievement(retroPointer: achievement!, stateIcon: .unlocked)
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
	/// Should be explicitly called if ``doFrame()``
	/// is not being called because emulation is paused.
	public func idling() {
		rc_client_idle(_client)
	}
	
	// MARK: - Rich Presence
	
	/// Returns `true` if the current game supports rich presence.
	public var hasRichPresence: Bool {
		return rc_client_has_rich_presence(_client) != 0
	}
	
	/// Returns the current rich presence message.
	public var richPresenceMessage: String? {
		var buffer: [CChar] = Array(repeating: 0, count: 1024)
		let written = rc_client_get_rich_presence_message(_client, &buffer, buffer.count)
		guard written > 0 else {
			return nil
		}
		return String(cString: buffer)
	}
	
	// MARK: -
	
	/// Begin loading a game from the selected file URL.
	///
	/// - parameter url: The file URL to load from to load into RetroAchievements.
	/// - parameter console: The console to load the file from. Use ``RCKConsoleIdentifier/unknown`` if the console is unknown.
	/// - Parameter completionHandler: The completion handler.
	/// - note: The URL must be a file URL. if it is not, this function throws ``RCKError-enum/RCKErrorAPIFailure``.
	@objc(loadGameFromURL:console:completionHandler:)
	public func loadGame(from url: URL, console: RCKConsoleIdentifier = .unknown) async throws {
		guard url.isFileURL else {
			throw RCKError(.apiFailure, userInfo:
							[NSLocalizedDescriptionKey: "Invalid URL scheme: RcheevosKit cannot load games directly from the internet.",
							NSDebugDescriptionErrorKey: "RcheevosKit cannot load games directly from the internet.",
				 NSLocalizedRecoverySuggestionErrorKey: "Either connect to the server using Finder or Files, or download the file to your device.",
										 NSURLErrorKey: url])
		}
		
		try await withCheckedThrowingContinuation { cont in
			let cb = RCKProgressCallback<Void>(callback: cont)
			let aCall = Unmanaged.passRetained(cb).toOpaque()
			
			_ = url.withUnsafeFileSystemRepresentation { up in
				rc_client_begin_identify_and_load_game(_client, console.rawValue, up, nil, 0, { result, errorMessage, _, bCall in
					let cCall: RCKProgressCallback<Void> = Unmanaged.fromOpaque(bCall!).takeRetainedValue()
					guard result == RC_OK else {
						var dict = [String: Any]()
						if let errorMessage {
							let tmpStr = String(cString: errorMessage)
							dict[NSLocalizedFailureReasonErrorKey] = tmpStr
							dict[NSLocalizedDescriptionKey] = tmpStr
						}
						cCall.callback.resume(throwing: RCKError(RCKError.Code(rawValue: result) ?? .apiFailure, userInfo: dict))
						return
					}
					
					cCall.callback.resume()
				}, aCall)
			}
		}
	}
	
	/// Begin loading a game from the passed-in data.
	///
	/// - Parameter from: The data contents to load into RetroAchievements.
	/// - Parameter console: The console to load the data from. Use ``RCKConsoleIdentifier/unknown`` if the console is unknown.
	/// - Parameter completionHandler: The completion handler.
	@objc(loadGameFromData:console:completionHandler:)
	public func loadGame(from: Data, console: RCKConsoleIdentifier = .unknown) async throws {
		try await withCheckedThrowingContinuation { cont in
			let cb = RCKProgressCallback<Void>(callback: cont)
			let aCall = Unmanaged.passRetained(cb).toOpaque()
			
			_ = from.withUnsafeBytes { urbp in
				return rc_client_begin_identify_and_load_game(_client, console.rawValue, nil, urbp.baseAddress, urbp.count, { result, errorMessage, _, bCall in
					let cCall: RCKProgressCallback<Void> = Unmanaged.fromOpaque(bCall!).takeRetainedValue()
					guard result == RC_OK else {
						var dict = [String: Any]()
						if let errorMessage {
							let tmpStr = String(cString: errorMessage)
							dict[NSLocalizedFailureReasonErrorKey] = tmpStr
						}
						cCall.callback.resume(throwing: RCKError(RCKError.Code(rawValue: result) ?? .apiFailure, userInfo: dict))
						return
					}
					
					cCall.callback.resume()
				}, aCall)
			}
		}
	}
	
	/// Determines if a game was successfully identified and loaded.
	@objc(gameLoaded)
	public var isGameLoaded: Bool {
		@objc(isGameLoaded) get {
			return rc_client_is_game_loaded(_client) != 0
		}
	}
	
	/// Unloads the current game.
	public func unloadGame() {
		rc_client_unload_game(_client)
	}
	
	@objc(RCKLoadingGameState)
	public enum LoadingGameState: CInt, Sendable, Encodable {
		case none = 0
		case awaitingLogin
		case identifyingGame
		/// Deprecated, game data is now returned by identify call
		case fetchingGameData
		case startingSession
		case done
		/// There is currently no method to cancel/abort any process in this wrapper.
		case aborted
	}
	
	/// Gets the current progress of the asynchronous load game process.
	public func getLoadingGameState() -> LoadingGameState {
		return LoadingGameState(rawValue: rc_client_get_load_game_state(_client)) ?? .none
	}
	
	@objc(RCKUserGameSummary)
	final public class UserGameSummary: NSObject, Sendable, Encodable {
		public let countOfCoreAchievements: UInt32
		public let countOfUnofficialAchievements: UInt32
		public let countOfUnlockedAchievements: UInt32
		public let countOfUnsupportedAchievements: UInt32
		
		public let corePoints: UInt32
		public let unlockedPoints: UInt32
		
		@nonobjc
		internal init(gameSummary: rc_client_user_game_summary_t) {
			countOfCoreAchievements = gameSummary.num_core_achievements
			countOfUnofficialAchievements = gameSummary.num_unofficial_achievements
			countOfUnlockedAchievements = gameSummary.num_unlocked_achievements
			countOfUnsupportedAchievements = gameSummary.num_unsupported_achievements
			
			corePoints = gameSummary.points_core
			unlockedPoints = gameSummary.points_unlocked
			super.init()
		}
	}
	
	/// Returns a breakdown of the number of achievements in the game, and how many the user has unlocked.
	///
	/// Used for the "You have unlocked X of Y achievements" message shown when the game starts.
	public func userGameSummary() -> UserGameSummary {
		var hi = rc_client_user_game_summary_t()
		rc_client_get_user_game_summary(_client, &hi)
		return UserGameSummary(gameSummary: hi)
	}
	
	private func mediaChangedCallback(result: CInt, errorMessage: UnsafePointer<CChar>?) throws {
		if result == RC_OK {
			return
		}
		
		let err: Error
		
		if result == RC_HARDCORE_DISABLED {
			err = RCKError(.hardcoreDisabled, userInfo: [NSLocalizedDescriptionKey: "Hardcore disabled. Unrecognized media inserted.",
														NSDebugDescriptionErrorKey: "Hardcore disabled. Unrecognized media inserted.",
														NSLocalizedFailureErrorKey: "Unrecognized media inserted."])
		} else {
			let errMsg = errorMessage ?? rc_error_str(result)!
			let errStr = String(cString: errMsg)
			err = RCKError(RCKError.Code(rawValue: result)!,
						   userInfo: [NSLocalizedDescriptionKey: errStr,
									 NSDebugDescriptionErrorKey: errStr])
		}
		throw err
	}
	
	/// Changes the active disc in a multi-disc game.
	@objc(changeMediaToURL:completionHandler:)
	public func changeMedia(to url: URL) async throws {
		guard url.isFileURL else {
			throw RCKError(.apiFailure, userInfo:
							[NSLocalizedDescriptionKey: "Invalid URL scheme: RcheevosKit cannot load games directly from the internet.",
							NSDebugDescriptionErrorKey: "RcheevosKit cannot load games directly from the internet.",
				 NSLocalizedRecoverySuggestionErrorKey: "Either connect to the server using Finder or Files, or download the file to your device.",
										 NSURLErrorKey: url])
		}
		try await withCheckedThrowingContinuation { cont in
			let cb = RCKProgressCallback<Void>(callback: cont)
			let aCall = Unmanaged.passRetained(cb).toOpaque()
			
			_ = url.withUnsafeFileSystemRepresentation { up in
				return rc_client_begin_identify_and_change_media(_client, up, nil, 0, { result, errorMessage, client, bCall in
					let cCall: RCKProgressCallback<Void> = Unmanaged.fromOpaque(bCall!).takeRetainedValue()
					guard let usrDat = rc_client_get_userdata(client) else {
						cCall.callback.resume(throwing: RCKError(.apiFailure, userInfo: [NSLocalizedDescriptionKey: "Unable to retrieve client data."]))
						return
					}
					let aSelf: Client = Unmanaged.fromOpaque(usrDat).takeUnretainedValue()
					do {
						try aSelf.mediaChangedCallback(result: result, errorMessage: errorMessage)
						cCall.callback.resume()
					} catch {
						cCall.callback.resume(throwing: error)
					}
				}, aCall)
			}
		}
	}
	
	/// Changes the active disc in a multi-disc game.
	@objc(changeMediaToData:completionHandler:)
	public func changeMedia(to data: Data) async throws {
		try await withCheckedThrowingContinuation { cont in
			let cb = RCKProgressCallback<Void>(callback: cont)
			let aCall = Unmanaged.passRetained(cb).toOpaque()
			_ = data.withUnsafeBytes { urbp in
				return rc_client_begin_identify_and_change_media(_client, nil, urbp.baseAddress, urbp.count, { result, errorMessage, client, bCall in
					let cCall: RCKProgressCallback<Void> = Unmanaged.fromOpaque(bCall!).takeRetainedValue()
					guard let usrDat = rc_client_get_userdata(client) else {
						cCall.callback.resume(throwing: RCKError(.apiFailure, userInfo: [NSLocalizedDescriptionKey: "Unable to retrieve client data."]))
						return
					}
					let aSelf: Client = Unmanaged.fromOpaque(usrDat).takeUnretainedValue()
					do {
						try aSelf.mediaChangedCallback(result: result, errorMessage: errorMessage)
						cCall.callback.resume()
					} catch {
						cCall.callback.resume(throwing: error)
					}
				}, aCall)
			}
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
			return rc_client_serialize_progress_sized(_client, umrbp.baseAddress, umrbp.count)
		}
		guard success == RC_OK else {
			throw RCKError(RCKError.Code(rawValue: success) ?? .invalidState)
		}
		
		return buffer
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
			return rc_client_deserialize_progress_sized(_client, urbp.baseAddress, urbp.count)
		}
		
		guard result == RC_OK else {
			throw RCKError(RCKError.Code(rawValue: result) ?? .invalidState)
		}
	}
	
	// MARK: -
	
	private func showChallengeIndicator(achievement: UnsafePointer<rc_client_achievement_t>!) {
		var imageURL: URL? = nil
		var cUrl = [CChar](repeating: 0, count: 512)
		if rc_client_achievement_get_image_url(achievement, Int32(RC_CLIENT_ACHIEVEMENT_STATE_UNLOCKED), &cUrl, cUrl.count) == RC_OK {
			let urlString = String(cString: cUrl)
			imageURL = URL(string: urlString)
		}
		let achieve = Client.Achievement(retroPointer: achievement, stateIcon: .unlocked)
		delegate?.showChallengeIndicator?(client: self, referencing: achieve, imageURL: imageURL)
	}
	
	private func hideChallengeIndicator(achievement: UnsafePointer<rc_client_achievement_t>!) {
		let achieve = Client.Achievement(retroPointer: achievement, stateIcon: .active)
		delegate?.hideChallengeIndicator?(client: self, referencing: achieve)
	}
	
	// The UPDATE event assumes the indicator is already visible, and just asks us to update the image/text.
	private func updateProgressIndicator(achievement: UnsafePointer<rc_client_achievement_t>!) {
		let achieve = Client.Achievement(retroPointer: achievement, stateIcon: .active)
		delegate?.updateProgressIndicator?(client: self, referencing: achieve)
	}
	
	// The SHOW event tells us the indicator was not visible, but should be now.
	private func showProgressIndicator(achievement: UnsafePointer<rc_client_achievement_t>!) {
		let achieve = Client.Achievement(retroPointer: achievement, stateIcon: .active)
		delegate?.showProgressIndicator?(client: self, referencing: achieve)
	}
	
	// MARK: - User Account stuff
	
	private class RCKProgressCallback<A: Sendable> {
		let callback: CheckedContinuation<A, any Error>
		
		init(callback: CheckedContinuation<A, any Error>) {
			self.callback = callback
		}
	}
	
	/// Login with a user name and a password.
	///
	/// - parameter userName: The user name to log in with.
	/// - parameter password: The password to log in with.
	/// - parameter completionHandler: What will be called when the function is done, or if there's an error.
	/// - throws: If login failed.
	public func loginWith(userName: String, password: String) async throws {
		// This will generate an HTTP payload and call the server_call chain above.
		// Eventually, login_callback will be called to let us know if the login was successful.
		try await withCheckedThrowingContinuation { cont in
			let cb = RCKProgressCallback<Void>(callback: cont)
			let aCall = Unmanaged.passRetained(cb).toOpaque()
			//TODO: set up some way to cancel log-ins?
			rc_client_begin_login_with_password(_client, userName, password, { result, errorMessage, _, bCall in
				let cCall: RCKProgressCallback<Void> = Unmanaged.fromOpaque(bCall!).takeRetainedValue()
				if result == RC_OK {
					cCall.callback.resume()
				} else {
					var userInfo = [String: Any]()
					if let errorMessage {
						let tmpStr = String(cString: errorMessage)
						userInfo[NSLocalizedFailureReasonErrorKey] = tmpStr
						userInfo[NSLocalizedDescriptionKey] = tmpStr
					}
					cCall.callback.resume(throwing: RCKError(RCKError.Code(rawValue: result)!, userInfo: userInfo))
				}
			}, aCall)
		}
	}
	
	/// Login with a user name and a token.
	///
	/// - parameter userName: The user name to log in with.
	/// - parameter token: A login token generated when logged in before, generated by getting the ``loginToken``.
	/// The user name must match what was used to generate the login token beforehand.
	/// - parameter completionHandler: What will be called when the function is done, or if there's an error.
	/// - throws: If login failed. A common cause is that the login token expired.
	public func loginWith(userName: String, token: String) async throws {
		// This will generate an HTTP payload and call the server_call chain above.
		// Eventually, login_callback will be called to let us know if the login was successful.
		try await withCheckedThrowingContinuation { cont in
			let cb = RCKProgressCallback<Void>(callback: cont)
			let aCall = Unmanaged.passRetained(cb).toOpaque()
			//TODO: set up some way to cancel log-ins?
			rc_client_begin_login_with_token(_client, userName, token, { result, errorMessage, _, bCall in
				let cCall: RCKProgressCallback<Void> = Unmanaged.fromOpaque(bCall!).takeRetainedValue()
				if result == RC_OK {
					cCall.callback.resume()
				} else {
					var userInfo = [String: Any]()
					if let errorMessage {
						let tmpStr = String(cString: errorMessage)
						userInfo[NSLocalizedFailureReasonErrorKey] = tmpStr
						userInfo[NSLocalizedDescriptionKey] = tmpStr
					}
					cCall.callback.resume(throwing: RCKError(RCKError.Code(rawValue: result)!, userInfo: userInfo))
				}
			}, aCall)
		}
	}
	
	/// Logout of the current user account.
	public func logout() {
		rc_client_logout(_client)
	}
	
	/// Is the user logged in?
	@objc(loggedIn)
	public var isLoggedIn: Bool {
		@objc(isLoggedIn) get {
			return rc_client_get_user_info(_client) != nil
		}
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
	/// Will return `nil` if not logged in.
	public func userInfo() -> UserInfo? {
		guard let usrInf = rc_client_get_user_info(_client) else {
			return nil
		}
		
		return UserInfo(user: usrInf)
	}
	
	// MARK: - getters/setters

	/// Gets/sets whether hardcore is enabled (off by default).
	///
	/// Can be called with a game is loaded.
	/// Enabling hardcore with a game is loaded will call ``ClientDelegate/restartEmulationRequested(client:)``
	/// event. Processing will be disabled until ``Client/reset()`` is called.
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
	
	/// Returns `true` if the current game has any leaderboards.
	public var hasLeaderboards: Bool {
		return rc_client_has_leaderboards(_client) != 0
	}
	
	// MARK: -
	
	/// Get information about a leaderboard. Returns `nil` if not found.
	@objc(leaderboardInfoForIdentifier:)
	public func leaderboardInfo(for identifier: UInt32) -> Leaderboard? {
		guard let leaderboard = rc_client_get_leaderboard_info(_client, identifier) else {
			return nil
		}
		return Leaderboard(leaderboard: leaderboard)
	}
	
	/// Get information about an achievement. Returns `nil` if not found.
	@objc(achievementInfoforIdentifier:)
	public func achievementInfo(for id: UInt32) -> Client.Achievement? {
		guard let achievement = rc_client_get_achievement_info(_client, id) else {
			return nil
		}
		return Client.Achievement(retroPointer: achievement, stateIcon: Achievement.State(rawValue: achievement.pointee.state) ?? .disabled)
	}
	
	/// Returns the achievement list of the current game.
	public func achievementsList(category: Client.Achievement.Category = .coreAndUnofficial, grouping: Client.Achievement.ListGrouping = .progress) -> [Client.Achievement.Bucket]? {
		guard let list = rc_client_create_achievement_list(_client, Int32(category.rawValue), grouping.rawValue) else {
			return nil
		}
		defer {
			rc_client_destroy_achievement_list(list)
		}
		
		let buckets = UnsafeBufferPointer(start: list.pointee.buckets, count: Int(list.pointee.num_buckets))
		return buckets.map({Client.Achievement.Bucket(rcheevo: $0)})
	}
	
	/// Get information about the current game.
	///
	/// Returns `nil` if no game is loaded.
	/// - NOTE: returns a dummy game record if an unidentified game is loaded.
	public func gameInfo() -> GameInfo? {
		guard let gi = rc_client_get_game_info(_client) else {
			return nil
		}
		
		return GameInfo(gi: gi)
	}
	
	/// Gets all progress for the given console asynchonously. This query returns the total number of achievements for all games
	/// tracked by this console, as well as the user’s achievement unlock count for both softcore and hardcore modes.
	@objc(allUserProgressForConsole:completionHandler:)
	public func allUserProgress(for console: RCKConsoleIdentifier) async throws -> [UserProgressEntry] {
		return try await withCheckedThrowingContinuation { continuation in
			let anObj = RCKProgressCallback(callback: continuation)
			let aCall = Unmanaged.passRetained(anObj).toOpaque()
			
			rc_client_begin_fetch_all_user_progress(_client, console.rawValue, { result, errorMessage, list, client, ch in
				let callback2: RCKProgressCallback<[Client.UserProgressEntry]> = Unmanaged.fromOpaque(ch!).takeRetainedValue()
				guard result == R_OK else {
					var errorUserInfo: [String: Any] = [:]
					if let errorMessage {
						errorUserInfo[NSLocalizedFailureReasonErrorKey] = String(cString: errorMessage)
						errorUserInfo[NSLocalizedDescriptionKey] = String(cString: errorMessage)
					}
					callback2.callback.resume(throwing: RCKError(RCKError.Code(rawValue: result)!, userInfo: errorUserInfo))
					return
				}
				defer {
					rc_client_destroy_all_user_progress(list)
				}
				let safeList = UnsafeBufferPointer(list?.pointee)
				callback2.callback.resume(returning: safeList.map({UserProgressEntry(raInternal: $0)}))
			}, aCall)
		}
	}
	
	@objc(RCKUserProgressEntry) @objcMembers
	public final class UserProgressEntry: NSObject, Codable, Sendable {
		public let gameID: UInt32
		public let countOfAchievements: UInt32
		public let countOfUnlockedAchievements: UInt32
		public let countOfUnlockedHardcoreAchievements: UInt32
		
		@nonobjc
		internal init(raInternal: rc_client_all_user_progress_entry_t) {
			self.gameID = raInternal.game_id
			self.countOfAchievements = raInternal.num_achievements
			self.countOfUnlockedAchievements = raInternal.num_unlocked_achievements
			self.countOfUnlockedHardcoreAchievements = raInternal.num_unlocked_achievements_hardcore
			super.init()
		}
	}
	
	// MARK: - Logging

	@objc(RCKClientLogLevel)
	public enum LogLevel: CInt, Sendable, Codable {
		case none = 0
		case `error`
		case warning
		case info
		case verbose
	}
	
	/// Sets the logging level. The delegate must implement ``ClientDelegate/client(_:receivedMessage:)``
	/// in order to receive messages.
	public func enableLogging(level: LogLevel) {
		rc_client_enable_logging(_client, level.rawValue) { message, client in
			guard let usrDat = rc_client_get_userdata(client), let message else {
				return
			}
			let aSelf: Client = Unmanaged.fromOpaque(usrDat).takeUnretainedValue()
			aSelf.delegate?.client?(aSelf, receivedMessage: String(cString: message))
		}
	}
	
	// MARK: - hashing
	
	@objc(RCKClientHashEntry) @objcMembers
	final public class HashEntry: NSObject, Codable, Sendable {
		public let hashString: String
		public let gameID: UInt32
		
		@nonobjc
		internal init(raInternal: rc_client_hash_library_entry_t) {
			let preHash: [CChar] = [raInternal.hash.0, raInternal.hash.1, raInternal.hash.2,
									raInternal.hash.3, raInternal.hash.4, raInternal.hash.5,
									raInternal.hash.6, raInternal.hash.7, raInternal.hash.8,
									raInternal.hash.9, raInternal.hash.10, raInternal.hash.11,
									raInternal.hash.12, raInternal.hash.13, raInternal.hash.14,
									raInternal.hash.15, raInternal.hash.16, raInternal.hash.17,
									raInternal.hash.18, raInternal.hash.19, raInternal.hash.20,
									raInternal.hash.21, raInternal.hash.22, raInternal.hash.23,
									raInternal.hash.24, raInternal.hash.25, raInternal.hash.26,
									raInternal.hash.27, raInternal.hash.28, raInternal.hash.29,
									raInternal.hash.30, raInternal.hash.31, 0]
			self.hashString = String(cString: preHash)
			self.gameID = raInternal.game_id
			super.init()
		}
		
		public override var hash: Int {
			var hash = Hasher()
			hash.combine(hashString)
			return hash.finalize()
		}
	}
	
	/// Starts an asynchronous request for all hashes for the given console.
	///
	/// This request returns a mapping from hashes to the game's unique identifier. A single game may have multiple
	/// hashes in the case of multi-disc games, or variants that are still compatible with the same achievement set.
	public func fetchHashLibrary(for consoleID: RCKConsoleIdentifier) async throws -> [HashEntry] {
		return try await withCheckedThrowingContinuation { cont in
			let cb = RCKProgressCallback<[HashEntry]>(callback: cont)
			let aCall = Unmanaged.passRetained(cb).toOpaque()
			rc_client_begin_fetch_hash_library(_client, consoleID.rawValue, { result, errorMessage, list, _, bCall in
				let cCall: RCKProgressCallback<[HashEntry]> = Unmanaged.fromOpaque(bCall!).takeRetainedValue()
				guard result == RC_OK, let list else {
					var dict = [String: Any]()
					if let errorMessage {
						let tmpStr = String(cString: errorMessage)
						dict[NSLocalizedFailureReasonErrorKey] = tmpStr
						dict[NSLocalizedDescriptionKey] = tmpStr
					}
					cCall.callback.resume(throwing: RCKError(RCKError.Code(rawValue: result) ?? .apiFailure, userInfo: dict))
					return
				}
				
				let hashList = UnsafeBufferPointer(list.pointee)
				
				defer {
					rc_client_destroy_hash_library(list)
				}
				
				cCall.callback.resume(returning: hashList.map({HashEntry(raInternal: $0)}))
			}, aCall)
		}
	}
}

extension RCKError.Code: CustomStringConvertible {
	public var description: String {
		let des = rc_error_str(self.rawValue)!
		return String(cString: des)
	}
}

extension RCKConsoleIdentifier: CustomStringConvertible, CustomDebugStringConvertible, Codable {
	
	public var debugDescription: String {
		return "\(self) (\(self.rawValue))"
	}
}


//Additional classes
public extension Client {
	/// The user info.
	@objc(RCKClientUserInfo) @objcMembers
	final class UserInfo: NSObject, Sendable, Codable {
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

		public let avatarURL: URL?
		
		@nonobjc
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
			
			if let preAvatar = hi.pointee.avatar_url {
				avatarURL = URL(string: String(cString: preAvatar))
			} else {
				avatarURL = nil
			}
		}
		
		public override var description: String {
			return "\(displayName) (\(userName)), score: \(score) (softcore: \(softcoreScore))"
		}
	}

	@objc(RCKLeaderboardTracker) @objcMembers
	final class LeaderboardTracker: NSObject, Sendable, Codable {
		public let display: String
		public let identifier: UInt32
		
		@nonobjc
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
		
		public override func isEqual(_ object: Any?) -> Bool {
			guard let object1 = object as? LeaderboardTracker else {
				return false
			}
			return self == object1
		}
		
		public static func == (lhs: LeaderboardTracker, rhs: LeaderboardTracker) -> Bool {
			return lhs.identifier == rhs.identifier
		}
		
		public override var description: String {
			return "ID ‘\(identifier)’, \(display)"
		}
	}
}

internal protocol RcheevosCountedBuffer {
	associatedtype Value
	var entries: UnsafeMutablePointer<Value>! { get }
	var num_entries: UInt32 { get }
}

extension rc_client_hash_library_t: RcheevosCountedBuffer {
	typealias Value = rc_client_hash_library_entry_t
}

extension rc_client_all_user_progress_t: RcheevosCountedBuffer {
	typealias Value = rc_client_all_user_progress_entry_t
}

internal extension UnsafeBufferPointer {
	/// Creates an `UnsafeBufferPointer` over the contiguous `Element` instances beginning
	/// at `start`, iterating until `sentinelChecker` returns `true`.
	///
	/// This is great for array pointers that have an unknown number of elements but does have
	/// a terminating element, or *sentinel*, that indicates the end of the array.
	/// The sentinal isn't included in the buffer.
	/// - parameter start: the pointer to start from.
	/// - parameter sentinelChecker: The block that checks if the current `Element`
	/// is the sentinel, or last object in an array. Return `true` if `toCheck`
	/// matches the characteristic of the sentinal.
	/// - parameter toCheck: The current element to check.
	@inlinable init<E>(start: UnsafePointer<Element>, sentinel sentinelChecker: (_ toCheck: Element) throws(E) -> Bool) throws(E) {
		var toIterate = start
		
		while !(try sentinelChecker(toIterate.pointee)) {
			toIterate = toIterate.advanced(by: 1)
		}
		
		self = UnsafeBufferPointer(start: start, count: start.distance(to: toIterate))
	}
	
	init<E>(_ count: E?) where E: RcheevosCountedBuffer, E.Value == Element {
		self = UnsafeBufferPointer(start: count?.entries, count: Int(count?.num_entries ?? 0))
	}
}
