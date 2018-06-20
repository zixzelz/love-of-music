//
//  ViewController.swift
//  love-of-music
//
//  Created by Ruslan Maslouski on 6/5/18.
//  Copyright © 2018 Ruslan Maslouski. All rights reserved.
//

import UIKit

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

    private var _willDisplayCell: MutableProperty<IndexPath> = MutableProperty(value: IndexPath(row: 0, section: 0)) // make as optional, add ignoreNill with ReactiveCocoa

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

        let willDisplayCell = Property(_willDisplayCell)

        contentDataSource = TableViewDataSource(tableView: tableView, listViewModel: viewModel.listViewModel,
            paging: (Constants.pagingPool, willDisplayCell),
            map: { (tableView, indexpath, cellVM) -> UITableViewCell in
                let cell = tableView.dequeueReusableCell(withIdentifier: "DefaultCell", for: indexpath) as! DefaultTableViewCell
                cell.configure(viewModel: cellVM)

                return cell
            })
    }

}

extension ViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, willDisplay cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        _willDisplayCell.value = indexPath
    }
}
