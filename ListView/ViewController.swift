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
        
        // Setting this property to `false` lets you see rows being reused in action!
        listView.clipsToBounds = false
        
        listView.reload(dimensions: [100, 200]) { index, listView in
            let label = listView.dequeueRow(type: UILabel.self, at: index)
            label.backgroundColor = .systemGreen
            label.text = "Section: \(index.section), row: \(index.row)"
            return label
        }
    }
    
    override func viewWillLayoutSubviews() {
        listView.frame = view.bounds.inset(by: view.safeAreaInsets).insetBy(dx: 16, dy: 24)
    }


}

extension UILabel: RowView { }
