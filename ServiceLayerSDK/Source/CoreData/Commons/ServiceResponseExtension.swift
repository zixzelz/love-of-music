//
//  ServiceResponseExtension.swift
//  ServiceLayerSDK
//
//  Created by Ruslan Maslouski on 24/12/2018.
//

import ReactiveSwift
import CoreData

extension ServiceResponse where T: NSManagedObject {

    public func items(in context: NSManagedObjectContext) -> SignalProducer<[T], ServiceError> {

        return items.flatMap(.latest, { items -> SignalProducer<[T], ServiceError> in
            return SignalProducer { observer, lifeTime in
                context.perform {
                    guard !lifeTime.hasEnded else {
                        return
                    }

                    let newItems = items.compactMap { $0.existingObject(in: context) }
                    observer.send(value: newItems)
                    observer.sendCompleted()
                }
            }
        })

    }

}
