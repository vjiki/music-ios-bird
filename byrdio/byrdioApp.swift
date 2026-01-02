//
//  byrdioApp.swift
//  byrdio
//
//  Created by Nikolai Golubkin on 15. 8. 2025..
//

import SwiftUI
import FirebaseCore
import GoogleSignIn

@main
struct byrdioApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate
    
    var body: some Scene {
        WindowGroup {
            Home()
                .preferredColorScheme(.dark)
                .onOpenURL { url in
                    GIDSignIn.sharedInstance.handle(url)
                }
        }
    }
}

// MARK: - App Delegate for Firebase and Google Sign-In
class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        // Configure Firebase - this will automatically read GoogleService-Info.plist
        // Make sure GoogleService-Info.plist is in the app bundle
        guard let path = Bundle.main.path(forResource: "GoogleService-Info", ofType: "plist") else {
            print("⚠️ Warning: GoogleService-Info.plist not found in bundle")
            return true
        }
        
        // Configure Firebase
        FirebaseApp.configure()
        
        // Configure Google Sign-In with the client ID from GoogleService-Info.plist
        if let plist = NSDictionary(contentsOfFile: path),
           let clientID = plist["CLIENT_ID"] as? String {
            GIDSignIn.sharedInstance.configuration = GIDConfiguration(clientID: clientID)
            print("✅ Google Sign-In configured with Client ID")
        } else {
            print("⚠️ Warning: Could not read CLIENT_ID from GoogleService-Info.plist")
        }
        
        return true
    }
    
    func application(_ app: UIApplication, open url: URL, options: [UIApplication.OpenURLOptionsKey : Any] = [:]) -> Bool {
        return GIDSignIn.sharedInstance.handle(url)
    }
}
