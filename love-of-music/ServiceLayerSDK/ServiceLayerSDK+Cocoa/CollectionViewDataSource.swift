//
//  ColectionViewDataSource.swift
//  love-of-music
//
//  Created by Ruslan Maslouski on 6/10/18.
//  Copyright © 2018 Ruslan Maslouski. All rights reserved.
//

import UIKit

class CollectionViewDataSource <CellViewModel>: NSObject, UICollectionViewDataSource {

    typealias CellMap = (_ collectionView: UICollectionView, _ indexPath: IndexPath, _ cellVM: CellViewModel) -> UICollectionViewCell

    private var collectionView: UICollectionView
    private var listViewModel: ListViewModel<CellViewModel>
    private var cellMap: CellMap

    init(collectionView: UICollectionView, listViewModel: ListViewModel<CellViewModel>, map: @escaping CellMap) {

        self.collectionView = collectionView
        self.listViewModel = listViewModel
        self.cellMap = map
    }

    //MARK: UICollectionViewDataSource

    func numberOfSections(in collectionView: UICollectionView) -> Int {
        return listViewModel.numberOfSections()
    }

    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return listViewModel.numberOfRows(inSection: section)
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cellVM = listViewModel.cellViewModel(at: indexPath)
        return cellMap(collectionView, indexPath, cellVM)
    }

}
