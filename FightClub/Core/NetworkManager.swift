//
//  NetworkManager.swift
//  FightClub
//
//  Created by Edward Lee on 12/24/24.
//

import Alamofire
import Foundation

protocol NetworkManagerProtocol {
    func request<T: Decodable>(_ endpoint: APIEndpoint) async throws -> [T]
}

class NetworkManager: NetworkManagerProtocol {
    static let shared = NetworkManager()
    private init() {}

    func request<T: Decodable>(_ endpoint: APIEndpoint) async throws -> [T] {
        do {
            let response = try await AF.request(endpoint.url,
                                                 method: endpoint.method,
                                                 parameters: endpoint.parameters)
                .serializingData()
                .value
                
            let decoder = JSONDecoder()
            do {
                let items = try decoder.decode([T].self, from: response)
                return items
            } catch {
                print("디코딩 오류.. : \(error.localizedDescription)")
                throw error
            }
        } catch {
            print("API Request 오류 : \(error.localizedDescription)")
            throw error
        }
    }
}
