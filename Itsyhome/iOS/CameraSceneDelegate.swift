//
//  CameraSceneDelegate.swift
//  Itsyhome
//
//  UIWindowSceneDelegate for the camera panel
//

import UIKit

class CameraSceneDelegate: UIResponder, UIWindowSceneDelegate {

    var window: UIWindow?

    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        guard let windowScene = scene as? UIWindowScene else { return }

        #if targetEnvironment(macCatalyst)
        let cameraActivityType = "com.nickustinov.itsyhome.camera"
        let hasCameraActivity = connectionOptions.userActivities.contains { $0.activityType == cameraActivityType } ||
            session.stateRestorationActivity?.activityType == cameraActivityType

        if !hasCameraActivity {
            UIApplication.shared.requestSceneSessionDestruction(session, options: nil, errorHandler: nil)
            return
        }

        let gridWidth: CGFloat = 300
        let height = Self.computePanelHeight(gridWidth: gridWidth)

        windowScene.sizeRestrictions?.minimumSize = CGSize(width: gridWidth, height: height)
        windowScene.sizeRestrictions?.maximumSize = CGSize(width: gridWidth, height: height)
        windowScene.title = "Cameras"

        if let titlebar = windowScene.titlebar {
            titlebar.titleVisibility = .hidden
            titlebar.toolbar = nil
        }
        #endif

        let window = UIWindow(windowScene: windowScene)
        window.rootViewController = CameraViewController()
        window.isHidden = true
        self.window = window
    }

    func sceneDidDisconnect(_ scene: UIScene) {
        if let cameraVC = window?.rootViewController as? CameraViewController {
            cameraVC.stopAllStreams()
        }
    }

    // Compute panel height using the same constants as CameraViewController
    private static func computePanelHeight(gridWidth: CGFloat) -> CGFloat {
        let sectionTop: CGFloat = 15
        let sectionBottom: CGFloat = 15
        let sectionSide: CGFloat = 12
        let lineSpacing: CGFloat = 8
        let labelHeight: CGFloat = 28

        let appDelegate = UIApplication.shared.delegate as? AppDelegate
        let count: Int
        if PlatformManager.shared.selectedPlatform == .homeAssistant {
            count = CameraViewController.cachedHACameras.count
        } else {
            count = appDelegate?.homeKitManager?.cameraAccessories.count ?? 0
        }
        guard count > 0 else { return 150 }

        let cellWidth = gridWidth - sectionSide * 2
        let cellHeight = cellWidth * 9.0 / 16.0 + labelHeight

        if count <= 3 {
            return sectionTop + CGFloat(count) * cellHeight + CGFloat(count - 1) * lineSpacing + sectionBottom
        } else {
            return sectionTop + 3 * cellHeight + 2 * lineSpacing + lineSpacing + cellHeight * 0.5
        }
    }
}
