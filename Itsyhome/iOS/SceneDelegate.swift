//
//  SceneDelegate.swift
//  Itsyhome
//
//  Handles window scenes - hides the main window on macCatalyst
//

import UIKit

class SceneDelegate: UIResponder, UIWindowSceneDelegate {

    var window: UIWindow?

    private var macOSController: iOS2Mac? {
        (UIApplication.shared.delegate as? AppDelegate)?.macOSController
    }

    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        guard let windowScene = (scene as? UIWindowScene) else { return }

        #if targetEnvironment(macCatalyst)
        // Hide the window on Mac - we only use the menu bar
        windowScene.sizeRestrictions?.minimumSize = CGSize(width: 1, height: 1)
        windowScene.sizeRestrictions?.maximumSize = CGSize(width: 1, height: 1)

        // Create a tiny invisible window (never ordered front — see swizzle
        // in MacOSController that blocks 1×1 windows from Mission Control)
        let window = UIWindow(windowScene: windowScene)
        window.frame = CGRect(x: 0, y: 0, width: 1, height: 1)
        window.rootViewController = UIViewController()
        window.isHidden = true
        self.window = window

        // Handle any URLs passed at launch
        for urlContext in connectionOptions.urlContexts {
            handleURL(urlContext.url)
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

    func scene(_ scene: UIScene, openURLContexts URLContexts: Set<UIOpenURLContext>) {
        for context in URLContexts {
            handleURL(context.url)
        }
    }

    private func handleURL(_ url: URL) {
        #if targetEnvironment(macCatalyst)
        if let command = URLSchemeHandler.handle(url) {
            _ = macOSController?.executeCommand(command)
        }
        #endif
    }
}
