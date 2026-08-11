import Foundation

#if canImport(FoundationNetworking)
  import FoundationNetworking
#endif

public enum RemoteModelConfigurationError: Error, Equatable, Sendable {
  case endpointMustUseHTTP
  case emptyProviderIdentifier
  case emptyProviderVersion
  case invalidRequestTimeout
}

public struct BearerTokenSource: Sendable {
  private let resolver: @Sendable () async throws -> String?

  public static let none = BearerTokenSource(value: nil)

  public init(value: String?) {
    resolver = { value }
  }

  public init(resolve: @escaping @Sendable () async throws -> String?) {
    resolver = resolve
  }

  fileprivate func resolve() async throws -> String? {
    try await resolver()
  }
}

public struct RemoteModelEndpointConfiguration: Sendable {
  public let endpoint: URL
  public let providerIdentifier: String
  public let providerVersion: String
  public let requestTimeout: TimeInterval
  fileprivate let bearerToken: BearerTokenSource

  public init(
    endpoint: URL,
    providerIdentifier: String,
    providerVersion: String,
    requestTimeout: TimeInterval = 30,
    bearerToken: BearerTokenSource = .none
  ) throws {
    guard
      let scheme = endpoint.scheme?.lowercased(),
      ["http", "https"].contains(scheme),
      endpoint.host != nil
    else {
      throw RemoteModelConfigurationError.endpointMustUseHTTP
    }
    let providerIdentifier = providerIdentifier.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !providerIdentifier.isEmpty else {
      throw RemoteModelConfigurationError.emptyProviderIdentifier
    }
    let providerVersion = providerVersion.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !providerVersion.isEmpty else {
      throw RemoteModelConfigurationError.emptyProviderVersion
    }
    guard requestTimeout.isFinite, requestTimeout > 0 else {
      throw RemoteModelConfigurationError.invalidRequestTimeout
    }

    self.endpoint = endpoint
    self.providerIdentifier = providerIdentifier
    self.providerVersion = providerVersion
    self.requestTimeout = requestTimeout
    self.bearerToken = bearerToken
  }
}

public enum RemoteModelAdapterError: Error, Equatable, Sendable {
  case credentialResolutionFailed
  case invalidBearerToken
  case requestEncodingFailed
  case timedOut
  case transportFailed(code: Int?)
  case nonHTTPResponse
  case httpStatus(code: Int)
  case responseDecodingFailed
  case responseContractViolation(reason: String)
}

extension RemoteModelAdapterError: LocalizedError {
  public var errorDescription: String? {
    switch self {
    case .credentialResolutionFailed:
      "The runtime bearer token could not be resolved."
    case .invalidBearerToken:
      "The runtime bearer token is empty or contains an invalid line break."
    case .requestEncodingFailed:
      "The model request could not be encoded as JSON."
    case .timedOut:
      "The model request timed out."
    case .transportFailed(let code):
      code.map { "The model transport failed with URL error code \($0)." }
        ?? "The model transport failed."
    case .nonHTTPResponse:
      "The model endpoint did not return an HTTP response."
    case .httpStatus(let code):
      "The model endpoint returned HTTP status \(code)."
    case .responseDecodingFailed:
      "The model response was not valid JSON for the expected response contract."
    case .responseContractViolation(let reason):
      "The model response violated the response contract: \(reason)"
    }
  }
}

public protocol RemoteModelHTTPTransport: Sendable {
  func data(for request: URLRequest) async throws -> (Data, URLResponse)
}

public struct URLSessionRemoteModelHTTPTransport: RemoteModelHTTPTransport {
  private let session: URLSession

  public init(session: URLSession = .shared) {
    self.session = session
  }

  public func data(for request: URLRequest) async throws -> (Data, URLResponse) {
    try await session.data(for: request)
  }
}

struct RemoteModelHTTPClient: Sendable {
  let configuration: RemoteModelEndpointConfiguration
  let transport: any RemoteModelHTTPTransport

  func post<Request: Encodable, Response: Decodable>(
    _ payload: Request,
    responseType: Response.Type
  ) async throws -> Response {
    try Task.checkCancellation()

    let body: Data
    do {
      body = try JSONEncoder().encode(payload)
    } catch {
      throw RemoteModelAdapterError.requestEncodingFailed
    }

    let token: String?
    do {
      token = try await configuration.bearerToken.resolve()
    } catch is CancellationError {
      throw CancellationError()
    } catch {
      if Task.isCancelled { throw CancellationError() }
      throw RemoteModelAdapterError.credentialResolutionFailed
    }
    try Task.checkCancellation()

    var request = URLRequest(
      url: configuration.endpoint,
      cachePolicy: .reloadIgnoringLocalAndRemoteCacheData,
      timeoutInterval: configuration.requestTimeout
    )
    request.httpMethod = "POST"
    request.httpBody = body
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    request.setValue("application/json", forHTTPHeaderField: "Accept")
    if let token {
      guard
        !token.isEmpty,
        !token.contains("\r"),
        !token.contains("\n")
      else {
        throw RemoteModelAdapterError.invalidBearerToken
      }
      request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
    }

    let responseBody: Data
    let response: URLResponse
    do {
      (responseBody, response) = try await transport.data(for: request)
    } catch is CancellationError {
      throw CancellationError()
    } catch let error as URLError {
      if error.code == .cancelled || Task.isCancelled {
        throw CancellationError()
      }
      if error.code == .timedOut {
        throw RemoteModelAdapterError.timedOut
      }
      throw RemoteModelAdapterError.transportFailed(code: error.errorCode)
    } catch {
      if Task.isCancelled { throw CancellationError() }
      let error = error as NSError
      if error.domain == NSURLErrorDomain {
        if error.code == NSURLErrorCancelled { throw CancellationError() }
        if error.code == NSURLErrorTimedOut { throw RemoteModelAdapterError.timedOut }
        throw RemoteModelAdapterError.transportFailed(code: error.code)
      }
      throw RemoteModelAdapterError.transportFailed(code: nil)
    }
    try Task.checkCancellation()

    guard let response = response as? HTTPURLResponse else {
      throw RemoteModelAdapterError.nonHTTPResponse
    }
    guard (200..<300).contains(response.statusCode) else {
      throw RemoteModelAdapterError.httpStatus(code: response.statusCode)
    }

    do {
      return try JSONDecoder().decode(responseType, from: responseBody)
    } catch {
      throw RemoteModelAdapterError.responseDecodingFailed
    }
  }
}
