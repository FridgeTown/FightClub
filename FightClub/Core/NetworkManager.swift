import Alamofire
import Foundation
import Network // NWPathMonitor를 위해 추가
import UIKit

// NetworkError를 더 구체적으로 정의
enum NetworkError: LocalizedError {
    case decodingError(Error)
    case requestFailed(Error)
    case invalidURL
    case serverError(Int)
    case networkConnectivity
    case timeout
    case unauthorized
    case unknown
    
    var errorDescription: String? {
        switch self {
        case .decodingError:
            return "데이터 처리 중 오류가 발생했습니다"
        case .requestFailed:
            return "요청을 처리할 수 없습니다"
        case .invalidURL:
            return "잘못된 URL입니다"
        case .serverError(let code):
            return "서버 오류가 발생했습니다 (코드: \(code))"
        case .networkConnectivity:
            return "인터넷 연결을 확인해주세요"
        case .timeout:
            return "서버 응답 시간이 초과되었습니다"
        case .unauthorized:
            return "인증이 필요합니다"
        case .unknown:
            return "알 수 없는 오류가 발생했습니다"
        }
    }
}

protocol NetworkManagerProtocol {
    func request<T: Decodable>(_ endpoint: APIEndpoint) async throws -> APIResponse<T>
    func requestArray<T: Decodable>(_ endpoint: APIEndpoint) async throws -> APIResponse<[T]>
}

class NetworkManager: NetworkManagerProtocol {
    static let shared = NetworkManager()
    private let networkMonitor = NetworkMonitor.shared
    private var defaultHeaders: HTTPHeaders = [
        "Accept": "application/json",
        "Content-Type": "application/json"
    ]
    
    private init() {}

    func request<T: Decodable>(_ endpoint: APIEndpoint) async throws -> APIResponse<T> {
        // 네트워크 연결 확인
        guard networkMonitor.isConnected else {
            throw NetworkError.networkConnectivity
        }
        
        do {
            var headers = defaultHeaders
            if let endpointHeaders = endpoint.header {
                endpointHeaders.forEach { header in
                    headers[header.name] = header.value
                }
            }
            
            let request = AF.request(endpoint.url,
                                   method: endpoint.method,
                                   parameters: endpoint.parameters,
                                   encoding: JSONEncoding.default,
                                   headers: headers)
            
            let data = try await request
                .validate() // 상태 코드 검증
                .serializingData()
                .value
            
            // HTTP 상태 코드 확인
            if let response = request.response {
                switch response.statusCode {
                case 401:
                    throw NetworkError.unauthorized
                case 500...599:
                    throw NetworkError.serverError(response.statusCode)
                default:
                    break
                }
            }
            
            let decoder = JSONDecoder()
            decoder.keyDecodingStrategy = .convertFromSnakeCase
            
            let apiResponse = try decoder.decode(APIResponse<T>.self, from: data)
            return apiResponse
            
        } catch let error as URLError {
            switch error.code {
            case .notConnectedToInternet:
                throw NetworkError.networkConnectivity
            case .timedOut:
                throw NetworkError.timeout
            default:
                throw NetworkError.requestFailed(error)
            }
        } catch let error as DecodingError {
            print("디코딩 오류: \(error.localizedDescription)")
            throw NetworkError.decodingError(error)
        } catch let networkError as NetworkError {
            throw networkError
        } catch {
            print("API 요청 오류: \(error.localizedDescription)")
            throw NetworkError.unknown
        }
    }

    func requestArray<T: Decodable>(_ endpoint: APIEndpoint) async throws -> APIResponse<[T]> {
        // 네트워크 연결 확인
        guard networkMonitor.isConnected else {
            throw NetworkError.networkConnectivity
        }
        
        do {
            var headers = defaultHeaders
            if let endpointHeaders = endpoint.header {
                endpointHeaders.forEach { header in
                    headers[header.name] = header.value
                }
            }
            
            let request = AF.request(endpoint.url,
                                   method: endpoint.method,
                                   parameters: endpoint.parameters,
                                   encoding: JSONEncoding.default,
                                   headers: headers)
            
            let data = try await request
                .validate()
                .serializingData()
                .value
            
            if let response = request.response {
                switch response.statusCode {
                case 401:
                    throw NetworkError.unauthorized
                case 500...599:
                    throw NetworkError.serverError(response.statusCode)
                default:
                    break
                }
            }
            
            let decoder = JSONDecoder()
            decoder.keyDecodingStrategy = .convertFromSnakeCase
            
            let apiResponse = try decoder.decode(APIResponse<[T]>.self, from: data)
            return apiResponse
            
        } catch let error as URLError {
            switch error.code {
            case .notConnectedToInternet:
                throw NetworkError.networkConnectivity
            case .timedOut:
                throw NetworkError.timeout
            default:
                throw NetworkError.requestFailed(error)
            }
        } catch let error as DecodingError {
            print("디코딩 오류: \(error.localizedDescription)")
            throw NetworkError.decodingError(error)
        } catch let networkError as NetworkError {
            throw networkError
        } catch {
            print("API 요청 오류: \(error.localizedDescription)")
            throw NetworkError.unknown
        }
    }
    
    func requestImage<T: Decodable>(_ endpoint: APIEndpoint) async throws -> APIResponse<T> {
        // 기존 request 함수와 동일한 구현
        return try await request(endpoint)
    }
    
    func uploadProfileImage(image: UIImage) async throws -> APIResponse<UserData?> {
        // 네트워크 연결 확인
        guard networkMonitor.isConnected else {
            print("네트워크 연결 없음")
            throw NetworkError.networkConnectivity
        }
        
        guard let url = URL(string: "http://43.200.49.201:8080/user/image") else {
            print("잘못된 URL")
            throw NetworkError.invalidURL
        }
        
        // 액세스 토큰 가져오기
        let accessToken: String
        do {
            guard let token = try TokenManager.shared.getAccessToken(), !token.isEmpty else {
                print("토큰 없음")
                throw NetworkError.unauthorized
            }
            accessToken = token
            print("토큰 확인됨: \(accessToken.prefix(10))...")
        } catch {
            print("토큰 가져오기 실패: \(error)")
            throw NetworkError.unauthorized
        }
        
        // 이미지 크기 조정 및 압축
        let maxSize: CGFloat = 800.0 // 최대 800x800
        let scale = min(maxSize/image.size.width, maxSize/image.size.height, 1.0)
        let newSize = CGSize(width: image.size.width * scale, height: image.size.height * scale)
        
        let renderer = UIGraphicsImageRenderer(size: newSize)
        let resizedImage = renderer.image { context in
            image.draw(in: CGRect(origin: .zero, size: newSize))
        }
        
        // 이미지 압축
        guard let imageData = resizedImage.jpegData(compressionQuality: 0.5) else { // 압축률 50%로 조정
            print("이미지 변환 실패")
            throw NetworkError.requestFailed(URLError(.cannotCreateFile))
        }
        print("이미지 데이터 크기: \(imageData.count) bytes")
        
        // 1MB 제한 확인
        let maxBytes = 1024 * 1024 // 1MB
        guard imageData.count <= maxBytes else {
            print("이미지 크기가 1MB를 초과합니다")
            throw NetworkError.requestFailed(URLError(.dataLengthExceedsMaximum))
        }
        
        // 헤더 설정
        let headers: HTTPHeaders = [
            "Authorization": "Bearer \(accessToken)",
            "Content-Type": "multipart/form-data"
        ]
        
        return try await withCheckedThrowingContinuation { continuation in
            AF.upload(multipartFormData: { formData in
                formData.append(imageData, withName: "file", fileName: "profile.jpg", mimeType: "image/jpeg")
            }, to: url, method: .post, headers: headers)
            .validate(statusCode: 200..<300)
            .responseDecodable(of: APIResponse<UserData?>.self) { response in
                // 응답 데이터 로깅
                print("서버 응답 상태 코드: \(response.response?.statusCode ?? -1)")
                if let data = response.data {
                    print("서버 응답 데이터: \(String(data: data, encoding: .utf8) ?? "없음")")
                }
                
                switch response.result {
                case .success(let apiResponse):
                    print("업로드 성공: \(apiResponse)")
                    continuation.resume(returning: apiResponse)
                case .failure(let error):
                    print("업로드 실패: \(error)")
                    if let statusCode = response.response?.statusCode {
                        switch statusCode {
                        case 401:
                            continuation.resume(throwing: NetworkError.unauthorized)
                        case 413:
                            continuation.resume(throwing: NetworkError.requestFailed(URLError(.dataLengthExceedsMaximum)))
                        case 500...599:
                            continuation.resume(throwing: NetworkError.serverError(statusCode))
                        default:
                            continuation.resume(throwing: NetworkError.requestFailed(error))
                        }
                    } else {
                        continuation.resume(throwing: NetworkError.requestFailed(error))
                    }
                }
            }
        }
    }
}

// 네트워크 상태 모니터링을 위한 클래스
class NetworkMonitor: ObservableObject {
    static let shared = NetworkMonitor()
    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "NetworkMonitor")
    
    @Published var isConnected = true
    
    private init() {
        monitor.pathUpdateHandler = { [weak self] path in
            DispatchQueue.main.async {
                self?.isConnected = path.status == .satisfied
            }
        }
        monitor.start(queue: queue)
    }
    
    deinit {
        monitor.cancel()
    }
}
