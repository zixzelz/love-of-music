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

    private var viewModel: ResultSearchTableViewModeling {
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

    private lazy var loadingTableFooterView: LoadingTableFooterView = {
        return LoadingTableFooterView()
    }()

    init(viewModel: ResultSearchTableViewModeling) {
        self.viewModel = viewModel
        super.init(style: UITableViewStyle.plain)
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        tableView.keyboardDismissMode = .onDrag
        tableView.registerNib(ResultSearchTableViewCell.self)
        tableView.tableFooterView = loadingTableFooterView

        bind(with: viewModel)
    }

    private var scopedDisposable: ScopedDisposable?
    private func bind(with viewModel: ResultSearchTableViewModeling) {
        let list = CompositeDisposable()
        scopedDisposable = ScopedDisposable(list)

        let willDisplayCell = Property(_willDisplayCell)

        contentDataSource = TableViewDataSource(tableView: tableView, listViewModel: viewModel.listViewModel,
            paging: (Constants.pagingPool, willDisplayCell),
            map: { (tableView, indexpath, cellVM) -> UITableViewCell in
                let cell: ResultSearchTableViewCell = tableView.dequeueCell(for: indexpath)
                cell.configure(viewModel: cellVM)
//                cell.backgroundColor = UIColor.red
                print("cell for row \(indexpath) \(cellVM.title)")
                return cell
            })

        list += viewModel.listViewModel.state.observeValues { [weak self] (state) in
            switch state {
            case .loading:
                self?.loadingTableFooterView.spinner.startAnimating()
            case .loaded, .none:
                self?.loadingTableFooterView.spinner.stopAnimating()
            }
        }
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

class LoadingTableFooterView: UIView {

    let spinner = UIActivityIndicatorView(activityIndicatorStyle: .whiteLarge)

    init() {
        super.init(frame: spinner.bounds.insetBy(dx: 0, dy: -20))
        spinner.autoresizingMask = [.flexibleLeftMargin, .flexibleRightMargin, .flexibleTopMargin, .flexibleBottomMargin]
        spinner.color = UIColor.black

        addSubview(spinner)
        spinner.center = CGPoint(x: bounds.midX, y: bounds.midY)
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

}
