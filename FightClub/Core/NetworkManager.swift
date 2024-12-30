//
//  NetworkManager.swift
//  FightClub
//
//  Created by Edward Lee on 12/24/24.
//

import Alamofire
import Foundation

protocol NetworkManagerProtocol {
    func request<T: Decodable>(_ endpoint: APIEndpoint) async throws -> APIResponse<T>
}

class NetworkManager: NetworkManagerProtocol {
    static let shared = NetworkManager()
    private init() {}
    
    private var defaultHeaders: HTTPHeaders = [
        "Accept": "application/json",
        "Content-Type": "application/json"
    ]

    func request<T: Decodable>(_ endpoint: APIEndpoint) async throws -> APIResponse<T> {
        do {
                var headers = defaultHeaders
                if let endpointHeaders = endpoint.header {
                    endpointHeaders.forEach { header in
                        headers[header.name] = header.value
                    }
                }
            
            let response = try await AF.request(endpoint.url,
                                                 method: endpoint.method,
                                                 parameters: endpoint.parameters,
                                                 encoding: JSONEncoding.default,
                                                headers: headers)
                .serializingData()
                .value
            print("responseon network manager", response)
            let decoder = JSONDecoder()
            do {
                let apiResponse = try decoder.decode(APIResponse<T>.self, from: response)
                return apiResponse
            } catch {
                print("디코딩 오류.. : \(error.localizedDescription)")
                throw error
            }
        } catch {
            print("API Request 오류 : \(error.localizedDescription)")
            throw error
        }
    }
    
    func requestArray<T: Decodable>(_ endpoint: APIEndpoint) async throws -> APIResponse<[T]> {
        do {
                var headers = defaultHeaders
                if let endpointHeaders = endpoint.header {
                    endpointHeaders.forEach { header in
                        headers[header.name] = header.value
                    }
                }
            
            let response = try await AF.request(endpoint.url,
                                                 method: endpoint.method,
                                                 parameters: endpoint.parameters,
                                                 encoding: JSONEncoding.default,
                                                headers: headers)
                .serializingData()
                .value
            print("responseon network manager", response)
            let decoder = JSONDecoder()
            do {
                let apiResponse = try decoder.decode(APIResponse<[T]>.self, from: response)
                return apiResponse
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
