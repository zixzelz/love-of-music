//
//  UITableView.swift
//  love-of-music
//
//  Created by Ruslan Maslouski on 6/13/18.
//  Copyright © 2018 Ruslan Maslouski. All rights reserved.
//

import UIKit

extension UITableView {

    public func dequeueCell < Cell: UITableViewCell> (for indexPath: IndexPath) -> Cell where Cell: CellIdentifier {
        guard let cell = dequeueReusableCell(withIdentifier: Cell.identifier, for: indexPath) as? Cell else {
            fatalError("Could not dequeue cell with identifier: \(Cell.identifier)")
        }

        return cell
    }

    public func dequeueHeaderFooter < Cell: UITableViewHeaderFooterView> () -> Cell where Cell: CellIdentifier {
        guard let cell = dequeueReusableHeaderFooterView(withIdentifier: Cell.identifier) as? Cell else {
            fatalError("Could not dequeue cell with identifier: \(Cell.identifier)")
        }

        return cell
    }

    public func register< Cell: UITableViewCell > (_: Cell.Type) where Cell: CellIdentifier {
        register(Cell.self, forCellReuseIdentifier: Cell.identifier)
    }

    public func register< Cell: UITableViewHeaderFooterView > (_: Cell.Type) where Cell: CellIdentifier {
        register(Cell.self, forHeaderFooterViewReuseIdentifier: Cell.identifier)
    }

    public func registerNib < Cell: UITableViewCell > (_ aClass: Cell.Type) where Cell: CellIdentifier {
        let nibName = NSStringFromClass(aClass).components(separatedBy: ".").last!
        register(UINib(nibName: nibName, bundle: nil), forCellReuseIdentifier: Cell.identifier)
    }

}

public protocol CellIdentifier {
    static var identifier: String { get }
}

extension CellIdentifier {
    public static var identifier: String {
        return "\(Self.self)"
    }
}
