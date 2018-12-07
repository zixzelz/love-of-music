//
//  AlbumDetailViewModel.swift
//  love-of-music
//
//  Created by Ruslan Maslouski on 6/18/18.
//  Copyright © 2018 Ruslan Maslouski. All rights reserved.
//

import UIKit

class AlbumDetailViewModel: AlbumDetailViewModeling {

    private var item: AlbumEntity

    init(item: AlbumEntity) {
        self.item = item
    }

    var ganre: String? {
        return item.genre
    }

    var style: String? {
        return item.style
    }

    var year: String? {
        return item.year
    }
    
    var title: String? {
        return item.title
    }

    var imageUrl: String? {
        return item.thumb
    }

}
