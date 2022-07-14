//
//  NetworkManager.swift
//  Networking
//
//  Created by Егор Бадмаев on 14.07.2022.
//

import Foundation

protocol NetworkManagerProtocol {
    var session: URLSession { get set }
    func perform<Model: Codable>(request: NetworkRequest, completion: @escaping (Result<Model, NetworkManagerError>) -> Void)
}

final class NetworkManager: NetworkManagerProtocol {
    
    public var session: URLSession
    private let decoder: JSONDecoder
    
    init(session: URLSession, decoder: JSONDecoder = JSONDecoder()) {
        self.session = session
        self.decoder = decoder
    }
    
    public func perform<Model: Codable>(request: NetworkRequest, completion: @escaping (Result<Model, NetworkManagerError>) -> Void) {
        
        guard let url = URL(string: request.urlString),
              var urlComponents = URLComponents(url: url, resolvingAgainstBaseURL: false)
        else {
            completion(.failure(NetworkManagerError.invalidURL))
            return
        }
        urlComponents.queryItems = request.parameters.map { URLQueryItem(name: $0.key, value: $0.value )}
        
        guard let url = urlComponents.url else {
            completion(.failure(NetworkManagerError.invalidURL))
            return
        }
        
        var urlRequest = URLRequest(url: url, cachePolicy: .useProtocolCachePolicy, timeoutInterval: 3)
        urlRequest.httpMethod = request.method.rawValue
        urlRequest.allHTTPHeaderFields = request.httpHeaderFields
        
        let dataTask = session.dataTask(with: urlRequest, completionHandler: { [weak self] (data, response, error) in
            
            /// We use the capture list in order to avoid reference-cycle or/and application crashes.
            /// `[weak self]` - creating a **weak** reference to `self`, thereby avoiding reference-cycle/crash
            /// Then we create a `strongSelf` - a strong reference to `self` inside the block, so we guarantee that the block will be executed to the end, since the instance of the class will not be able to reset, and we also avoid problems with optionals
            guard let strongSelf = self else {
                completion(.failure(NetworkManagerError.retainCycle))
                return
            }
            
            guard error == nil, let data = data else {
                completion(.failure(NetworkManagerError.networkError))
                return
            }
            
            guard let model = try? strongSelf.decoder.decode(Model.self, from: data) else {
                completion(.failure(NetworkManagerError.parsingJSONError))
                return
            }
            
            completion(.success(model.self))
        })
        dataTask.resume()
    }
}
