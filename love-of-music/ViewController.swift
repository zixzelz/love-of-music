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

        releasesService = ReleasesService()
        releasesService.getItems { (result) in
            print("\(result)")
        }
    }

}
