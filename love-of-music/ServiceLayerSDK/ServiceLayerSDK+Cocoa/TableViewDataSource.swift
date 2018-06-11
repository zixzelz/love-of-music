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

    private var tableView: UITableView
    private var listViewModel: ListViewModel<CellViewModel>
    private var cellMap: CellMap

    init(tableView: UITableView, listViewModel: ListViewModel<CellViewModel>, map: @escaping CellMap) {

        self.tableView = tableView
        self.listViewModel = listViewModel
        self.cellMap = map
    }

    //MARK: UITableViewDataSource

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return listViewModel.numberOfItems
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cellVM = listViewModel.cellViewModel(at: indexPath)
        return cellMap(tableView, indexPath, cellVM)
    }

}
