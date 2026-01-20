//
//  SceneDelegate.swift
//  Itsyhome
//
//  Handles window scenes - hides the main window on macCatalyst
//

import UIKit

class SceneDelegate: UIResponder, UIWindowSceneDelegate {
    
    var window: UIWindow?
    
    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        guard let windowScene = (scene as? UIWindowScene) else { return }
        
        #if targetEnvironment(macCatalyst)
        // Hide the window on Mac - we only use the menu bar
        windowScene.sizeRestrictions?.minimumSize = CGSize(width: 1, height: 1)
        windowScene.sizeRestrictions?.maximumSize = CGSize(width: 1, height: 1)
        
        // Create a tiny invisible window
        let window = UIWindow(windowScene: windowScene)
        window.frame = CGRect(x: 0, y: 0, width: 1, height: 1)
        window.rootViewController = UIViewController()
        window.makeKeyAndVisible()
        self.window = window
        
        // Hide from dock
        DispatchQueue.main.async {
            windowScene.windows.forEach { $0.isHidden = true }
        }
        #else
        // On iOS, show a placeholder view
        let window = UIWindow(windowScene: windowScene)
        let vc = UIViewController()
        vc.view.backgroundColor = .systemBackground
        
        let label = UILabel()
        label.text = "Itsyhome runs in the menu bar on Mac"
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        vc.view.addSubview(label)
        NSLayoutConstraint.activate([
            label.centerXAnchor.constraint(equalTo: vc.view.centerXAnchor),
            label.centerYAnchor.constraint(equalTo: vc.view.centerYAnchor)
        ])
        
        window.rootViewController = vc
        window.makeKeyAndVisible()
        self.window = window
        #endif
    }
}
