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

            guard list.count > 0 else {
                var inset = strongSelf.tableView.contentInset.top
                if #available(iOS 11.0, *) {
                    inset = strongSelf.tableView.adjustedContentInset.top
                }
                strongSelf.tableView.setContentOffset(CGPoint(x: 0, y: -inset), animated: false)
                print("tableView.reloadData()")
                strongSelf.tableView.reloadData()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    strongSelf.tableView.setContentOffset(CGPoint(x: 0, y: -inset), animated: true)
                }
                return
            }

            strongSelf.tableView.beginUpdates()
            for update in list {
                switch update {
                case .insert(let indexPath):
                    strongSelf.tableView.insertRows(at: [indexPath], with: .automatic)
                case .update(let indexPath):
                    strongSelf.tableView.reloadRows(at: [indexPath], with: .automatic)
                case .delete(let indexPath):
                    strongSelf.tableView.deleteRows(at: [indexPath], with: .automatic)
                case .move(let atIndexPath, let toIndexPath):
                    strongSelf.tableView.deleteRows(at: [atIndexPath], with: .automatic)
                    strongSelf.tableView.insertRows(at: [toIndexPath], with: .automatic)
//                    strongSelf.tableView.moveRow(at: atIndexPath, to: toIndexPath)
                }
            }
            print("tableView.endUpdates()")
            strongSelf.tableView.endUpdates()

        }
        tableView.reloadData()
    }

    private var pagingScopedDisposable: ScopedDisposable?
    private func bindPaging(_ paging: Paging) {
        let list = CompositeDisposable()
        pagingScopedDisposable = ScopedDisposable(list)

        let pool = paging.pool
        list += paging.willDisplayCell.observeValues { [unowned self] (indexPath) in

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
