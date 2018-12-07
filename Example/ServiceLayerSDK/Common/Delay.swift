//
//  Delay.swift
//  HelpBook
//
//  Created by Ruslan Maslouski on 5/16/15.
//

import Foundation

public typealias dispatch_cancelable_closure = (_ cancel: Bool) -> Void

public func delay(_ time: TimeInterval, closure: @escaping () -> Void) -> dispatch_cancelable_closure? {

    func dispatch_later(_ clsr: @escaping () -> Void) {
        DispatchQueue.main.asyncAfter(
            deadline: DispatchTime.now() + Double(Int64(time * Double(NSEC_PER_SEC))) / Double(NSEC_PER_SEC), execute: clsr)
    }

    var closure: (() -> Void)? = closure
    var cancelableClosure: dispatch_cancelable_closure?

    let delayedClosure: dispatch_cancelable_closure = { cancel in
        if let closure = closure {
            if (cancel == false) {
                DispatchQueue.main.async(execute: closure)
            }
        }
        closure = nil
        cancelableClosure = nil
    }

    cancelableClosure = delayedClosure

    dispatch_later {
        if let delayedClosure = cancelableClosure {
            delayedClosure(false)
        }
    }

    return cancelableClosure
}

public func cancel_delay(_ closure: dispatch_cancelable_closure?) {

    if let closure = closure {
        closure(true)
    }
}
