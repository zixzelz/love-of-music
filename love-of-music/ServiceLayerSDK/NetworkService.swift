//
//  NetworkService.swift
//  grsu.schedule
//
//  Created by Ruslan Maslouski on 9/5/16.
//  Copyright © 2016 Ruslan Maslouski. All rights reserved.
//

import Foundation

public enum NetworkServiceMethod: String {
    case GET = "GET"
}

enum ServiceResult<T, Err: Error> {

    case success(T)
    case failure(Err)
}

protocol NetworkServiceQueryType: LocalServiceQueryType {

    var path: String { get }
    var method: NetworkServiceMethod { get }
    func parameters(range: NSRange?) -> [String: Any]?

    static var cacheTimeInterval: TimeInterval { get }
}

class NetworkService<T: ModelType, U: PageModelType> {

    typealias NetworkServiceFetchItemCompletionHandlet = (ServiceResult<T, ServiceError>) -> ()
    typealias NetworkServiceFetchCompletionHandlet = (ServiceResult<[T], ServiceError>) -> ()
    typealias NetworkServiceStoreCompletionHandlet = (ServiceResult<Void, ServiceError>) -> ()

    fileprivate let localService: LocalService<T, U>

    init (localService: LocalService<T, U>) {

        self.localService = localService
    }

    func fetchDataItem < NetworkServiceQuery: NetworkServiceQueryType> (_ query: NetworkServiceQuery, cache: CachePolicy, completionHandler: @escaping NetworkServiceFetchItemCompletionHandlet) where NetworkServiceQuery.QueryInfo == T.QueryInfo {

        fetchData(query, cache: cache) { (result) in

            switch result {
            case .success(let items):
                guard let item = items.first else {
                    completionHandler(.failure(.wrongResponseFormat))
                    return
                }
                completionHandler(.success(item))
            case .failure(let error):
                DispatchQueue.main.async {
                    completionHandler(.failure(error))
                }
            }
        }
    }

    func fetchData < NetworkServiceQuery: NetworkServiceQueryType> (_ query: NetworkServiceQuery, cache: CachePolicy, range: NSRange? = nil, completionHandler: @escaping NetworkServiceFetchCompletionHandlet) where NetworkServiceQuery.QueryInfo == T.QueryInfo {

        switch cache {
        case .cachedOnly:

            localService.featch(query, completionHandler: completionHandler)

        case .CachedThenLoad: // page

            if range == nil || range?.location == 0 {
                let fetchLimit = range.flatMap { $0.location == 0 ? $0.length: nil }
                localService.featch(query, fetchLimit: fetchLimit) { result in
                    completionHandler(result)
                }
            }

            resumeRequest(query, range: range) { result in

                switch result {
                case .success:
                    self.localService.featch(query, completionHandler: completionHandler)
                case .failure(let error):
                    DispatchQueue.main.async {
                        completionHandler(.failure(error))
                    }
                }

            }

        case .cachedElseLoad: // add expire date to enum

            if isCacheExpired(query) {
                resumeRequest(query) { result in

                    switch result {
                    case .success:
                        self.localService.featch(query, completionHandler: completionHandler)
                    case .failure(let error):
                        DispatchQueue.main.async {
                            completionHandler(.failure(error))
                        }
                    }

                }
            } else {
                localService.featch(query, completionHandler: completionHandler)
            }

        case .reloadIgnoringCache:

            resumeRequest(query) { result in

                switch result {
                case .success:
                    self.localService.featch(query, completionHandler: completionHandler)
                case .failure(let error):
                    DispatchQueue.main.async {
                        completionHandler(.failure(error))
                    }
                }
            }
        }

    }

    @discardableResult private func resumeRequest < NetworkServiceQuery: NetworkServiceQueryType> (_ query: NetworkServiceQuery, range: NSRange? = nil, completionHandler: @escaping NetworkServiceStoreCompletionHandlet) -> URLSessionDataTask? where NetworkServiceQuery.QueryInfo == T.QueryInfo {

        let session = urlSession()

        guard var components = URLComponents(string: query.path) else {
            DispatchQueue.main.async {
                completionHandler(.failure(.internalError))
            }
            return nil
        }
        components.query = query.queryString(range: range)
        guard let url = components.url else {
            DispatchQueue.main.async {
                completionHandler(.failure(.internalError))
            }
            return nil
        }
        let request = URLRequest(url: url)

        let task = session.dataTask(with: request) { (data: Data?, response: URLResponse?, error: Error?) in

            if let error = error {

                NSLog("[Error] response error: \(error)")
                DispatchQueue.main.async {
                    completionHandler(.failure(.networkError(error: error)))
                }
                return
            }

            let json = try? JSONSerialization.jsonObject(with: data!, options: .mutableContainers)
            let responseDict = json as? [String: AnyObject] ?? [String: AnyObject]()

            #if DEBUG
                if let response = NSString(data: data!, encoding: String.Encoding.utf8.rawValue) {
                    print("response: \(response)")
                }
            #endif
            self.saveDate(query, range: range)
            self.parseAndStore(query, responseDict: responseDict, completionHandler: completionHandler)
        }

        task.resume()
        return task
    }

    fileprivate func parseAndStore < NetworkServiceQuery: NetworkServiceQueryType> (_ query: NetworkServiceQuery, responseDict: [String: AnyObject], completionHandler: @escaping NetworkServiceStoreCompletionHandlet) where NetworkServiceQuery.QueryInfo == T.QueryInfo {

        localService.parseAndStore(query, json: responseDict, completionHandler: completionHandler)
    }

    // MARK - Utils

    fileprivate func saveDate < NetworkServiceQuery: NetworkServiceQueryType> (_ query: NetworkServiceQuery, range: NSRange?) where NetworkServiceQuery.QueryInfo == T.QueryInfo {

        let cacheIdentifier = query.cacheIdentifier(range: range)

        DispatchQueue.main.async {
            let userDefaults = UserDefaults.standard
            userDefaults.set(Date(), forKey: cacheIdentifier)

            var arr = userDefaults.stringArray(forKey: "NetworkServiceExpiredFlags") ?? []
            arr.append(cacheIdentifier)
            userDefaults.set(arr, forKey: "NetworkServiceExpiredFlags")
        }
    }

    fileprivate func isCacheExpired < NetworkServiceQuery: NetworkServiceQueryType> (_ query: NetworkServiceQuery, range: NSRange? = nil) -> Bool where NetworkServiceQuery.QueryInfo == T.QueryInfo {

        let cacheIdentifier = query.cacheIdentifier(range: range)
        let userDefaults = UserDefaults.standard

        guard let date = userDefaults.object(forKey: cacheIdentifier) as? Date else { return true }
        let expiryDate = date.addingTimeInterval(type(of: query).cacheTimeInterval)

        return expiryDate < Date()
    }

    fileprivate func urlSession() -> URLSession {
        let queue = OperationQueue()
        queue.name = "com.network.servicelayer.queue"

        let sessionConfig = URLSessionConfiguration.default
        sessionConfig.timeoutIntervalForRequest = 30

        return URLSession(configuration: sessionConfig)
    }

}

//class PageNetworkService<T: ModelType, PageModel: PageModelType>: NetworkService<T> {
//
//    func fetchPageData < NetworkServiceQuery: NetworkServiceQueryType> (_ query: NetworkServiceQuery, cache: CachePolicy, page: NSRange, completionHandler: @escaping NetworkServiceFetchCompletionHandlet) where NetworkServiceQuery.QueryInfo == T.QueryInfo {
//
//    }
//}

func cleanCacheExpiredFlags() {
    let userDefaults = UserDefaults.standard
    let arr = userDefaults.stringArray(forKey: "NetworkServiceExpiredFlags") ?? []
    userDefaults.removeObject(forKey: "NetworkServiceExpiredFlags")

    for cacheIdentifier in arr {
        userDefaults.removeObject(forKey: cacheIdentifier)
    }
}

private extension NetworkServiceQueryType {

    func cacheIdentifier(range: NSRange?) -> String {

        var key = String(describing: type(of: self))
        if let str = queryString(range: range) {
            key.append(str)
        }
        return key
    }

    func queryString(range: NSRange?) -> String? {
        let params = parameters(range: range)
        return params?.stringFromHttpParameters()
    }

}

private extension String {

    func stringByAddingPercentEncodingForURLQueryValue() -> String? {
        let allowedCharacters = CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-._~")

        return addingPercentEncoding(withAllowedCharacters: allowedCharacters)
    }

}

private extension Dictionary {

    func stringFromHttpParameters() -> String {
        let parameterArray = self.map { (key, value) -> String in
            let percentEscapedKey = (key as! String).stringByAddingPercentEncodingForURLQueryValue()!
            let percentEscapedValue = (value as! String).stringByAddingPercentEncodingForURLQueryValue()!
            return "\(percentEscapedKey)=\(percentEscapedValue)"
        }

        return parameterArray.joined(separator: "&")
    }

}

