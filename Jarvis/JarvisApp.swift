//
//  JarvisApp.swift
//  Jarvis
//
//  Created by Harsh Surati on 17/12/24.
//

import SwiftUI
import GoogleSignIn

@main
struct JarvisApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                .onOpenURL { url in
                    GIDSignIn.sharedInstance.handle(url)
                }
        }
    }
}
