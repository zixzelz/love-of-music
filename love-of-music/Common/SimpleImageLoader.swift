//
//  ImageLoader.swift
//  love-of-music
//
//  Created by Ruslan Maslouski on 6/20/18.
//  Copyright © 2018 Ruslan Maslouski. All rights reserved.
//

import Foundation
import UIKit

class SimpleImageLoader {

    private static let imageCaсhe = NSCache<NSString, UIImage>()

    static func loadImage(urlString: String, completion: @escaping (UIImage?) -> ()) {

        guard let url = URL(string: urlString) else {
            completion(nil)
            return
        }
        if let imageFromCache = imageFromCache(for: urlString) {
            completion(imageFromCache)
            return
        }
        if let imageFromDocument = getImageFromDocumentDirectory(key: urlString) {
            saveImageToCaсhe(image: imageFromDocument, for: urlString)
            completion(imageFromDocument)
            return
        }

        getData(url: url) { data in

            guard let data = data else {
                DispatchQueue.main.async {
                    completion(nil)
                }
                return
            }

            guard let image = UIImage(data: data) else {
                DispatchQueue.main.async {
                    completion(nil)
                }
                return
            }

            DispatchQueue.main.async {
                completion(image)
            }

            saveImageToCaсhe(image: image, for: urlString)
            saveImageToDocumentDirectory(image: image, for: urlString)
        }
    }

    static private func getData(url: URL, completion: @escaping (Data?) -> ()) {
        let session = URLSession.shared

        session.dataTask(with: url) { (data, response, error) in

            guard let data = data else {
                completion(nil)
                return
            }
            completion(data)

        }.resume()
    }

    static private func saveImageToCaсhe(image: UIImage, for url: String) {
        imageCaсhe.setObject(image, forKey: url as NSString)
    }

    static private func imageFromCache(for url: String) -> UIImage? {
        guard let image = imageCaсhe.object(forKey: url as NSString) else {
            return nil
        }
        return image
    }

    static private func saveImageToDocumentDirectory(image: UIImage, for key: String) {

        DispatchQueue.global().async {
            guard let paths = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else { return }
            guard let data = UIImagePNGRepresentation(image) else { return }
            let modifyKey = key.replacingOccurrences(of: "/", with: "")
            let fileName = paths.appendingPathComponent("image:\(modifyKey)")

            do {
                try data.write(to: fileName)
            } catch {
                print("Error write image to document directory: \(error)")
            }
        }

    }

    static private func getImageFromDocumentDirectory(key: String) -> UIImage? {

        guard let paths = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else { return nil }
        let fileManager = FileManager.default

        let modifyKey = key.replacingOccurrences(of: "/", with: "")
        let fileName = paths.appendingPathComponent("image:\(modifyKey)")

        if fileManager.fileExists(atPath: fileName.path) {
            return UIImage(contentsOfFile: fileName.path)
        }
        return nil

    }

    static func cleanAllCach() {
        imageCaсhe.removeAllObjects()
    }

}
