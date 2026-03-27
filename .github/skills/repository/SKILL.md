---
name: repository
description: Cria um novo Repository SwiftUI seguindo o padrao MVVM do projeto (iOS 15+). Use quando o usuario pedir para criar um Repository, camada de dados, ou fonte de dados para um ViewModel.
argument-hint: <NomeDoRepository> (ex: User, Product)
---

Crie um novo Repository SwiftUI seguindo o padrao MVVM do projeto. Target minimo: **iOS 15**.

## Argumentos

Nome em PascalCase (sem o sufixo `Repository`): `$ARGUMENTS`

Se `$ARGUMENTS` estiver vazio, pergunte: "Qual o nome do Repository? (ex: `User`, `Product`)"

A partir do nome PascalCase, derive:
- `<Name>RepositoryProtocol` para o protocolo
- `<Name>Repository` para a implementacao concreta
- Arquivo: `Repositories/<Name>Repository.swift`

## Perguntas a fazer (se nao informadas nos argumentos)

1. **Model relacionada**: qual Model esse Repository gerencia? (ex: `User`, `Product`) — normalmente tem o mesmo nome base
2. **Operacoes necessarias**: quais operacoes o Repository precisa expor? (padrao: `fetchAll`, `fetchById`, `create`, `update`, `delete`) — liste apenas as necessarias
3. **Fonte de dados**: vai consumir `APIClient`? Banco local? Ambos? (padrao: `APIClient`)
4. **Mock para testes**: precisa de `Mock<Name>Repository` para testes e previews? (padrao: sim)

## O que criar

### `Repositories/<Name>Repository.swift`

```swift
import Foundation

// MARK: - Protocol

protocol <Name>RepositoryProtocol: Sendable {
    func fetchAll() async throws -> [<Name>]
    func fetch(id: String) async throws -> <Name>
    func create(_ item: <Name>) async throws -> <Name>
    func update(_ item: <Name>) async throws -> <Name>
    func delete(_ item: <Name>) async throws
}

// MARK: - Implementation

final class <Name>Repository: <Name>RepositoryProtocol {

    private let apiClient: APIClientProtocol

    init(apiClient: APIClientProtocol = APIClient()) {
        self.apiClient = apiClient
    }

    func fetchAll() async throws -> [<Name>] {
        try await apiClient.request(
            endpoint: .<name>List,
            responseType: [<Name>].self
        )
    }

    func fetch(id: String) async throws -> <Name> {
        try await apiClient.request(
            endpoint: .<name>(id),
            responseType: <Name>.self
        )
    }

    func create(_ item: <Name>) async throws -> <Name> {
        try await apiClient.request(
            endpoint: .create<Name>(item),
            responseType: <Name>.self
        )
    }

    func update(_ item: <Name>) async throws -> <Name> {
        try await apiClient.request(
            endpoint: .update<Name>(item),
            responseType: <Name>.self
        )
    }

    func delete(_ item: <Name>) async throws {
        try await apiClient.request(
            endpoint: .delete<Name>(item.id),
            responseType: EmptyResponse.self
        )
    }
}
```

> Inclua apenas as funcoes solicitadas pelo usuario. Nao crie operacoes que nao serao usadas.

---

### Mock (se solicitado)

Crie o mock no arquivo `Preview Content/Mock<Name>Repository.swift` para uso em testes e previews:

```swift
import Foundation

final class Mock<Name>Repository: <Name>RepositoryProtocol {

    // MARK: - Configuracao

    var stubbedItems: [<Name>] = <Name>.mockList
    var stubbedItem: <Name> = <Name>.mock
    var shouldFail: Bool = false
    var error: Error = NetworkError.invalidResponse

    // MARK: - Protocol

    func fetchAll() async throws -> [<Name>] {
        if shouldFail { throw error }
        return stubbedItems
    }

    func fetch(id: String) async throws -> <Name> {
        if shouldFail { throw error }
        return stubbedItem
    }

    func create(_ item: <Name>) async throws -> <Name> {
        if shouldFail { throw error }
        stubbedItems.append(item)
        return item
    }

    func update(_ item: <Name>) async throws -> <Name> {
        if shouldFail { throw error }
        if let index = stubbedItems.firstIndex(where: { $0.id == item.id }) {
            stubbedItems[index] = item
        }
        return item
    }

    func delete(_ item: <Name>) async throws {
        if shouldFail { throw error }
        stubbedItems.removeAll { $0.id == item.id }
    }
}
```

> O mock implementa todas as funcoes do protocolo para garantir que compila mesmo que o ViewModel use apenas algumas delas.

---

## Endpoints necessarios

Lembre o usuario de adicionar os endpoints correspondentes ao enum `Endpoint` em `Services/Networking/Endpoint.swift`:

```swift
// Adicionar ao enum Endpoint existente:

case <name>List
case <name>(String)          // id
case create<Name>(<Name>)
case update<Name>(<Name>)
case delete<Name>(String)    // id
```

E os respectivos `path` e `method`:

```swift
// No switch de `var path: String`:
case .<name>List:         return "/<names>"
case .<name>(let id):     return "/<names>/\(id)"
case .create<Name>:       return "/<names>"
case .update<Name>(let item): return "/<names>/\(item.id)"
case .delete<Name>(let id):   return "/<names>/\(id)"

// No switch de `var method: HTTPMethod`:
case .<name>List:         return .get
case .<name>:             return .get
case .create<Name>:       return .post
case .update<Name>:       return .put
case .delete<Name>:       return .delete
```

---

## Apos criar os arquivos

Informe o usuario que ainda precisa:
1. Adicionar os endpoints ao enum `Endpoint` em `Services/Networking/Endpoint.swift`
2. Injetar o repository no `<Name>ViewModel` via `init`
3. Garantir que `<Name>.mock` e `<Name>.mockList` existem em `Preview Content/PreviewData+<Name>.swift` — o mock depende deles
4. Verificar se `APIClient.swift` e `NetworkError.swift` existem em `Services/Networking/`

---

## Regras

- Sempre `Protocol` + implementacao concreta — nunca expor a classe diretamente ao ViewModel
- Protocolo marcado como `Sendable` para compatibilidade com `async/await`
- Sem `import SwiftUI` — apenas `import Foundation`
- Sem logica de negocio — apenas mapeamento entre camada de rede e camada de dominio
- Sem tratamento de erro no Repository — propague `throws` para o ViewModel tratar
- Dependencias injetadas via `init` com valor padrao concreto (para testabilidade)
- Mock sempre em `Preview Content/` — nunca no target principal
- Inclua apenas as operacoes que o ViewModel realmente usa

### APIs proibidas (acima do iOS 15)
| NAO usar | Requer | Usar no lugar |
|----------|--------|---------------|
| `@Observable` | iOS 17 | Nao aplicavel em Repository |
| Actors Swift | iOS 17 | `Sendable` + `async/await` |

---

## Checklist de Revisao

- [ ] Protocolo `<Name>RepositoryProtocol` separado da implementacao concreta
- [ ] Protocolo marcado como `Sendable`
- [ ] `final class` para a implementacao concreta
- [ ] Sem `import SwiftUI` — apenas `import Foundation`
- [ ] Sem logica de negocio — apenas chamadas ao `apiClient`
- [ ] Todos os metodos marcados como `async throws`
- [ ] Dependencia de `APIClientProtocol` (nao de `APIClient` direto)
- [ ] `init(apiClient:)` com valor padrao `APIClient()`
- [ ] Mock criado em `Preview Content/` (nao no target principal)
- [ ] Mock implementa todas as funcoes do protocolo
- [ ] Mock com `shouldFail: Bool` para testar cenarios de erro
- [ ] Endpoints adicionados ao enum `Endpoint`
- [ ] `<Name>.mock` e `<Name>.mockList` existem no `PreviewData`
