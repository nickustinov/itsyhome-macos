//
//  CameraSceneDelegate.swift
//  Itsyhome
//
//  UIWindowSceneDelegate for the camera window
//

import UIKit

class CameraSceneDelegate: UIResponder, UIWindowSceneDelegate {

    var window: UIWindow?

    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        guard let windowScene = scene as? UIWindowScene else { return }

        #if targetEnvironment(macCatalyst)
        windowScene.title = "Cameras"
        windowScene.sizeRestrictions?.minimumSize = CGSize(width: 640, height: 480)
        windowScene.sizeRestrictions?.maximumSize = CGSize(width: 1920, height: 1080)
        #endif

        let window = UIWindow(windowScene: windowScene)
        window.rootViewController = CameraViewController()
        window.makeKeyAndVisible()
        self.window = window
    }

    func sceneDidDisconnect(_ scene: UIScene) {
        if let cameraVC = window?.rootViewController as? CameraViewController {
            cameraVC.stopAllStreams()
        }
    }
}
