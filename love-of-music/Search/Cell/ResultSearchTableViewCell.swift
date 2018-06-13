//
//  SearchTableViewCell.swift
//  love-of-music
//
//  Created by Ruslan Maslouski on 6/13/18.
//  Copyright © 2018 Ruslan Maslouski. All rights reserved.
//

import UIKit

class ResultSearchTableViewCell: UITableViewCell, CellIdentifier {

    func configure(viewModel: ResultSearchCellViewModel) {
        textLabel?.text = viewModel.title
    }
    
}
