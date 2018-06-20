//
//  ReleasesCellViewModel.swift
//  love-of-music
//
//  Created by Ruslan Maslouski on 6/12/18.
//  Copyright © 2018 Ruslan Maslouski. All rights reserved.
//

import UIKit

class ReleasesCellViewModel {

    var title: String?

    init(release: ReleasesEntity) {
        title = release.title
    }

}
