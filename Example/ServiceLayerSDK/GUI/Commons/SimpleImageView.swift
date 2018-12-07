//
//  SimpleImageView.swift
//  love-of-music
//
//  Created by Ruslan Maslouski on 6/20/18.
//  Copyright © 2018 Ruslan Maslouski. All rights reserved.
//

import UIKit

class SimpleImageView: UIImageView {

    private var setImageTask: Task?

    func setImage(url: String?, placeholder: UIImage? = nil) {

        image = placeholder

        guard let url = url else {
            setImageTask = nil
            return
        }

        let task = Task({ [weak self] image in
            self?.image = image ?? placeholder
        })
        setImageTask = task

        SimpleImageLoader.loadImage(urlString: url) { [weak self, weak task] (image) in
            if let task = task {
                task.task(image)
                self?.setImageTask = nil
            }
        }
    }

}

private class Task {
    private(set) var task: ((_ image: UIImage?) -> Void)

    init(_ task: @escaping ((_ image: UIImage?) -> Void)) {
        self.task = task
    }
}
