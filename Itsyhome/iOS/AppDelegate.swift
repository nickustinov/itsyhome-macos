//
//  AppDelegate.swift
//  Itsyhome
//
//  Main iOS app delegate - initializes HomeKit and loads macOS plugin
//

import UIKit
import HomeKit

@main
class AppDelegate: UIResponder, UIApplicationDelegate {
    
    var homeKitManager: HomeKitManager?
    var macOSController: iOS2Mac?
    
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        
        // Initialize HomeKit manager
        homeKitManager = HomeKitManager()
        
        // Load macOS plugin on Catalyst
        #if targetEnvironment(macCatalyst)
        loadMacOSPlugin()
        #endif
        
        return true
    }
    
    #if targetEnvironment(macCatalyst)
    private func loadMacOSPlugin() {
        let bundleFileName = "macOSBridge.bundle"
        
        // Try PlugIns folder first, then Resources (xcodegen puts it in Resources)
        var bundleURL: URL?
        
        if let pluginsURL = Bundle.main.builtInPlugInsURL {
            let pluginsPath = pluginsURL.appendingPathComponent(bundleFileName)
            if FileManager.default.fileExists(atPath: pluginsPath.path) {
                bundleURL = pluginsPath
            }
        }
        
        if bundleURL == nil, let resourcesURL = Bundle.main.resourceURL {
            let resourcesPath = resourcesURL.appendingPathComponent(bundleFileName)
            if FileManager.default.fileExists(atPath: resourcesPath.path) {
                bundleURL = resourcesPath
            }
        }
        
        guard let bundleURL = bundleURL else {
            print("Plugin bundle not found in PlugIns or Resources")
            return
        }
        
        print("Loading plugin from: \(bundleURL.path)")
        
        guard let bundle = Bundle(url: bundleURL) else {
            print("Failed to create bundle from URL")
            return
        }
        
        guard let pluginClass = bundle.principalClass as? iOS2Mac.Type else {
            print("Failed to get principalClass as iOS2Mac.Type")
            print("Principal class: \(String(describing: bundle.principalClass))")
            return
        }
        
        macOSController = pluginClass.init()
        macOSController?.iOSBridge = homeKitManager
        homeKitManager?.macOSDelegate = macOSController
        
        print("macOSBridge plugin loaded successfully!")
    }
    #endif
    
    // MARK: - UISceneSession Lifecycle
    
    func application(_ application: UIApplication, configurationForConnecting connectingSceneSession: UISceneSession, options: UIScene.ConnectionOptions) -> UISceneConfiguration {
        return UISceneConfiguration(name: "Default Configuration", sessionRole: connectingSceneSession.role)
    }
}
