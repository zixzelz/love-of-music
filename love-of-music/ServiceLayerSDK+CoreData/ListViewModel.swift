//
//  ListViewModel.swift
//  love-of-music
//
//  Created by Ruslan Maslouski on 6/8/18.
//  Copyright © 2018 Ruslan Maslouski. All rights reserved.
//

import UIKit
import CoreData

class ListViewModel<ObjectType, PageObjectType: PageModelType & NSFetchRequestResult, NetworkServiceQuery: NetworkServiceQueryType, CellViewModel> where ObjectType == PageObjectType.ObjectType, NetworkServiceQuery.QueryInfo == ObjectType.QueryInfo {

    typealias CellViewModelClosure = (_ item: PageObjectType, _ indexPath: NSIndexPath) -> CellViewModel

    private let fetchResult: FetchResult<ObjectType, PageObjectType, NetworkServiceQuery>
    private let cellViewModelClosure: CellViewModelClosure

    init(fetchResult: FetchResult<ObjectType, PageObjectType, NetworkServiceQuery>, cellViewModel: @escaping CellViewModelClosure) {
        self.fetchResult = fetchResult
        self.cellViewModelClosure = cellViewModel
    }

    func cellViewModel(at indexPath: NSIndexPath) -> CellViewModel {
        return cellViewModelClosure(indexPath)
    }

}
