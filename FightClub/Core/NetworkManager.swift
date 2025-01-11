import Alamofire
import Foundation

// NetworkError.swift 또는 NetworkManager.swift 파일에 추가
enum NetworkError: Error {
    case decodingError(Error) // 디코딩 오류
    case requestFailed(Error) // 네트워크 요청 실패
    case invalidURL           // 잘못된 URL
    case unknown              // 알 수 없는 오류
}

protocol NetworkManagerProtocol {
    func request<T: Decodable>(_ endpoint: APIEndpoint) async throws -> APIResponse<T>
}

class NetworkManager: NetworkManagerProtocol {
    static let shared = NetworkManager()
    private init() {}
    

    func requestArray<T: Decodable>(_ endpoint: APIEndpoint) async throws -> APIResponse<[T]> {
        let data = try await AF.request(endpoint.url,
                                        method: endpoint.method,
                                        parameters: endpoint.parameters,

                                        encoding: JSONEncoding.default,
                                        headers: endpoint.header
        ).serializingData()
        .value
        
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        
        let apiResponse = try decoder.decode(APIResponse<[T]>.self, from: data)
        return apiResponse
    }
    
    private var defaultHeaders: HTTPHeaders = [
        "Accept": "application/json",
        "Content-Type": "application/json"
    ]

    func request<T: Decodable>(_ endpoint: APIEndpoint) async throws -> APIResponse<T> {
        do {
            // Merge default headers with endpoint-specific headers
            var headers = defaultHeaders
            if let endpointHeaders = endpoint.header {
                endpointHeaders.forEach { header in
                    headers[header.name] = header.value
                }
            }
            
            // Perform the network request
            let data = try await AF.request(endpoint.url,
                                            method: endpoint.method,
                                            parameters: endpoint.parameters,
                                            encoding: JSONEncoding.default,
                                            headers: headers)
                .serializingData()
                .value
            
            // Decode the response into APIResponse<T>
            let decoder = JSONDecoder()
            decoder.keyDecodingStrategy = .convertFromSnakeCase
            let apiResponse = try decoder.decode(APIResponse<T>.self, from: data)
            
            // Return the decoded response
            return apiResponse
        } catch let decodingError as DecodingError {
            print("디코딩 오류: \(decodingError.localizedDescription)")
            throw NetworkError.decodingError(decodingError)
        } catch {
            print("API 요청 오류: \(error.localizedDescription)")
            throw NetworkError.requestFailed(error)
        }
    }
}
