//
//  DefaultTableViewCell.swift
//  love-of-music
//
//  Created by Ruslan Maslouski on 6/12/18.
//  Copyright © 2018 Ruslan Maslouski. All rights reserved.
//

import UIKit

class DefaultTableViewCell: UITableViewCell {

    func configure(viewModel: ReleasesCellViewModel) {
        textLabel?.text = viewModel.title
    }
}
