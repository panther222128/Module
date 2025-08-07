//
//  NetworkService.swift
//  Modules
//
//  Created by Horus on 8/7/25.
//

import Foundation

public enum NetworkError: Error {
    case error(statusCode: Int, data: Data?)
    case notConnected
    case cancelled
    case generic(Error)
    case urlGeneration
    case noResponse
    case sessionCreationFailed
    case refreshTokenExpired
    case noStatusCode
    case tokenSaveFailed
}

protocol NetworkCancellable {
    func cancel()
}

extension URLSessionTask: NetworkCancellable { }

public protocol NetworkService {
    func request(endpoint: some Requestable) async throws -> Data
}

public final class DefaultNetworkService: NetworkService {

    private let configuration: NetworkConfigurable
    private let networkSessionManager: NetworkSessionManager

    public init(configuration: NetworkConfigurable) {
        self.configuration = configuration
        self.networkSessionManager = DefaultNetworkSessionManager()
    }

    public func request(endpoint: some Requestable) async throws -> Data {
        do {
            let urlRequest = try endpoint.urlRequest(with: configuration)
            let result = try await networkSessionManager.request(urlRequest)
            guard let httpResponse = result.1 as? HTTPURLResponse else { throw NetworkError.noResponse }
            let statusCode = httpResponse.statusCode
            if (200..<300).contains(statusCode) {
                return result.0
            } else {
                throw NetworkError.error(statusCode: httpResponse.statusCode, data: result.0)
            }
        } catch let urlError as URLError {
            throw urlError
        } catch let error {
            throw error
        }
    }

}

protocol NetworkSessionManager {
    func request(_ request: URLRequest) async throws -> (Data, URLResponse)
}

final class DefaultNetworkSessionManager: NetworkSessionManager {

    init() {

    }
    
    func request(_ request: URLRequest) async throws -> (Data, URLResponse) {
        return try await URLSession.shared.data(for: request)
    }

}

