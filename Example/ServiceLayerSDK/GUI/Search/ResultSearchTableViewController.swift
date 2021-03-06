//
//  ResultSearchTableViewController.swift
//  love-of-music
//
//  Created by Ruslan Maslouski on 6/13/18.
//  Copyright © 2018 Ruslan Maslouski. All rights reserved.
//

import UIKit
import ReactiveSwift
import Result
import ServiceLayerSDK

protocol GeneralResultSearchTableViewModeling {
    func search(with text: String?)
    func viewModel(at indexPath: IndexPath) -> AlbumDetailViewModeling
}

protocol ResultSearchTableViewModeling: GeneralResultSearchTableViewModeling {
    var listViewModel: ListViewModel<ResultSearchCellViewModel> { get }
    func search(with text: String?)

    func viewModel(at indexPath: IndexPath) -> AlbumDetailViewModeling
}

protocol AlternativeResultSearchTableViewModeling: GeneralResultSearchTableViewModeling {
    var listViewModel: Property<ListViewModel<ResultSearchCellViewModel>> { get }
    func search(with text: String?)

    func viewModel(at indexPath: IndexPath) -> AlbumDetailViewModeling
}

class ResultSearchTableViewController: UITableViewController {

    private struct Constants {
        static let pagingPool = 2
    }

    weak var paretViewController: UIViewController?

    private(set) var viewModel: ResultSearchTableViewModeling? {
        didSet {
            if isViewLoaded {
                if let viewModel = viewModel {
                    bind(with: viewModel)
                }
            }
        }
    }

    private(set) var alternativeViewModel: AlternativeResultSearchTableViewModeling? {
        didSet {
            if isViewLoaded {
                if let alternativeViewModel = alternativeViewModel {
                    bind(with: alternativeViewModel)
                }
            }
        }
    }

    private var generalViewModel: GeneralResultSearchTableViewModeling? {
        return viewModel ?? alternativeViewModel
    }

    fileprivate let (willDisplayCellSignal, willDisplayCellObserver) = Signal<IndexPath, NoError>.pipe()
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

    init(viewModel: AlternativeResultSearchTableViewModeling) {
        self.alternativeViewModel = viewModel
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

        if let viewModel = viewModel {
            bind(with: viewModel)
        } else if let alternativeViewModel = alternativeViewModel {
            bind(with: alternativeViewModel)
        }
    }

    private var scopedDisposable: ScopedDisposable<AnyDisposable>?
    private func bind(with viewModel: ResultSearchTableViewModeling) {
        let list = CompositeDisposable()
        scopedDisposable = ScopedDisposable(list)

        contentDataSource = TableViewDataSource(tableView: tableView, listViewModel: viewModel.listViewModel,
            paging: (Constants.pagingPool, willDisplayCellSignal),
            map: { (tableView, indexpath, cellVM) -> UITableViewCell in
                let cell: ResultSearchTableViewCell = tableView.dequeueCell(for: indexpath)
                cell.configure(viewModel: cellVM)
                return cell
            })

        list += viewModel.listViewModel.state.producer.startWithValues { [weak self] state in
            switch state {
            case .loading:
                self?.loadingTableFooterView.spinner.startAnimating()
            case .loaded, .none:
                self?.loadingTableFooterView.spinner.stopAnimating()
            }
        }
    }

    private func bind(with viewModel: AlternativeResultSearchTableViewModeling) {
        let list = CompositeDisposable()
        scopedDisposable = ScopedDisposable(list)

        list += viewModel.listViewModel.producer.startWithValues { [unowned self] listViewModel in

            self.contentDataSource = TableViewDataSource(tableView: self.tableView, listViewModel: listViewModel,
                paging: (Constants.pagingPool, self.willDisplayCellSignal),
                map: { (tableView, indexpath, cellVM) -> UITableViewCell in
                    let cell: ResultSearchTableViewCell = tableView.dequeueCell(for: indexpath)
                    cell.configure(viewModel: cellVM)
                    return cell
                }
            )
        }

//        contentDataSource = TableViewDataSource(tableView: tableView, listViewModel: viewModel.listViewModel,
//            paging: (Constants.pagingPool, willDisplayCellSignal),
//            map: { (tableView, indexpath, cellVM) -> UITableViewCell in
//                let cell: ResultSearchTableViewCell = tableView.dequeueCell(for: indexpath)
//                cell.configure(viewModel: cellVM)
//                return cell
//            })

        list += viewModel.listViewModel.flatMap(.latest) {
            return $0.state
        }.producer.startWithValues { [weak self] state in
            switch state {
            case .loading:
                self?.loadingTableFooterView.spinner.startAnimating()
            case .loaded, .none:
                self?.loadingTableFooterView.spinner.stopAnimating()
            }
        }
    }

    private func filterContentForSearchText(_ searchText: String?) {
        generalViewModel?.search(with: searchText)
    }

    //MARK: - UITableViewDelegate

    override func scrollViewDidScroll(_ scrollView: UIScrollView) {
        print("scrollViewDidScroll \(scrollView.contentOffset)")
    }
    
    override func tableView(_ tableView: UITableView, willDisplay cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        willDisplayCellObserver.send(value: indexPath)
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let c = UIStoryboard(name: "Main", bundle: nil)

        if let vc = c.instantiateViewController(withIdentifier: "AlbumDetailViewControllerIdentifier") as? AlbumDetailViewController, let vm = generalViewModel?.viewModel(at: indexPath) {

            vc.viewModel = vm

            paretViewController?.navigationController?.pushViewController(vc, animated: true)
        }

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
