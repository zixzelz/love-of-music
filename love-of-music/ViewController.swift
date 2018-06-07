//
//  ViewController.swift
//  love-of-music
//
//  Created by Ruslan Maslouski on 6/5/18.
//  Copyright © 2018 Ruslan Maslouski. All rights reserved.
//

import UIKit

class ViewController: UIViewController {

    var releasesService: ReleasesService!

    override func viewDidLoad() {
        super.viewDidLoad()

        let range = NSRange(location: 0, length: 6)

        releasesService = ReleasesService()
        releasesService.getItemsPage(range: range) { (result) in
            guard case .success(let items) = result else {
                print("error: \(result)")
                return
            }
            print("result: \(items.count)\n\(items)")
        }
    }

}
