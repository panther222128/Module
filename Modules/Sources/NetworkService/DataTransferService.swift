//
//  DataTransferService.swift
//  Modules
//
//  Created by Horus on 8/7/25.
//

import Foundation

public enum DataTransferError: Error {
    case noResponse
    case parsing(Error)
    case networkFailure(NetworkError)
    case resolvedNetworkFailure(Error)
    case decode
}

protocol DataTransferDispatchQueue {
    func asyncExecute(work: @Sendable @escaping () -> Void)
}

extension DispatchQueue: DataTransferDispatchQueue {
    func asyncExecute(work: @Sendable @escaping () -> Void) {
        async(group: nil, execute: work)
    }
}

public protocol DataTransferService {
    typealias CompletionHandler<T> = (Result<T, DataTransferError>) -> Void
    
    func request<T: Decodable, E: ResponseRequestable>(with endpoint: E) async throws -> T where E.Response == T
}

public protocol DataTransferErrorResolver {
    func resolve(error: NetworkError) -> Error
}

public protocol ResponseDecoder {
    func decode<T: Decodable>(_ data: Data) throws -> T
}

public protocol DataTransferErrorLogger {
    func log(error: Error)
}

public final class DefaultDataTransferService {

    public let networkService: NetworkService
    public let errorResolver: DataTransferErrorResolver
    public let errorLogger: DataTransferErrorLogger

    public init(
        with networkService: NetworkService,
        errorResolver: DataTransferErrorResolver = DefaultDataTransferErrorResolver(),
        errorLogger: DataTransferErrorLogger = DefaultDataTransferErrorLogger()
    ) {
        self.networkService = networkService
        self.errorResolver = errorResolver
        self.errorLogger = errorLogger
    }
}

extension DefaultDataTransferService: DataTransferService {

    public func request<T: Decodable, E: ResponseRequestable>(with endpoint: E) async throws -> T where E.Response == T {
        do {
            let data = try await networkService.request(endpoint: endpoint)
            let decoded: T = try await decode(data: data, decoder: endpoint.responseDecoder)
            return decoded
        } catch let error {
            throw error
        }
    }

    // MARK: - Private
    private func decode<T: Decodable>(data: Data?, decoder: ResponseDecoder) async throws -> T {
        do {
            guard let data = data else { throw DataTransferError.noResponse }
            let decoded: T = try decoder.decode(data)
            return decoded
        } catch let error {
            throw error
        }
    }

    private func resolve(networkError error: NetworkError) -> DataTransferError {
        let resolvedError = self.errorResolver.resolve(error: error)
        return resolvedError is NetworkError
        ? .networkFailure(error)
        : .resolvedNetworkFailure(resolvedError)
    }
}

// MARK: - Logger
public final class DefaultDataTransferErrorLogger: DataTransferErrorLogger {
    public init() { }

    public func log(error: Error) {
        print(error)
    }
}

// MARK: - Error Resolver
public class DefaultDataTransferErrorResolver: DataTransferErrorResolver {
    public init() { }
    public func resolve(error: NetworkError) -> Error {
        return error
    }
}

public class JSONResponseDecoder: ResponseDecoder {
    public let jsonDecoder = JSONDecoder()
    public init() { }
    public func decode<T: Decodable>(_ data: Data) throws -> T {
        return try jsonDecoder.decode(T.self, from: data)
    }
}

class RawDataResponseDecoder: ResponseDecoder {
    init() { }

    enum CodingKeys: String, CodingKey {
        case `default` = ""
    }
    func decode<T: Decodable>(_ data: Data) throws -> T {
        if T.self is Data.Type, let data = data as? T {
            return data
        } else {
            let context = DecodingError.Context(
                codingPath: [CodingKeys.default],
                debugDescription: "Expected Data type"
            )
            throw Swift.DecodingError.typeMismatch(T.self, context)
        }
    }
}
