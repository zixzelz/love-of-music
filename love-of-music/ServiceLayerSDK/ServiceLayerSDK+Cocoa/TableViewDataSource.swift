//
//  TableViewDataSource.swift
//  love-of-music
//
//  Created by Ruslan Maslouski on 6/12/18.
//  Copyright © 2018 Ruslan Maslouski. All rights reserved.
//

import UIKit

class TableViewDataSource <CellViewModel>: NSObject, UITableViewDataSource {

    typealias CellMap = (_ tableView: UITableView, _ indexPath: IndexPath, _ cellVM: CellViewModel) -> UITableViewCell
    typealias Paging = (pool: Int, willDisplayCell: Property<IndexPath>)

    private var tableView: UITableView
    private var listViewModel: ListViewModel<CellViewModel>
    private var cellMap: CellMap

    init(
        tableView: UITableView,
        listViewModel: ListViewModel<CellViewModel>,
        paging: Paging? = nil,
        map: @escaping CellMap) {

        self.tableView = tableView
        self.listViewModel = listViewModel
        self.cellMap = map

        super.init()
        bind(listViewModel)

        if let paging = paging {
            bindPaging(paging)
        }
    }

    private var scopedDisposable: ScopedDisposable?
    private func bind(_ listViewModel: ListViewModel<CellViewModel>) {
        let list = CompositeDisposable()
        scopedDisposable = ScopedDisposable(list)

        list += listViewModel.didUpdate.observeValues { [weak self] list in
            guard let strongSelf = self else {
                return
            }

            let ff = strongSelf.tableView.numberOfRows(inSection: 0)
            print("listViewModel.didUpdate list: \(list); numberOfRows \(ff); totalCount: \(strongSelf.totalCount)")

            guard list.count > 0 else {
                strongSelf.tableView.reloadData()
                return
            }

            var itemsToInsert: [IndexPath] = []
            var itemsToUpdate: [IndexPath] = []
            var itemsToDelete: [IndexPath] = []

            strongSelf.tableView.beginUpdates()
            for update in list {
                switch update {
                case .insert(let indexPath):
                    itemsToInsert.append(indexPath)
                case .update(let indexPath):
                    itemsToUpdate.append(indexPath)
                case .delete(let indexPath):
                    itemsToDelete.append(indexPath)
                case .move(let atIndexPath, let toIndexPath):
                    strongSelf.tableView.moveRow(at: atIndexPath, to: toIndexPath)
                }
            }
            strongSelf.tableView.insertRows(at: itemsToInsert, with: .automatic)
            strongSelf.tableView.reloadRows(at: itemsToUpdate, with: .automatic)
            strongSelf.tableView.deleteRows(at: itemsToDelete, with: .automatic)
            strongSelf.tableView.endUpdates()

        }
        tableView.reloadData()
    }

    private func bindPaging(_ paging: Paging) {

        let pool = paging.pool
        paging.willDisplayCell.observeValues { [unowned self] (indexPath) in

            if indexPath.row + pool > self.totalCount {
                print("Set need load new page")
                DispatchQueue.main.async {
                    self.listViewModel.loadNextPageIfNeeded()
                }
            }
        }
    }

    private var totalCount: Int {
        return listViewModel.numberOfItems
    }

    //MARK: UITableViewDataSource

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return totalCount
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cellVM = listViewModel.cellViewModel(at: indexPath)
        return cellMap(tableView, indexPath, cellVM)
    }

}
