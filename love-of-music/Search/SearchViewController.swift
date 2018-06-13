//
//  SearchViewController.swift
//  love-of-music
//
//  Created by Ruslan Maslouski on 6/13/18.
//  Copyright © 2018 Ruslan Maslouski. All rights reserved.
//

import UIKit

class SearchViewController: UITableViewController {

    lazy var searchController: UISearchController = {
        return UISearchController(searchResultsController: resultsTableViewController)
    }()

    lazy var resultsTableViewController: ResultSearchTableViewController = {
        let vm = ResultSearchTableViewModel()
        let vc = ResultSearchTableViewController(viewModel: vm)
        vc.paretViewController = self
        return vc
    }()

    override func viewDidLoad() {
        super.viewDidLoad()

        setupSearchController()

        navigationItem.title = "Discogs"
        tableView.tableFooterView = UIView()
    }

    private func setupSearchController() {

        searchController.searchResultsUpdater = resultsTableViewController
        searchController.searchBar.placeholder = "Search artists"

        //        if #available(iOS 9.1, *) {
        //            searchController.obscuresBackgroundDuringPresentation = false
        //        }

        if #available(iOS 11.0, *) {
            navigationController?.navigationBar.prefersLargeTitles = true
            navigationItem.searchController = searchController
            navigationItem.hidesSearchBarWhenScrolling = false
        } else {
            tableView.tableHeaderView = searchController.searchBar
        }

        definesPresentationContext = true

        // Fix bug with a magic line between navigationBar and searchBar 🤬
        if #available(iOS 11.0, *) {
            navigationController?.navigationBar.subviews.first?.clipsToBounds = true
        }
    }

}
