//
//  TableViewDataSource.swift
//  love-of-music
//
//  Created by Ruslan Maslouski on 6/12/18.
//  Copyright © 2018 Ruslan Maslouski. All rights reserved.
//

import UIKit
import ReactiveSwift
import Result

public class TableViewDataSource <CellViewModel>: NSObject, UITableViewDataSource {

    public typealias CellMap = (_ tableView: UITableView, _ indexPath: IndexPath, _ cellVM: CellViewModel) -> UITableViewCell
    public typealias Paging = (pool: Int, willDisplayCell: Signal<IndexPath, NoError>)
    public typealias EmptyView = () -> UIView

    private var tableView: UITableView
    private var listViewModel: ListViewModel<CellViewModel>
    private var cellMap: CellMap
    private var emptyView: EmptyView?

    public init(
        tableView: UITableView,
        listViewModel: ListViewModel<CellViewModel>,
        paging: Paging? = nil,
        emptyView: EmptyView? = nil,
        map: @escaping CellMap) {

        self.tableView = tableView
        self.listViewModel = listViewModel
        self.cellMap = map
        self.emptyView = emptyView

        super.init()
        bind(listViewModel)

        if let paging = paging {
            bindPaging(paging)
        }
    }

    private var scopedDisposable: ScopedDisposable<AnyDisposable>?
    private func bind(_ listViewModel: ListViewModel<CellViewModel>) {
        let list = CompositeDisposable()
        scopedDisposable = ScopedDisposable(list)

        list += listViewModel.didUpdate.observeValues { [weak self] list in
            guard let strongSelf = self else {
                return
            }

            guard list.count > 0 else {
                var inset = strongSelf.tableView.contentInset.top// + 1
                if #available(iOS 11.0, *) {
                    inset = strongSelf.tableView.adjustedContentInset.top// + 1
                }
                print("tableView.reloadData() \(inset)")
                print("will ContentOffset \(strongSelf.tableView.contentOffset)")

                // Scroll to top
                strongSelf.tableView.dataSource = nil
                strongSelf.tableView.reloadData()
                strongSelf.tableView.dataSource = self
                strongSelf.tableView.reloadData()
                strongSelf.tableView.layoutIfNeeded()
                strongSelf.tableView.setContentOffset(CGPoint(x: 0, y: -inset), animated: false)
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

        list += listViewModel.state.producer.startWithValues { [weak self] state in
            guard let strongSelf = self else {
                return
            }
            switch state {
            case .none, .loading:
                strongSelf.tableView.backgroundView = nil
            case .loaded:
                if strongSelf.listViewModel.numberOfSections() > 0 && strongSelf.listViewModel.numberOfRows(inSection: 0) > 0 {
                    strongSelf.tableView.backgroundView = nil
                } else {
                    strongSelf.tableView.backgroundView = strongSelf.emptyView?()
                }
            }
        }

        tableView.reloadData()
    }

    private var pagingScopedDisposable: ScopedDisposable<AnyDisposable>?
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
        return listViewModel.numberOfRows(inSection: 0)
    }

    //MARK: UITableViewDataSource

    public func numberOfSections(in tableView: UITableView) -> Int {
        return listViewModel.numberOfSections()
    }

    public func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return listViewModel.numberOfRows(inSection: section)
    }

    public func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cellVM = listViewModel.cellViewModel(at: indexPath)
        return cellMap(tableView, indexPath, cellVM)
    }

    public func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        return listViewModel.section(at: section)
    }
}
