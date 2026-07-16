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

        // Pre-size approximation only – CameraViewController corrects the
        // exact size (spans, real aspect ratios) as soon as it appears.
        let columns = max(1, min(3, UserDefaults.standard.object(forKey: "cameraGridColumns") as? Int ?? 2))
        let gridWidth: CGFloat = 12 * 2 + CGFloat(columns) * 276 + CGFloat(columns - 1) * 8
        let height = Self.computePanelHeight(gridWidth: gridWidth, columns: columns)

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

    // Compute panel height using the same constants as CameraViewController,
    // approximating every tile as a 16:9 column tile (spans and detected
    // ratios are the view controller's concern).
    private static func computePanelHeight(gridWidth: CGFloat, columns: Int) -> CGFloat {
        let sectionTop: CGFloat = 15
        let sectionBottom: CGFloat = 15
        let sectionSide: CGFloat = 12
        let lineSpacing: CGFloat = 8

        let appDelegate = UIApplication.shared.delegate as? AppDelegate
        let count: Int
        if PlatformManager.shared.selectedPlatform == .homeAssistant {
            count = CameraViewController.cachedHACameras.count
        } else {
            count = appDelegate?.homeKitManager?.cameraAccessories.count ?? 0
        }
        guard count > 0 else { return 150 }

        let cellWidth = columns == 1 ? gridWidth - sectionSide * 2 : 276
        let rowHeight = cellWidth * 9.0 / 16.0
        let rows = (count + columns - 1) / columns

        if rows <= 3 {
            return min(CameraPanelBounds.maxHeight, sectionTop + CGFloat(rows) * rowHeight + CGFloat(rows - 1) * lineSpacing + sectionBottom)
        } else {
            return min(CameraPanelBounds.maxHeight, sectionTop + 3 * rowHeight + 2 * lineSpacing + lineSpacing + rowHeight * 0.5)
        }
    }
}
