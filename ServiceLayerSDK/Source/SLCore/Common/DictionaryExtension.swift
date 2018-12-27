//
//  NSDictionaryExtension.swift
//  love-of-music
//
//  Created by Ruslan Maslouski on 7/20/18.
//  Copyright © 2018 Ruslan Maslouski. All rights reserved.
//

import Foundation

public extension NSDictionary {
    func doubleValue(for key: String) -> Double {
        return double(for: key) ?? 0
    }
    func double(for key: String) -> Double? {
        return self[key] as? Double
    }
    func intValue(for key: String) -> Int {
        return int(for: key) ?? 0
    }
    func int(for key: String) -> Int? {
        return self[key] as? Int
    }
    func boolValue(for key: String) -> Bool {
        return bool(for: key) ?? false
    }
    func bool(for key: String) -> Bool? {
        return self[key] as? Bool
    }
    func stringValue(for key: String) -> String {
        return string(for: key) ?? ""
    }
    func string(for key: String) -> String? {
        return self[key] as? String
    }
    func dict(for key: String) -> NSDictionary? {
        return self[key] as? NSDictionary
    }
    func dictArr(for key: String) -> [NSDictionary]? {
        return self[key] as? [NSDictionary]
    }
    func arrValue<T>(for key: String) -> [T] {
        return arr(for: key) ?? []
    }
    func arr<T>(for key: String) -> [T]? {
        return self[key] as? [T]
    }
    func date(for key: String) -> Date? {
        return self[key] as? Date
    }
}

public extension Dictionary where Value == AnyObject {
    func intValue(for key: Key) -> Int {
        return int(for: key) ?? 0
    }
    func int(for key: Key) -> Int? {
        return self[key] as? Int
    }
    func stringValue(for key: Key) -> String {
        return string(for: key) ?? ""
    }
    func string(for key: Key) -> String? {
        return self[key] as? String
    }
    func dictValue(for key: Key) -> NSDictionary {
        return dict(for: key) ?? NSDictionary()
    }
    func dict(for key: Key) -> NSDictionary? {
        return self[key] as? NSDictionary
    }
    func dictArr(for key: Key) -> [NSDictionary]? {
        return self[key] as? [NSDictionary]
    }
    func arrValue<T>(for key: Key) -> [T] {
        return arr(for: key) ?? []
    }
    func arr<T>(for key: Key) -> [T]? {
        return self[key] as? [T]
    }
}
