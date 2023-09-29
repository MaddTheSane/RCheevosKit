//
//  AppDelegate.swift
//  RCKTesting
//
//  Created by C.W. Betts on 9/3/23.
//

import Cocoa
import RcheevosKit
import RcheevosKit.RCKConsoles
import RcheevosKit.RCKClientAchievement
import RcheevosKit.RCKError

@main
class AppDelegate: NSObject, NSApplicationDelegate, ClientDelegate {
	func readMemory(client: RcheevosKit.Client, at address: UInt32, count num_bytes: UInt32) -> Data {
		return Data()
	}
	
	func loginSuccessful(client: RcheevosKit.Client) {
		
	}
	
	func loginFailed(client: RcheevosKit.Client, with: Error) {
		DispatchQueue.main.async {
			NSSound.beep()
			let alert = NSAlert(error: with)
			alert.alertStyle = .critical
			alert.runModal()
		}
	}
	
	func restartEmulationRequested(client: RcheevosKit.Client) {
		DispatchQueue.main.async {
			let alert = NSAlert()
			
			alert.messageText = "Restart requested!"
			
			alert.runModal()
		}
	}
	
	func gameLoadedSuccessfully(client: RcheevosKit.Client) {
		
	}
	
	func gameFailedToLoad(client: RcheevosKit.Client, error: Error) {
		DispatchQueue.main.async {
			NSSound.beep()
		}
	}
	
	func gameCompleted(client: RcheevosKit.Client) {
		
	}
	
	func serverError(client: RcheevosKit.Client, message: String?, api: String?) {
		
	}
	
	func client(_ client: RcheevosKit.Client, got achievement: RCKClientAchievement) {
		
	}

	@IBOutlet var window: NSWindow!
	@IBOutlet var userNameField: NSTextField!
	@IBOutlet var passwordField: NSSecureTextField!

	var client = Client()

	func applicationDidFinishLaunching(_ aNotification: Notification) {
		client.delegate = self
		client.start()
		client.spectatorMode = true
	}

	func applicationWillTerminate(_ aNotification: Notification) {
		// Insert code here to tear down your application
	}

	func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
		return true
	}

	@IBAction func logIn(_ sender: AnyObject?) {
		let name = userNameField.stringValue
		let pass = passwordField.stringValue
		guard !name.isEmpty,
			  !pass.isEmpty else {
			NSSound.beep()
			return
		}
		client.useUnofficialAchievements = true
		client.loginWith(userName: name, password: pass)
	}

	@IBAction func selectGame(_ sender: AnyObject?) {
		let openPanel = NSOpenPanel()
		
		openPanel.beginSheetModal(for: self.window) { response in
			if response == .OK {
				self.client.loadGame(from: openPanel.url!)
			}
		}
	}
}

