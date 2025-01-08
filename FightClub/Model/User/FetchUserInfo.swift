//
//  FetchUserInfo.swift
//  FightClub
//
//  Created by 김지훈 on 08/01/2025.
//
import Foundation
import Alamofire

func fetchUserInfo(completion: @escaping (Result<UserData, Error>) -> Void) {
    guard let url = URL(string: APIEndpoint.getUserInfo.url) else {
        completion(.failure(URLError(.badURL)))
        return
    }

    let headers: HTTPHeaders? = APIEndpoint.getUserInfo.header

    AF.request(url, method: .get, headers: headers)
        .validate(statusCode: 200..<300)
        .responseDecodable(of: APIResponse<UserData>.self) { response in
            switch response.result {
            case .success(let apiResponse):
                if let userData = apiResponse.data {
                    completion(.success(userData))
                } else {
                    completion(.failure(URLError(.cannotDecodeContentData)))
                }
            case .failure(let error):
                completion(.failure(error))
            }
        }
}
