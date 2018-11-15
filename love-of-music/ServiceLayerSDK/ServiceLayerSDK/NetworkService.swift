//
//  NetworkService.swift
//  grsu.schedule
//
//  Created by Ruslan Maslouski on 9/5/16.
//  Copyright © 2016 Ruslan Maslouski. All rights reserved.
//

import Foundation
import ReactiveSwift

public enum NetworkServiceMethod: String {
    case GET = "GET"
}

struct PageInfo {
    let totalCount: Int
}

struct ServiceResponse<T> {
    let pageInfo: PageInfo?
    private let itemsBlock: () -> [T]

    var items: [T] {
        return itemsBlock()
    }

    init(pageInfo: PageInfo?, itemsBlock: @escaping () -> [T]) {
        self.pageInfo = pageInfo
        self.itemsBlock = itemsBlock
    }
}

enum ServiceResult<T, Err: Error> {
    case success(T)
    case failure(Err)
}

protocol NetworkServiceQueryType: LocalServiceQueryType {

    var path: String { get }
    var method: NetworkServiceMethod { get }
    func parameters(range: NSRange?) -> [String: String]?

    static var cacheTimeInterval: TimeInterval { get }
}

extension NetworkServiceQueryType {
    var filterIdentifier: String {
        return path + (queryString(range: nil) ?? "")
    }
}

//class NetworkService {
//
//    class func networkService<ObjectType: ModelType>(localService: LocalService<ObjectType, Void>) -> NetworkService {
//        return MainNetworkService()
//    }
//
//}

class NetworkService<ObjectType: ModelType> {

    typealias NetworkServiceFetchItemCompletionHandlet = (ServiceResult<ObjectType, ServiceError>) -> ()
    typealias FetchItemsCompletionHandler = (ServiceResult<[ObjectType], ServiceError>) -> ()
    typealias FetchPageCompletionHandler = (ServiceResult<LocalServiceFetchInfo, ServiceError>) -> ()
    typealias FetchCompletionHandler = (ServiceResult<LocalServiceFetchInfo, ServiceError>) -> ()
    private typealias StoreCompletionHandlet = (ServiceResult<LocalServiceFetchInfo, ServiceError>) -> ()

    private let localService: LocalService<ObjectType>

    init (localService: LocalService<ObjectType>) {
        self.localService = localService
    }

    func fetchDataItem <NetworkServiceQuery: NetworkServiceQueryType> (_ query: NetworkServiceQuery, cache: CachePolicy, completionHandler: @escaping NetworkServiceFetchItemCompletionHandlet) where NetworkServiceQuery.QueryInfo == ObjectType.QueryInfo {

        fetchDataItems(query, cache: cache) { (result) in

            switch result {
            case .success(let items):
                guard let item = items.first else {
                    completionHandler(.failure(.wrongResponseFormat))
                    return
                }
                completionHandler(.success(item))
            case .failure(let error):
                completionHandler(.failure(error))
            }

        }
    }

    func fetchDataItems < NetworkServiceQuery: NetworkServiceQueryType> (_ query: NetworkServiceQuery, cache: CachePolicy, range: NSRange? = nil, completionHandler: @escaping FetchItemsCompletionHandler) where NetworkServiceQuery.QueryInfo == ObjectType.QueryInfo {

        let fetchCompletion: FetchCompletionHandler = { [weak self] (result) in
            switch result {
            case .success:
                self?.localService.featchItems(query, completionHandler: completionHandler)
            case .failure(let error):
                completionHandler(.failure(error))
            }
        }

        switch cache {
        case .cachedOnly:
            localService.featchItems(query, completionHandler: completionHandler)
        case .cachedThenLoad: // page

            if range == nil || range?.location == 0 {
                let fetchLimit = range.flatMap { $0.location == 0 ? $0.length: nil }
                localService.featchItems(query, fetchLimit: fetchLimit, completionHandler: completionHandler)
            }
            fetchData(query, cache: cache, range: range, completionHandler: fetchCompletion)

        case .cachedElseLoad:

            if isCacheExpired(query) {
                fetchData(query, cache: cache, range: range, completionHandler: fetchCompletion)
            } else {
                localService.featchItems(query, completionHandler: completionHandler)
            }

        case .reloadIgnoringCache:
            fetchData(query, cache: cache, range: range, completionHandler: fetchCompletion)
        }
    }

    func loadData < NetworkServiceQuery: NetworkServiceQueryType> (_ query: NetworkServiceQuery, range: NSRange? = nil, completionHandler: @escaping FetchPageCompletionHandler) where NetworkServiceQuery.QueryInfo == ObjectType.QueryInfo {
        fetchData(query, cache: .reloadIgnoringCache, range: range, completionHandler: completionHandler)
    }

    func loadNewData < NetworkServiceQuery: NetworkServiceQueryType> (_ query: NetworkServiceQuery, cache: CachePolicy, range: NSRange? = nil) -> SignalProducer<ServiceResponse<ObjectType>, ServiceError> where NetworkServiceQuery.QueryInfo == ObjectType.QueryInfo {
        return SignalProducer<ServiceResponse<ObjectType>, ServiceError> { (observer, lifetime) in
            self.fetchData(query, cache: .reloadIgnoringCache, range: range) { result in

                guard !lifetime.hasEnded else {
                    return
                }

                switch result {
                case .success(let value):
                    let pageInfo = PageInfo(totalCount: value.totalItems)
                    let response = ServiceResponse<ObjectType>(pageInfo: pageInfo, itemsBlock: {
                        return []
                    })
                    observer.send(value: response)
                case .failure(let error):
                    observer.send(error: error)
                }
            }
        }
    }

    private func fetchData < NetworkServiceQuery: NetworkServiceQueryType> (_ query: NetworkServiceQuery, cache: CachePolicy, range: NSRange? = nil, completionHandler: @escaping FetchCompletionHandler) where NetworkServiceQuery.QueryInfo == ObjectType.QueryInfo {

        switch cache {
        case .cachedOnly: break
        case .cachedThenLoad, .cachedElseLoad, .reloadIgnoringCache:

            resumeRequest(query, range: range) { result in
                guard case .failure(let error) = result else {
                    completionHandler(result)
                    return
                }
                DispatchQueue.main.async {
                    completionHandler(.failure(error))
                }
            }

        }
    }

    @discardableResult private func resumeRequest < NetworkServiceQuery: NetworkServiceQueryType> (_ query: NetworkServiceQuery, range: NSRange? = nil, completionHandler: @escaping StoreCompletionHandlet) -> URLSessionDataTask? where NetworkServiceQuery.QueryInfo == ObjectType.QueryInfo {

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

            guard let data = data,
                let jsonObj = try? JSONSerialization.jsonObject(with: data, options: .mutableContainers),
                let responseDict = jsonObj as? NSDictionary else {
                    completionHandler(.failure(.wrongResponseFormat))
                    return
            }

            #if DEBUG
//                if let response = NSString(data: data!, encoding: String.Encoding.utf8.rawValue) {
//                    print("response: \(response)")
//                }
            #endif
            self.parseAndStore(query, responseDict: responseDict, range: range) { [weak self] (result) in
                self?.saveDate(query, range: range)
                completionHandler(result)
            }
        }

        task.resume()
        return task
    }

    private func parseAndStore < NetworkServiceQuery: NetworkServiceQueryType> (_ query: NetworkServiceQuery, responseDict: NSDictionary, range: NSRange?, completionHandler: @escaping StoreCompletionHandlet) where NetworkServiceQuery.QueryInfo == ObjectType.QueryInfo {

        localService.parseAndStore(query, json: responseDict, range: range, completionHandler: completionHandler)
    }

    // MARK - Utils

    private func saveDate < NetworkServiceQuery: NetworkServiceQueryType> (_ query: NetworkServiceQuery, range: NSRange?) where NetworkServiceQuery.QueryInfo == ObjectType.QueryInfo {

        let cacheIdentifier = query.cacheIdentifier(range: range)

        DispatchQueue.main.async {
            let userDefaults = UserDefaults.standard
            userDefaults.set(Date(), forKey: cacheIdentifier)

            var arr = userDefaults.stringArray(forKey: "NetworkServiceExpiredFlags") ?? []
            arr.append(cacheIdentifier)
            userDefaults.set(arr, forKey: "NetworkServiceExpiredFlags")
        }
    }

    private func isCacheExpired < NetworkServiceQuery: NetworkServiceQueryType> (_ query: NetworkServiceQuery, range: NSRange? = nil) -> Bool where NetworkServiceQuery.QueryInfo == ObjectType.QueryInfo {

        let cacheIdentifier = query.cacheIdentifier(range: range)
        let userDefaults = UserDefaults.standard

        guard let date = userDefaults.object(forKey: cacheIdentifier) as? Date else { return true }
        let expiryDate = date.addingTimeInterval(type(of: query).cacheTimeInterval)

        return expiryDate < Date()
    }

    private func urlSession() -> URLSession {
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

private extension Dictionary where Key == String, Value == String {

    func stringFromHttpParameters() -> String {
        let parameterArray = self.map { (key, value) -> String in
            let percentEscapedKey = key.stringByAddingPercentEncodingForURLQueryValue()!
            let percentEscapedValue = value.stringByAddingPercentEncodingForURLQueryValue()!
            return "\(percentEscapedKey)=\(percentEscapedValue)"
        }

        return parameterArray.joined(separator: "&")
    }

}

extension SignalProducer {

//    func voidResponse() -> SignalProducer<ServiceResponse<Void>, Error> {
//        return self.map { _ -> ServiceResponse<Void> in
//            return Response(response: nil, error: nil, fromCache: false)
//        }
//    }

//    func legacyMapToNoErrorResponse() -> SignalProducer<Response<Value, NoError>, NoError> {
//        return self.map { _ -> Response<Value, NoError> in
//            return Response(response: nil, error: nil, fromCache: false)
//            }.flatMapError { error in
//                return SignalProducer<Response<Value, NoError>, NoError>(value: Response(response: nil, error: nil, fromCache: false))
//        }
//    }
}
