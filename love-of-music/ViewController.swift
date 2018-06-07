//
//  ViewController.swift
//  love-of-music
//
//  Created by Ruslan Maslouski on 6/5/18.
//  Copyright © 2018 Ruslan Maslouski. All rights reserved.
//

import UIKit
import CoreData

class ViewController: UIViewController {

    let pageSize = 6

    @IBOutlet var tableView: UITableView!

    var releasesService: ReleasesService!
    var fetchResult: FetchResult<ReleasesEntity, ReleasesPageEntity, ReleasesQuery>!

    override func viewDidLoad() {
        super.viewDidLoad()

        releasesService = ReleasesService()
        let networkService = releasesService.networkService

        fetchResult = FetchResult(networkService: networkService, cachePolicy: .CachedThenLoad, pageSize: pageSize)

        let query = ReleasesQuery()
        fetchResult.performFetch(query: query)
    }

}

extension ViewController: UITableViewDataSource {

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return 5
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "DefaultCell", for: indexPath)
        cell.textLabel?.text = ""
        cell.detailTextLabel?.text = ""

        return cell
    }

}
