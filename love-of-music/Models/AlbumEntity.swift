//
//  AlbumEntity.swift
//  love-of-music
//
//  Created by Ruslan Maslouski on 6/13/18.
//  Copyright © 2018 Ruslan Maslouski. All rights reserved.
//

import Foundation
import CoreData

@objc(AlbumEntity)
class AlbumEntity: NSManagedObject {

    @NSManaged var albumId: String
    @NSManaged var title: String?
    @NSManaged var thumb: String?
    @NSManaged var country: String?
    @NSManaged var year: String?
    @NSManaged var genre: String?
    @NSManaged var type: String?
}
