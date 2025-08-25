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
	@MainActor @IBOutlet weak var loginStatus: NSImageView!
	fileprivate var achievements = [Client.Achievement.Bucket]()

	var client = Client()

	func readMemory(client: RcheevosKit.Client, at address: UInt32, count num_bytes: UInt32) -> Data {
		return Data()
	}
	
	func restartEmulationRequested(client: RcheevosKit.Client) {
		DispatchQueue.main.async {
			let alert = NSAlert()
			
			alert.messageText = "Restart requested!"
			
			alert.runModal()
		}
	}
	
	func gameCompleted(with client: RcheevosKit.Client) {
		
	}
	
	func serverError(from client: RcheevosKit.Client, message: String?, api: String?) {
		
	}
	
	func client(_ client: RcheevosKit.Client, got achievement: Client.Achievement) {
		
	}

	func applicationDidFinishLaunching(_ aNotification: Notification) {
		client.delegate = self
		client.spectatorMode = true
		client.useUnofficialAchievements = true
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
		Task {
			do {
				try await client.loginWith(userName: name, password: pass)
				self.loginStatus.image = NSImage(named: NSImage.statusPartiallyAvailableName)
			} catch {
				NSSound.beep()
				self.loginStatus.image = NSImage(named: NSImage.statusUnavailableName)
				
				let alert = NSAlert(error: error)
				alert.alertStyle = .critical
				alert.runModal()
			}
		}
	}

	@IBAction func selectGame(_ sender: AnyObject?) {
		Task {
			let openPanel = NSOpenPanel()
			
			let response = await openPanel.begin()
			if response == .OK {
				do {
					try await self.client.loadGame(from: openPanel.url!)
					self.loginStatus.image = NSImage(named: NSImage.statusAvailableName)
					self.achievements = self.client.achievementsList() ?? []
					self.achievementsView.reloadData()
					
					self.gameNameView.stringValue = self.client.gameInfo()?.title ?? "Unknown Game"
					
				} catch {
					NSSound.beep()
					if self.client.isLoggedIn {
						self.loginStatus.image = NSImage(named: NSImage.statusPartiallyAvailableName)
					}
					self.achievements.removeAll()
					self.achievementsView.reloadData()
					
					self.gameNameView.stringValue = "No Game"
					let alert = NSAlert(error: error)
					alert.alertStyle = .critical
					alert.runModal()
				}
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
//			icon = item.currentIcon
			icon = nil
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
