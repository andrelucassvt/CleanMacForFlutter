---
name: service
description: Cria a camada de Networking (APIClient, Endpoint, NetworkError) seguindo o padrao MVVM do projeto SwiftUI (iOS 15+). Use quando o usuario pedir para criar o cliente HTTP, adicionar novos endpoints, configurar a camada de rede, ou criar um servico de armazenamento local.
argument-hint: networking | storage | <NomeDoServico> (ex: KeychainService)
---

Crie a camada de servico seguindo o padrao MVVM do projeto. Target minimo: **iOS 15**.

## Argumentos

Tipo de servico: `$ARGUMENTS`

Se `$ARGUMENTS` estiver vazio, pergunte:
- "Qual tipo de servico precisa criar?"
  - `networking` — APIClient, Endpoint, NetworkError (infraestrutura HTTP completa)
  - `endpoint` — adicionar novos casos ao enum `Endpoint` existente
  - `storage` — KeychainService ou UserDefaultsService
  - Outro nome customizado

## Perguntas a fazer (se nao informadas nos argumentos)

### Para `networking` (setup inicial)
1. Qual a `baseURL` da API? (ex: `https://api.example.com`) — se nao souber, use placeholder
2. A API usa autenticacao por token Bearer? (padrao: sim — adicionar header `Authorization`)
3. A API retorna datas em ISO 8601? (padrao: sim)

### Para `endpoint` (adicionar endpoints)
1. Quais recursos novos precisam de endpoints? (ex: `Product`, `Order`)
2. Quais operacoes: GET lista, GET por ID, POST, PUT, DELETE?

### Para `storage`
1. `KeychainService` (dados sensiveis: tokens, senhas) ou `UserDefaultsService` (preferencias)?
2. Quais chaves/valores precisam ser armazenados?

---

## O que criar

### Opção 1: `networking` — Infraestrutura HTTP completa

Crie os 3 arquivos em `Services/Networking/`:

#### `Services/Networking/Endpoint.swift`

```swift
import Foundation

// MARK: - HTTPMethod

enum HTTPMethod: String {
    case get    = "GET"
    case post   = "POST"
    case put    = "PUT"
    case patch  = "PATCH"
    case delete = "DELETE"
}

// MARK: - Endpoint

enum Endpoint {
    // TODO: Adicione os casos conforme os recursos da API
    // Exemplo:
    // case userList
    // case user(String)
    // case createUser(User)
    // case updateUser(User)
    // case deleteUser(String)

    var path: String {
        switch self {
        // TODO: Mapeie cada caso para o path correspondente
        // case .userList:              return "/users"
        // case .user(let id):          return "/users/\(id)"
        // case .createUser:            return "/users"
        // case .updateUser(let item):  return "/users/\(item.id)"
        // case .deleteUser(let id):    return "/users/\(id)"
        }
    }

    var method: HTTPMethod {
        switch self {
        // TODO: Mapeie cada caso para o metodo HTTP correspondente
        // case .userList:    return .get
        // case .user:        return .get
        // case .createUser:  return .post
        // case .updateUser:  return .put
        // case .deleteUser:  return .delete
        }
    }

    var body: Encodable? {
        switch self {
        // Retorne o body para casos que enviam dados (POST, PUT, PATCH)
        // case .createUser(let user):  return user
        // case .updateUser(let user):  return user
        default: return nil
        }
    }
}
```

#### `Services/Networking/NetworkError.swift`

```swift
import Foundation

enum NetworkError: LocalizedError {
    case invalidURL
    case invalidResponse
    case httpError(statusCode: Int)
    case decodingFailed(Error)
    case encodingFailed(Error)
    case noInternetConnection
    case unauthorized
    case serverError(Int)

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "URL invalida."
        case .invalidResponse:
            return "Resposta invalida do servidor."
        case .httpError(let code):
            return "Erro HTTP \(code)."
        case .decodingFailed(let error):
            return "Falha ao processar dados: \(error.localizedDescription)"
        case .encodingFailed(let error):
            return "Falha ao codificar dados: \(error.localizedDescription)"
        case .noInternetConnection:
            return "Sem conexao com a internet."
        case .unauthorized:
            return "Sessao expirada. Faca login novamente."
        case .serverError(let code):
            return "Erro do servidor (\(code)). Tente novamente mais tarde."
        }
    }
}

// MARK: - Empty Response

struct EmptyResponse: Decodable {}
```

#### `Services/Networking/APIClient.swift`

```swift
import Foundation

// MARK: - Protocol

protocol APIClientProtocol: Sendable {
    func request<T: Decodable>(endpoint: Endpoint, responseType: T.Type) async throws -> T
}

// MARK: - Implementation

final class APIClient: APIClientProtocol {

    // MARK: - Properties

    private let baseURL: URL
    private let session: URLSession
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    // MARK: - Init

    init(
        baseURL: URL = URL(string: "https://api.example.com")!,
        session: URLSession = .shared
    ) {
        self.baseURL = baseURL
        self.session = session

        self.encoder = JSONEncoder()
        self.encoder.dateEncodingStrategy = .iso8601

        self.decoder = JSONDecoder()
        self.decoder.dateDecodingStrategy = .iso8601
    }

    // MARK: - Request

    func request<T: Decodable>(endpoint: Endpoint, responseType: T.Type) async throws -> T {
        let urlRequest = try buildRequest(for: endpoint)
        let (data, response) = try await session.data(for: urlRequest)
        try validate(response: response, data: data)
        return try decode(data, as: T.self)
    }

    // MARK: - Private Helpers

    private func buildRequest(for endpoint: Endpoint) throws -> URLRequest {
        let url = baseURL.appendingPathComponent(endpoint.path)
        var request = URLRequest(url: url)
        request.httpMethod = endpoint.method.rawValue
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        // Descomentar quando tiver autenticacao:
        // if let token = TokenStorage.shared.accessToken {
        //     request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        // }

        if let body = endpoint.body {
            request.httpBody = try encoder.encode(AnyEncodable(body))
        }

        return request
    }

    private func validate(response: URLResponse, data: Data) throws {
        guard let httpResponse = response as? HTTPURLResponse else {
            throw NetworkError.invalidResponse
        }

        switch httpResponse.statusCode {
        case 200...299:
            break
        case 401:
            throw NetworkError.unauthorized
        case 500...599:
            throw NetworkError.serverError(httpResponse.statusCode)
        default:
            throw NetworkError.httpError(statusCode: httpResponse.statusCode)
        }
    }

    private func decode<T: Decodable>(_ data: Data, as type: T.Type) throws -> T {
        do {
            return try decoder.decode(T.self, from: data)
        } catch {
            throw NetworkError.decodingFailed(error)
        }
    }
}

// MARK: - AnyEncodable (type erasure para Encodable)

private struct AnyEncodable: Encodable {
    private let encode: (Encoder) throws -> Void

    init(_ value: Encodable) {
        self.encode = value.encode(to:)
    }

    func encode(to encoder: Encoder) throws {
        try encode(encoder)
    }
}
```

---

### Opção 2: `endpoint` — Adicionar endpoints ao enum existente

Adicione os novos casos ao enum `Endpoint` em `Services/Networking/Endpoint.swift`:

```swift
// Novos casos:
case <resource>List
case <resource>(String)          // id
case create<Resource>(<Resource>)
case update<Resource>(<Resource>)
case delete<Resource>(String)    // id

// Em var path:
case .<resource>List:                  return "/<resources>"
case .<resource>(let id):              return "/<resources>/\(id)"
case .create<Resource>:                return "/<resources>"
case .update<Resource>(let item):      return "/<resources>/\(item.id)"
case .delete<Resource>(let id):        return "/<resources>/\(id)"

// Em var method:
case .<resource>List:                  return .get
case .<resource>:                      return .get
case .create<Resource>:                return .post
case .update<Resource>:                return .put
case .delete<Resource>:                return .delete

// Em var body:
case .create<Resource>(let item):      return item
case .update<Resource>(let item):      return item
```

---

### Opção 3: `storage` — Servicos de armazenamento local

#### `Services/Storage/KeychainService.swift` (dados sensiveis)

```swift
import Foundation
import Security

protocol KeychainServiceProtocol: Sendable {
    func save(_ value: String, forKey key: String) throws
    func read(forKey key: String) throws -> String
    func delete(forKey key: String) throws
}

enum KeychainError: LocalizedError {
    case saveFailed(OSStatus)
    case readFailed(OSStatus)
    case deleteFailed(OSStatus)
    case itemNotFound

    var errorDescription: String? {
        switch self {
        case .saveFailed(let status):  return "Falha ao salvar no Keychain: \(status)"
        case .readFailed(let status):  return "Falha ao ler do Keychain: \(status)"
        case .deleteFailed(let status): return "Falha ao deletar do Keychain: \(status)"
        case .itemNotFound:            return "Item nao encontrado no Keychain."
        }
    }
}

final class KeychainService: KeychainServiceProtocol {

    func save(_ value: String, forKey key: String) throws {
        let data = Data(value.utf8)
        let query: [CFString: Any] = [
            kSecClass:           kSecClassGenericPassword,
            kSecAttrAccount:     key,
            kSecValueData:       data,
            kSecAttrAccessible:  kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        ]

        SecItemDelete(query as CFDictionary)
        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else { throw KeychainError.saveFailed(status) }
    }

    func read(forKey key: String) throws -> String {
        let query: [CFString: Any] = [
            kSecClass:            kSecClassGenericPassword,
            kSecAttrAccount:      key,
            kSecReturnData:       true,
            kSecMatchLimit:       kSecMatchLimitOne
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status != errSecItemNotFound else { throw KeychainError.itemNotFound }
        guard status == errSecSuccess, let data = result as? Data,
              let string = String(data: data, encoding: .utf8) else {
            throw KeychainError.readFailed(status)
        }

        return string
    }

    func delete(forKey key: String) throws {
        let query: [CFString: Any] = [
            kSecClass:        kSecClassGenericPassword,
            kSecAttrAccount:  key
        ]
        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainError.deleteFailed(status)
        }
    }
}
```

#### `Services/Storage/UserDefaultsService.swift` (preferencias)

```swift
import Foundation

protocol UserDefaultsServiceProtocol: Sendable {
    func set<T: Codable>(_ value: T, forKey key: UserDefaultsKey)
    func get<T: Codable>(forKey key: UserDefaultsKey) -> T?
    func remove(forKey key: UserDefaultsKey)
}

enum UserDefaultsKey: String {
    // Adicione as chaves do projeto aqui:
    // case hasCompletedOnboarding
    // case selectedLanguage
    // case lastSyncDate
}

final class UserDefaultsService: UserDefaultsServiceProtocol {

    private let defaults: UserDefaults
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func set<T: Codable>(_ value: T, forKey key: UserDefaultsKey) {
        if let data = try? encoder.encode(value) {
            defaults.set(data, forKey: key.rawValue)
        }
    }

    func get<T: Codable>(forKey key: UserDefaultsKey) -> T? {
        guard let data = defaults.data(forKey: key.rawValue) else { return nil }
        return try? decoder.decode(T.self, from: data)
    }

    func remove(forKey key: UserDefaultsKey) {
        defaults.removeObject(forKey: key.rawValue)
    }
}
```

---

## Apos criar os arquivos

Informe o usuario que ainda precisa:

### Para `networking`:
1. Substituir `https://api.example.com` pela URL real da API
2. Adicionar os endpoints correspondentes aos recursos do projeto ao enum `Endpoint`
3. Se usar autenticacao, criar `TokenStorage` (via `KeychainService`) e descomentar o header `Authorization` no `APIClient`
4. Verificar se `EmptyResponse` ja existe — usar apenas uma definicao no projeto

### Para `storage`:
1. Registrar as chaves necessarias no enum `UserDefaultsKey`
2. Injetar o servico via `init` nos ViewModels ou Repositories que precisarem

---

## Regras

- Sem `import SwiftUI` — apenas `Foundation` (e `Security` para Keychain)
- `APIClientProtocol` marcado como `Sendable` para compatibilidade com `async/await`
- Nenhum tratamento de estado de UI — apenas operacoes de rede e armazenamento
- Erros tipados e descritivos — nunca propague erros genericos sem `LocalizedError`
- `JSONDecoder` com `.iso8601` como `dateDecodingStrategy` (padrao da API)
- Encoding do body via `AnyEncodable` para type erasure seguro de `Encodable`
- `kSecAttrAccessibleWhenUnlockedThisDeviceOnly` para dados do Keychain — nunca `kSecAttrAccessibleAlways`

---

## Checklist de Revisao

### APIClient / Networking
- [ ] `APIClientProtocol` marcado como `Sendable`
- [ ] `final class APIClient` sem `import SwiftUI`
- [ ] `baseURL` injetavel via `init` (nao hardcoded no metodo)
- [ ] `JSONDecoder` e `JSONEncoder` com `.iso8601`
- [ ] Validacao de `HTTPURLResponse` com tratamento por faixa de status
- [ ] `401` mapeado para `NetworkError.unauthorized`
- [ ] `500-599` mapeado para `NetworkError.serverError`
- [ ] `DecodingError` capturado e convertido para `NetworkError.decodingFailed`
- [ ] `EmptyResponse` definido uma unica vez no projeto
- [ ] `AnyEncodable` presente para encoding do body

### Endpoint
- [ ] Todos os casos tem `path`, `method` e `body` mapeados
- [ ] Paths sem barra inicial (a `appendingPathComponent` cuida disso)
- [ ] POST/PUT casos retornam o model no `body`
- [ ] GET/DELETE casos retornam `nil` no `body`

### Keychain
- [ ] `kSecAttrAccessibleWhenUnlockedThisDeviceOnly` (nunca `kSecAttrAccessibleAlways`)
- [ ] `SecItemDelete` antes de `SecItemAdd` para evitar duplicatas
- [ ] Erros mapeados para `KeychainError` com `OSStatus`

### UserDefaults
- [ ] Chaves tipadas via `UserDefaultsKey` enum (nunca strings soltas)
- [ ] Encoding/decoding via `JSONEncoder`/`JSONDecoder` para suportar tipos `Codable` complexos
