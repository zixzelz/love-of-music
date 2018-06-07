//
//  ReleasesEntity.swift
//  love-of-music
//
//  Created by Ruslan Maslouski on 6/5/18.
//  Copyright © 2018 Ruslan Maslouski. All rights reserved.
//

import Foundation
import CoreData

@objc(ReleasesEntity)
class ReleasesEntity: NSManagedObject {

    @NSManaged var title: String?
    @NSManaged var userId: String
}
