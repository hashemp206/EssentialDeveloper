//
//  RemoteLoader.swift
//  EssentialFeed
//
//  Created by Hashem Abounajmi on 28/03/2022.
//  Copyright © 2022 Hashem Aboonajmi. All rights reserved.
//

import Foundation

public final class RemoteLoader<Resource> {
    
    private let url: URL
    private let client: HTTPClient
    private let mapper: Mapper
    
    public enum Error: Swift.Error {
        case connectivity
        case invalidData
    }
    
    public typealias Result = Swift.Result<Resource, Swift.Error>
    public typealias Mapper = (Data, HTTPURLResponse) throws -> Resource
    
    public init(url: URL, client: HTTPClient, mapper: @escaping Mapper) {
        self.client = client
        self.url = url
        self.mapper = mapper
    }
    
    public func load(completion: @escaping (Result) -> Void ) {
        client.get(from: url) { [weak self] result in
            guard let self = self else { return }
            switch result {
                case let .success((data, response)):
                completion(self.map(data, from: response))
                case .failure(_):
                    completion(.failure(Error.connectivity))
            }
        }
    }
    
    private func map(_ data: Data, from response: HTTPURLResponse) -> Result {
        do {
            return .success(try mapper(data, response))
        } catch {
            return .failure(Error.invalidData)
        }
    }
}