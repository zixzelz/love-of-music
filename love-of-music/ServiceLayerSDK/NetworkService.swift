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
    var parameters: [String: Any]? { get }
    var range: NSRange? { get } //Default nil

    static var cacheTimeInterval: TimeInterval { get }
}

// Default Value
extension NetworkServiceQueryType {
    var range: NSRange? {
        return nil
    }
}

protocol PageModelType {
    associatedtype ObjectType: ModelType
    var object: ObjectType { get }
}

class NetworkService<T: ModelType> {

    typealias NetworkServiceFetchItemCompletionHandlet = (ServiceResult<T, ServiceError>) -> ()
    typealias NetworkServiceFetchCompletionHandlet = (ServiceResult<[T], ServiceError>) -> ()
    typealias NetworkServiceStoreCompletionHandlet = (ServiceResult<Void, ServiceError>) -> ()

    fileprivate let localService: LocalService<T>

    init (localService: LocalService<T>) {

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

    func fetchData < NetworkServiceQuery: NetworkServiceQueryType> (_ query: NetworkServiceQuery, cache: CachePolicy, completionHandler: @escaping NetworkServiceFetchCompletionHandlet) where NetworkServiceQuery.QueryInfo == T.QueryInfo {

        switch cache {
        case .cachedOnly:

            localService.featch(query, completionHandler: completionHandler)

        case .CachedThenLoad:

            localService.featch(query) { result in
                completionHandler(result)
            }
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

        case .cachedElseLoad:

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

    }

    func fetchData < NetworkServiceQuery: NetworkServiceQueryType, PageModel: PageModelType> (_ query: NetworkServiceQuery, cache: CachePolicy, completionHandler: @escaping NetworkServiceFetchCompletionHandlet) where NetworkServiceQuery.QueryInfo == T.QueryInfo {



    }

    @discardableResult private func resumeRequest < NetworkServiceQuery: NetworkServiceQueryType> (_ query: NetworkServiceQuery, completionHandler: @escaping NetworkServiceStoreCompletionHandlet) -> URLSessionDataTask? where NetworkServiceQuery.QueryInfo == T.QueryInfo {

        let session = urlSession()

        guard var components = URLComponents(string: query.path) else {
            DispatchQueue.main.async {
                completionHandler(.failure(.internalError))
            }
            return nil
        }
        components.query = query.queryString
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
            self.saveDate(query)
            self.parseAndStore(query, responseDict: responseDict, completionHandler: completionHandler)
        }

        task.resume()
        return task
    }

    fileprivate func parseAndStore < NetworkServiceQuery: NetworkServiceQueryType> (_ query: NetworkServiceQuery, responseDict: [String: AnyObject], completionHandler: @escaping NetworkServiceStoreCompletionHandlet) where NetworkServiceQuery.QueryInfo == T.QueryInfo {

        localService.parseAndStore(query, json: responseDict, completionHandler: completionHandler)
    }

    // MARK - Utils

    fileprivate func saveDate < NetworkServiceQuery: NetworkServiceQueryType> (_ query: NetworkServiceQuery) where NetworkServiceQuery.QueryInfo == T.QueryInfo {

        let cacheIdentifier = query.cacheIdentifier

        DispatchQueue.main.async {
            let userDefaults = UserDefaults.standard
            userDefaults.set(Date(), forKey: cacheIdentifier)

            var arr = userDefaults.stringArray(forKey: "NetworkServiceExpiredFlags") ?? []
            arr.append(cacheIdentifier)
            userDefaults.set(arr, forKey: "NetworkServiceExpiredFlags")
        }
    }

    fileprivate func isCacheExpired < NetworkServiceQuery: NetworkServiceQueryType> (_ query: NetworkServiceQuery) -> Bool where NetworkServiceQuery.QueryInfo == T.QueryInfo {

        let cacheIdentifier = query.cacheIdentifier
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

func cleanCacheExpiredFlags() {
    let userDefaults = UserDefaults.standard
    let arr = userDefaults.stringArray(forKey: "NetworkServiceExpiredFlags") ?? []
    userDefaults.removeObject(forKey: "NetworkServiceExpiredFlags")

    for cacheIdentifier in arr {
        userDefaults.removeObject(forKey: cacheIdentifier)
    }
}

private extension NetworkServiceQueryType {

    var cacheIdentifier: String {

        var key = String(describing: type(of: self))
        if let str = queryString {
            key.append(str)
        }
        return key
    }

    var queryString: String? {

        var params = parameters
        if let range = range {
            params?["per_page"] = Int(range.length)
            params?["page"] = Int(range.location / range.length) + 1
        }
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

