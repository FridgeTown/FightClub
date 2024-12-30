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

    func request<T: Decodable>(_ endpoint: APIEndpoint) async throws -> APIResponse<T> {
        do {
            let headers: HTTPHeaders = [
                "Accept": "application/json",
                "Content-Type": "application/json"
            ]
            
            let response = try await AF.request(endpoint.url,
                                                 method: endpoint.method,
                                                 parameters: endpoint.parameters,
                                                 encoding: JSONEncoding.default, // JSON 형식으로 인코딩
                                                 headers: headers) // 헤더 추가
                .serializingData()
                .value
            
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
}
