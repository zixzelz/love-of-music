//
//  SearchTableViewCell.swift
//  love-of-music
//
//  Created by Ruslan Maslouski on 6/13/18.
//  Copyright © 2018 Ruslan Maslouski. All rights reserved.
//

import UIKit
import ServiceLayerSDK

class ResultSearchTableViewCell: UITableViewCell, CellIdentifier {

    @IBOutlet private var _imageView: SimpleImageView!
    @IBOutlet private var _textLabel: UILabel!
    @IBOutlet private var _detailTextLabel: UILabel!

    func configure(viewModel: ResultSearchCellViewModel) {
        _imageView.setImage(url: viewModel.imageURL, placeholder: UIImage(named: "placeholder-music"))
        _textLabel.text = viewModel.title
        _detailTextLabel.text = viewModel.country
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        _imageView.setImage(url: nil)
    }

}
