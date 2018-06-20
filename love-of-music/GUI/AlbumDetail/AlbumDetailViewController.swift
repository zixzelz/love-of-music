//
//  AlbumDetailViewController.swift
//  love-of-music
//
//  Created by Ruslan Maslouski on 6/18/18.
//  Copyright © 2018 Ruslan Maslouski. All rights reserved.
//

import UIKit

protocol AlbumDetailViewModeling {
    var ganre: String? { get }
    var style: String? { get }
    var year: String? { get }
    var title: String? { get }
}

class AlbumDetailViewController: UIViewController {

    @IBOutlet private weak var ganreLabel: UILabel!
    @IBOutlet private weak var styleLabel: UILabel!
    @IBOutlet private weak var yearLabel: UILabel!

    var viewModel: AlbumDetailViewModeling? {
        didSet {
            if isViewLoaded {
                bind(viewModel: viewModel)
            }
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        
        bind(viewModel: viewModel)
    }

    func bind(viewModel: AlbumDetailViewModeling?) {
        navigationItem.title = viewModel?.title
        ganreLabel.text = viewModel?.ganre
        styleLabel.text = viewModel?.style
        yearLabel.text = viewModel?.year
    }
    
}
