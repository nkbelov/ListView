//
//  ViewController.swift
//  ListView
//
//  Created by WTEDST on 14.08.21.
//

import UIKit

class ViewController: UIViewController {

    private let listView = ListView()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        view.addSubview(listView)
        listView.backgroundColor = .systemTeal
    }
    
    override func viewWillLayoutSubviews() {
        listView.frame = view.bounds.inset(by: view.safeAreaInsets).insetBy(dx: 16, dy: 24)
    }


}

