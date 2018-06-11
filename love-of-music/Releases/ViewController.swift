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

    @IBOutlet var tableView: UITableView!
    private var contentDataSource: TableViewDataSource<ReleasesCellViewModel>? {
        didSet {
            tableView.dataSource = contentDataSource
        }
    }

    private var viewModel: ViewControllerViewModeling! {
        didSet {
            if isViewLoaded {
                bind(with: viewModel)
            }
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        viewModel = ViewControllerViewModel()
//        bind(with: viewModel)
    }

    private func bind(with viewModel: ViewControllerViewModeling) {
        contentDataSource = TableViewDataSource(tableView: tableView, listViewModel: viewModel.listViewModel, map: { (tableView, indexpath, cellVM) -> UITableViewCell in
            let cell = tableView.dequeueReusableCell(withIdentifier: "DefaultCell", for: indexpath) as! DefaultTableViewCell
            cell.configure(viewModel: cellVM)

            return cell
        })
    }

}
