//
//  CoreDataHelper.swift
//  grsu.schedule
//
//  Created by Ruslan Maslouski on 6/5/18.
//  Copyright © 2018 Ruslan Maslouski. All rights reserved.
//

import CoreData
import UIKit

class CoreDataHelper: NSObject {

    private let store: CoreDataStore

    private static let sharedInstance = CoreDataHelper()

    override init() {

        store = CoreDataStore()

        super.init()

        NotificationCenter.default.addObserver(self, selector: #selector(CoreDataHelper.contextDidSaveContext(_:)), name: NSNotification.Name.NSManagedObjectContextDidSave, object: nil)
    }

    private func setup() {
        managedObjectContext.saveIfNeeded()
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    static var managedObjectContext: NSManagedObjectContext {
        return sharedInstance.managedObjectContext
    }

    static var backgroundContext: NSManagedObjectContext {
        return sharedInstance.backgroundContext
    }

    class func saveBackgroundContext() {
        saveContext(sharedInstance.backgroundContext)
    }

    class func saveContext(_ context: NSManagedObjectContext) {
        context.saveIfNeeded()
    }

    class func convertToMainQueue(_ itemIds: [NSManagedObjectID]) -> [AnyObject] {
        return sharedInstance.convertToMainQueue(itemIds)
    }

    // #pragma mark - Core Data stack

    lazy var managedObjectContext: NSManagedObjectContext = {

        let coordinator = store.persistentStoreCoordinator

        var managedObjectContext = NSManagedObjectContext(concurrencyType: NSManagedObjectContextConcurrencyType.mainQueueConcurrencyType)
        managedObjectContext.persistentStoreCoordinator = coordinator

        return managedObjectContext
    }()

    lazy var backgroundContext: NSManagedObjectContext = {

        let coordinator = store.persistentStoreCoordinator

        var backgroundContext = NSManagedObjectContext(concurrencyType: NSManagedObjectContextConcurrencyType.privateQueueConcurrencyType)
        backgroundContext.persistentStoreCoordinator = coordinator

        return backgroundContext
    }()

    // save NSManagedObjectContext
    
    func saveContext(_ context: NSManagedObjectContext) {

        context.saveIfNeeded()
    }

    func saveBackgroundContext() {
        saveContext(backgroundContext)
    }

    func convertToMainQueue(_ itemIds: [NSManagedObjectID]) -> [AnyObject] {
        let mainContext = managedObjectContext

        var items = [AnyObject]()
        for objId in itemIds {

            let obj = mainContext.object(with: objId)
            items.append(obj)
        }
        return items
    }

    // call back function by saveContext, support multi-thread
    @objc func contextDidSaveContext(_ notification: Foundation.Notification) {
        let sender = notification.object as! NSManagedObjectContext
        if sender === managedObjectContext {
            backgroundContext.perform {
                self.backgroundContext.mergeChanges(fromContextDidSave: notification)
            }
        } else if sender === backgroundContext {
            managedObjectContext.perform {
                self.managedObjectContext.mergeChanges(fromContextDidSave: notification)
            }
        }
    }
}

extension NSManagedObjectContext {

    public func saveIfNeeded() {

        do {
            if hasChanges {
                try save()
            }
        } catch {

            print("Unresolved error \(error)")
            abort()
        }
    }
}
