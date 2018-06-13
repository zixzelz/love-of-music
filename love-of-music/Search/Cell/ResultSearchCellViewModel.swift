//
//  SearchCellViewModel.swift
//  love-of-music
//
//  Created by Ruslan Maslouski on 6/13/18.
//  Copyright © 2018 Ruslan Maslouski. All rights reserved.
//

import Foundation

class ResultSearchCellViewModel {

    private let release: AlbumEntity

    var title: String? {
        return release.title
    }
    var country: String? {
        return release.country
    }

    init(release: AlbumEntity) {
        self.release = release
    }

}
