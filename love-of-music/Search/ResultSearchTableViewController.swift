//
//  ResultSearchTableViewController.swift
//  love-of-music
//
//  Created by Ruslan Maslouski on 6/13/18.
//  Copyright © 2018 Ruslan Maslouski. All rights reserved.
//

import UIKit

protocol ResultSearchTableViewModeling {
    var listViewModel: ListViewModel<ResultSearchCellViewModel> { get }
    func search(with text: String?)
}

class ResultSearchTableViewController: UITableViewController {

    private struct Constants {
        static let pagingPool = 2
    }

    weak var paretViewController: UIViewController?

    var viewModel: ResultSearchTableViewModeling {
        didSet {
            if isViewLoaded {
                bind(with: viewModel)
            }
        }
    }

    private var _willDisplayCell: MutableProperty<IndexPath> = MutableProperty(value: IndexPath(row: 0, section: 0)) // make as optional
    private var contentDataSource: TableViewDataSource<ResultSearchCellViewModel>? {
        didSet {
            tableView.dataSource = contentDataSource
        }
    }

    init(viewModel: ResultSearchTableViewModeling) {
        self.viewModel = viewModel
        super.init(style: UITableViewStyle.plain)
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        tableView.registerNib(ResultSearchTableViewCell.self)//registerNib(ResultSearchTableViewCell.self)
        tableView.tableFooterView = UIView()

        bind(with: viewModel)
    }

    private func bind(with viewModel: ResultSearchTableViewModeling) {

        let willDisplayCell = Property(_willDisplayCell)

        contentDataSource = TableViewDataSource(tableView: tableView, listViewModel: viewModel.listViewModel,
            paging: (Constants.pagingPool, willDisplayCell),
            map: { (tableView, indexpath, cellVM) -> UITableViewCell in
                let cell: ResultSearchTableViewCell = tableView.dequeueCell(for: indexpath)
                cell.configure(viewModel: cellVM)
                return cell
            })
    }

    private func filterContentForSearchText(_ searchText: String?) {
        viewModel.search(with: searchText)
    }

    //MARK: - UITableViewDelegate

    override func tableView(_ tableView: UITableView, willDisplay cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        _willDisplayCell.value = indexPath
    }
}

extension ResultSearchTableViewController: UISearchResultsUpdating {

    func updateSearchResults(for searchController: UISearchController) {
        let searchBar = searchController.searchBar
        filterContentForSearchText(searchBar.text)
    }
}
