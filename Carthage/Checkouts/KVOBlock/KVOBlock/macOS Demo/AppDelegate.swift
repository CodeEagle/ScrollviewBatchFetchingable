//
//  AppDelegate.swift
//  macOS Demo
//
//  Created by LawLincoln on 16/7/4.
//  Copyright © 2016年 SelfStudio. All rights reserved.
//

import Cocoa
import KVOBlock
@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate {

    @IBOutlet weak var window: NSWindow!


    func applicationDidFinishLaunching(_ aNotification: Notification) {
        // Insert code here to initialize your application
        window.observeKeyPath("title") { (_, old, new) in
            print("new:\(new)")
        }
        window.title = "hahah"
    }

    func applicationWillTerminate(_ aNotification: Notification) {
        // Insert code here to tear down your application
    }


}

