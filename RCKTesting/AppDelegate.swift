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
		DispatchQueue.main.async {
			self.achievements = self.client.achievementsList() ?? []
			self.achievementsView.reloadData()
		}
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
	
	func client(_ client: RcheevosKit.Client, got achievement: Client.Achievement) {
		
	}

	@IBOutlet var window: NSWindow!
	@IBOutlet var userNameField: NSTextField!
	@IBOutlet var passwordField: NSSecureTextField!
	@IBOutlet weak var achievementsView: NSOutlineView!
	fileprivate var achievements = [Client.Achievement.Bucket]()

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

extension AppDelegate: NSOutlineViewDataSource, NSOutlineViewDelegate {
	func outlineView(_ outlineView: NSOutlineView, numberOfChildrenOfItem item: Any?) -> Int {
		if item == nil {
			return achievements.count
		} else if let item = item as? Client.Achievement.Bucket {
			return item.achievements.count
		}
		return 0
	}
	
	func outlineView(_ outlineView: NSOutlineView, child index: Int, ofItem item: Any?) -> Any {
		if item == nil {
			return achievements[index]
		} else if let item = item as? Client.Achievement.Bucket {
			return item.achievements[index]
		}
		return NSNull()
	}
	
	func outlineView(_ outlineView: NSOutlineView, isItemExpandable item: Any) -> Bool {
		if let item = item as? Client.Achievement.Bucket {
			return item.achievements.count != 0
		}
		return false
	}
	
	func outlineView(_ outlineView: NSOutlineView, viewFor tableColumn: NSTableColumn?, item: Any) -> NSView? {
		return nil
	}
}
