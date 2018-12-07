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

public struct PageInfo {
    let totalCount: Int
}

public struct ServiceResponse<T> {
    public let pageInfo: PageInfo?
    private let itemsBlock: () -> [T]

    public var items: [T] {
        return itemsBlock()
    }

    init(pageInfo: PageInfo?, itemsBlock: @escaping () -> [T]) {
        self.pageInfo = pageInfo
        self.itemsBlock = itemsBlock
    }
}

public enum ServiceResult<T, Err: Error> {
    case success(T)
    case failure(Err)
}

public protocol NetworkServiceQueryType: LocalServiceQueryType {

    var path: String { get }
    var method: NetworkServiceMethod { get }
    func parameters(range: NSRange?) -> [String: String]?

    static var cacheTimeInterval: TimeInterval { get }
}

public extension NetworkServiceQueryType {
    public var filterIdentifier: String {
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

public class NetworkService<ObjectType: ModelType> {

    typealias NetworkServiceFetchItemCompletionHandlet = (ServiceResult<ObjectType, ServiceError>) -> ()
    typealias FetchItemsCompletionHandler = (ServiceResult<[ObjectType], ServiceError>) -> ()
    typealias FetchPageCompletionHandler = (ServiceResult<LocalServiceFetchInfo, ServiceError>) -> ()
    typealias FetchCompletionHandler = (ServiceResult<LocalServiceFetchInfo, ServiceError>) -> ()
    private typealias StoreCompletionHandlet = (ServiceResult<LocalServiceFetchInfo, ServiceError>) -> ()

    private let localService: LocalService<ObjectType>

    public init (localService: LocalService<ObjectType>) {
        self.localService = localService
    }

//    func fetchDataItem <NetworkServiceQuery: NetworkServiceQueryType> (_ query: NetworkServiceQuery, cache: CachePolicy, completionHandler: @escaping NetworkServiceFetchItemCompletionHandlet) where NetworkServiceQuery.QueryInfo == ObjectType.QueryInfo {
//
//        fetchDataItems(query, cache: cache) { (result) in
//
//            switch result {
//            case .success(let items):
//                guard let item = items.first else {
//                    completionHandler(.failure(.wrongResponseFormat))
//                    return
//                }
//                completionHandler(.success(item))
//            case .failure(let error):
//                completionHandler(.failure(error))
//            }
//
//        }
//    }

//    func fetchDataItems < NetworkServiceQuery: NetworkServiceQueryType> (_ query: NetworkServiceQuery, cache: CachePolicy, range: NSRange? = nil, completionHandler: @escaping FetchItemsCompletionHandler) where NetworkServiceQuery.QueryInfo == ObjectType.QueryInfo {
//
//        let fetchCompletion: FetchCompletionHandler = { [weak self] (result) in
//            switch result {
//            case .success:
//                self?.localService.featchItems(query, completionHandler: completionHandler)
//            case .failure(let error):
//                completionHandler(.failure(error))
//            }
//        }
//
//        switch cache {
//        case .cachedOnly:
//            localService.featchItems(query, completionHandler: completionHandler)
//        case .cachedThenLoad: // page
//
//            if range == nil || range?.location == 0 {
//                let fetchLimit = range.flatMap { $0.location == 0 ? $0.length: nil }
//                localService.featchItems(query, fetchLimit: fetchLimit, completionHandler: completionHandler)
//            }
//            fetchData(query, cache: cache, range: range, completionHandler: fetchCompletion)
//
//        case .cachedElseLoad:
//
//            if isCacheExpired(query) {
//                fetchData(query, cache: cache, range: range, completionHandler: fetchCompletion)
//            } else {
//                localService.featchItems(query, completionHandler: completionHandler)
//            }
//
//        case .reloadIgnoringCache:
//            fetchData(query, cache: cache, range: range, completionHandler: fetchCompletion)
//        }
//    }

    func loadData < NetworkServiceQuery: NetworkServiceQueryType> (_ query: NetworkServiceQuery, range: NSRange? = nil, completionHandler: @escaping FetchPageCompletionHandler) -> SignalProducer<LocalServiceFetchInfo, ServiceError> where NetworkServiceQuery.QueryInfo == ObjectType.QueryInfo {
        return fetchData(query, cache: .reloadIgnoringCache, range: range)
    }

    public func loadNewData < NetworkServiceQuery: NetworkServiceQueryType> (_ query: NetworkServiceQuery, cache: CachePolicy, range: NSRange? = nil) -> SignalProducer<ServiceResponse<ObjectType>, ServiceError> where NetworkServiceQuery.QueryInfo == ObjectType.QueryInfo {

        return fetchData(query, cache: .reloadIgnoringCache, range: range)
            .map { info -> ServiceResponse<ObjectType> in
                let pageInfo = PageInfo(totalCount: info.totalItems)
                return ServiceResponse<ObjectType>(pageInfo: pageInfo, itemsBlock: {
                    return []
                })
        }
    }

    private func fetchData < NetworkServiceQuery: NetworkServiceQueryType> (_ query: NetworkServiceQuery, cache: CachePolicy, range: NSRange? = nil) -> SignalProducer<LocalServiceFetchInfo, ServiceError> where NetworkServiceQuery.QueryInfo == ObjectType.QueryInfo {

        switch cache {
        case .cachedOnly:
            return SignalProducer.empty
        case .cachedThenLoad, .cachedElseLoad, .reloadIgnoringCache:
            return resumeRequest(query, range: range)
        }
    }

    @discardableResult private func resumeRequest < NetworkServiceQuery: NetworkServiceQueryType> (_ query: NetworkServiceQuery, range: NSRange? = nil) -> SignalProducer<LocalServiceFetchInfo, ServiceError> where NetworkServiceQuery.QueryInfo == ObjectType.QueryInfo {

        let session = urlSession()

        return SignalProducer<NSDictionary, ServiceError> { (observer, lifetime) in

            guard var components = URLComponents(string: query.path) else {
                DispatchQueue.main.async {
                    observer.send(error: .internalError)
                }
                return
            }

            components.query = query.queryString(range: range)
            guard let url = components.url else {
                DispatchQueue.main.async {
                    observer.send(error: .internalError)
                }
                return
            }

            let request = URLRequest(url: url)

            let task = session.dataTask(with: request) { (data: Data?, response: URLResponse?, error: Error?) in

                guard !lifetime.hasEnded else {
                    return
                }

                if let error = error {
                    NSLog("[Error] response error: \(error)")
                    DispatchQueue.main.async {
                        observer.send(error: .networkError(error: error))
                    }
                    return
                }

                guard let data = data,
                    let jsonObj = try? JSONSerialization.jsonObject(with: data, options: .mutableContainers),
                    let responseDict = jsonObj as? NSDictionary else {
                        observer.send(error: .wrongResponseFormat)
                        return
                }

                #if DEBUG
                    //                if let response = NSString(data: data!, encoding: String.Encoding.utf8.rawValue) {
                    //                    print("response: \(response)")
                    //                }
                #endif

                observer.send(value: responseDict)
                observer.sendCompleted()
            }
            task.resume()
        }.flatMap(.latest) { responseDict -> SignalProducer<LocalServiceFetchInfo, ServiceError> in
            return self.parseAndStore(query, responseDict: responseDict, range: range)
        }.on(value: { [weak self] _ in
            self?.saveDate(query, range: range)
        })
    }

    private func parseAndStore < NetworkServiceQuery: NetworkServiceQueryType> (_ query: NetworkServiceQuery, responseDict: NSDictionary, range: NSRange?) -> SignalProducer<LocalServiceFetchInfo, ServiceError> where NetworkServiceQuery.QueryInfo == ObjectType.QueryInfo {
        return localService.parseAndStore(query, json: responseDict, range: range)
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
