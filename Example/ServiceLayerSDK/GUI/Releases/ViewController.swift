//
//  ViewController.swift
//  love-of-music
//
//  Created by Ruslan Maslouski on 6/5/18.
//  Copyright © 2018 Ruslan Maslouski. All rights reserved.
//

import UIKit
import ReactiveSwift
import Result
import ServiceLayerSDK

protocol ViewControllerViewModeling {

    var listViewModel: ListViewModel<ReleasesCellViewModel> { get }
}

class ViewController: UIViewController {

    private struct Constants {
        static let pagingPool = 2
    }

    @IBOutlet var tableView: UITableView!
    private var contentDataSource: TableViewDataSource<ReleasesCellViewModel>? {
        didSet {
            tableView.dataSource = contentDataSource
        }
    }

    fileprivate let (willDisplayCellSignal, willDisplayCellObserver) = Signal<IndexPath, NoError>.pipe()

    private var viewModel: ViewControllerViewModeling! {
        didSet {
            if isViewLoaded {
                bind(with: viewModel)
            }
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        tableView.delegate = self
        viewModel = ViewControllerViewModel()
//        bind(with: viewModel)
    }

    private func bind(with viewModel: ViewControllerViewModeling) {

        contentDataSource = TableViewDataSource(tableView: tableView, listViewModel: viewModel.listViewModel,
            paging: (Constants.pagingPool, willDisplayCellSignal),
            map: { (tableView, indexpath, cellVM) -> UITableViewCell in
                let cell = tableView.dequeueReusableCell(withIdentifier: "DefaultCell", for: indexpath) as! DefaultTableViewCell
                cell.configure(viewModel: cellVM)

                return cell
            })
    }

}

extension ViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, willDisplay cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        willDisplayCellObserver.send(value: indexPath)
    }
}
