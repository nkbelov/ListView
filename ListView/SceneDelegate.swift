//
//  SceneDelegate.swift
//  ListView
//
//  Created by WTEDST on 14.08.21.
//

import UIKit

class SceneDelegate: UIResponder, UIWindowSceneDelegate {

    var window: UIWindow?
    let viewController = ViewController()

    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        guard let scene = (scene as? UIWindowScene) else { return }
        
        window = window ?? UIWindow(windowScene: scene)
        window!.rootViewController = viewController
        window!.makeKeyAndVisible()
    }
}

