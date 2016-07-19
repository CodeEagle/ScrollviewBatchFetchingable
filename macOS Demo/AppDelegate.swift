//
//  AppDelegate.swift
//  macOS Demo
//
//  Created by LawLincoln on 16/7/4.
//  Copyright © 2016年 CocoaPods. All rights reserved.
//

import Cocoa
import ScrollviewBatchFetchingable
@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate {

    @IBOutlet weak var window: NSWindow!
    let sc = NSScrollView(frame: NSMakeRect(0, 0, 300,400))


    func applicationDidFinishLaunching(_ aNotification: Notification) {
        // Insert code here to initialize your application
        window.contentView?.addSubview(sc)
        sc.ss_leadingScreensForBatching = 1.5
    }

    func applicationWillTerminate(_ aNotification: Notification) {
        // Insert code here to tear down your application
    }


}

