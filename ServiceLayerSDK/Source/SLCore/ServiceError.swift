//
//  ServiceError.swift
//  grsu.schedule
//
//  Created by Ruslan Maslouski on 9/9/16.
//  Copyright © 2016 Ruslan Maslouski. All rights reserved.
//

import Foundation

public enum ServiceError: Error {
    case networkError(error: Error)
    case wrongResponseFormat
    case internalError
}
