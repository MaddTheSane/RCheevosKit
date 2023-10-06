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
	@IBOutlet var window: NSWindow!
	@IBOutlet var userNameField: NSTextField!
	@IBOutlet var passwordField: NSSecureTextField!
	@IBOutlet weak var achievementsView: NSOutlineView!
	@IBOutlet weak var gameNameView: NSTextField!
	@IBOutlet weak var loginStatus: NSImageView!
	fileprivate var achievements = [Client.Achievement.Bucket]()

	var client = Client()

	func readMemory(client: RcheevosKit.Client, at address: UInt32, count num_bytes: UInt32) -> Data {
		return Data()
	}
	
	func loginSuccessful(client: RcheevosKit.Client) {
		DispatchQueue.main.async {
			self.loginStatus.image = NSImage(named: NSImage.statusPartiallyAvailableName)
		}
	}
	
	func loginFailed(client: RcheevosKit.Client, with: Error) {
		DispatchQueue.main.async {
			NSSound.beep()
			self.loginStatus.image = NSImage(named: NSImage.statusUnavailableName)

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
			self.loginStatus.image = NSImage(named: NSImage.statusAvailableName)
			self.achievements = self.client.achievementsList() ?? []
			self.achievementsView.reloadData()
			
			self.gameNameView.stringValue = self.client.gameInfo()?.title ?? "Unknown Game"
		}
	}
	
	func gameFailedToLoad(client: RcheevosKit.Client, error: Error) {
		DispatchQueue.main.async {
			self.loginStatus.image = NSImage(named: NSImage.statusPartiallyAvailableName)
			NSSound.beep()
			self.achievements.removeAll()
			self.achievementsView.reloadData()
			
			self.gameNameView.stringValue = "No Game"
		}
	}
	
	func gameCompleted(client: RcheevosKit.Client) {
		
	}
	
	func serverError(client: RcheevosKit.Client, message: String?, api: String?) {
		
	}
	
	func client(_ client: RcheevosKit.Client, got achievement: Client.Achievement) {
		
	}

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
		let name: String
		let info: String
		let icon: NSImage?
		if let item = item as? Client.Achievement.Bucket {
			name = item.label
			info = ""
			icon = client.gameInfo()?.image
		} else if let item = item as? Client.Achievement {
			name = item.title
			info = item.achievementDescription
			icon = item.currentIcon
		} else {
			fatalError("We shouldn't be getting here...")
		}

		guard let id = tableColumn?.identifier else {
			return nil
		}
		switch id {
		case nameIdentifier:
			return NSTextField(string: name)
			
		case infoIdentifier:
			return NSTextField(string: info)

		case iconIdentifier:
			if let icon {
				return NSImageView(image: icon)
			}
			return NSImageView(image: NSImage(named: NSImage.cautionName)!)
			
		default:
			return nil
		}
	}
}

let nameIdentifier = NSUserInterfaceItemIdentifier("AutomaticTableColumnIdentifier.0")
let infoIdentifier = NSUserInterfaceItemIdentifier("AutomaticTableColumnIdentifier.1")
let iconIdentifier = NSUserInterfaceItemIdentifier("IconViewTableColumnIdentifier")
