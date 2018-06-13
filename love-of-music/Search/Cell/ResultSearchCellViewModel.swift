//
//  SearchCellViewModel.swift
//  love-of-music
//
//  Created by Ruslan Maslouski on 6/13/18.
//  Copyright © 2018 Ruslan Maslouski. All rights reserved.
//

import Foundation

class SearchCellViewModel {

    var title: String?

    init(release: AlbumEntity) {
        title = release.title
    }

}
