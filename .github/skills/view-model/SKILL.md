---
name: view-model
description: Cria um novo ViewModel SwiftUI seguindo o padrao MVVM do projeto (iOS 15+). Use quando o usuario pedir para criar um novo ViewModel.
argument-hint: <NomeDoViewModel> (ex: ProductDetail, Profile)
---

Crie um novo ViewModel SwiftUI seguindo o padrao MVVM do projeto. Target minimo: **iOS 15**.

## Argumentos

Nome em PascalCase (sem o sufixo `ViewModel`): `$ARGUMENTS`

Se `$ARGUMENTS` estiver vazio, pergunte: "Qual o nome do ViewModel? (ex: `ProductDetail`, `Profile`)"

A partir do nome PascalCase, derive:
- `<Name>ViewModel` para o nome da classe
- Arquivo: `ViewModels/<Name>ViewModel.swift`

## Perguntas a fazer (se nao informadas nos argumentos)

1. **Repository**: qual Repository sera injetado? (ex: `UserRepository`, `ProductRepository`) — se nao souber, use um placeholder
2. **Tipo de dados**: qual o tipo principal que o ViewModel gerencia? (ex: `[User]`, `Product`, `Void`) — determina o `ViewState<T>`
3. **Acoes principais**: quais acoes o usuario pode realizar nessa tela? (ex: carregar lista, deletar item, buscar) — se nao souber, crie apenas `load()`

## ViewState — gerenciamento de estado

Todo ViewModel usa o enum `ViewState` para representar o estado atual da tela. Isso garante que a View sempre saiba exatamente em qual estado se encontra, sem depender de combinacoes de booleans.

### Definicao do `ViewState`

Crie o arquivo `Utilities/ViewState.swift` caso ainda nao exista no projeto:

```swift
import Foundation

enum ViewState<T> {
    case idle
    case loading
    case success(T)
    case error(String)

    var isLoading: Bool {
        if case .loading = self { return true }
        return false
    }

    var value: T? {
        if case .success(let data) = self { return data }
        return nil
    }

    var errorMessage: String? {
        if case .error(let message) = self { return message }
        return nil
    }
}
```

## O que criar

### `ViewModels/<Name>ViewModel.swift`

> Importe `Combine` apenas se o ViewModel usar publishers reativos (ex: busca com debounce). Para a maioria dos casos, `Foundation` e suficiente.

```swift
import Foundation

@MainActor
final class <Name>ViewModel: ObservableObject {

    // MARK: - State

    @Published private(set) var state: ViewState<<DataType>> = .idle

    // MARK: - Dependencies

    private let repository: <Repository>Protocol

    // MARK: - Init

    init(repository: <Repository>Protocol = <Repository>()) {
        self.repository = repository
    }

    // MARK: - Actions

    func load() async {
        state = .loading

        do {
            let data = try await repository.fetch()
            state = .success(data)
        } catch {
            state = .error(error.localizedDescription)
        }
    }
}
```

## Uso do ViewState na View

A View consome o `state` do ViewModel com um `switch`:

```swift
var body: some View {
    Group {
        switch viewModel.state {
        case .idle:
            EmptyView()

        case .loading:
            ProgressView("Carregando...")

        case .success(let data):
            // TODO: Renderize o conteudo com `data`
            ContentView(data: data)

        case .error(let message):
            ErrorStateView(message: message) {
                Task { await viewModel.load() }
            }
        }
    }
    .task {
        await viewModel.load()
    }
}
```

## Exemplos de acoes comuns

Quando o usuario informar as acoes, use estes padroes como referencia:

### Carregar lista

```swift
@Published private(set) var state: ViewState<[<Model>]> = .idle

func loadItems() async {
    state = .loading

    do {
        let items = try await repository.fetchAll()
        state = .success(items)
    } catch {
        state = .error(error.localizedDescription)
    }
}
```

### Deletar item

```swift
func delete(_ item: <Model>) async {
    guard case .success(var items) = state else { return }

    do {
        try await repository.delete(item)
        items.removeAll { $0.id == item.id }
        state = .success(items)
    } catch {
        state = .error(error.localizedDescription)
    }
}
```

### Buscar / filtrar

> Requer `import Combine` no arquivo.

```swift
@Published private(set) var searchState: ViewState<[<Model>]> = .idle
@Published var searchText: String = ""

private var cancellables = Set<AnyCancellable>()

private func setupSearch() {
    $searchText
        .debounce(for: .milliseconds(300), scheduler: RunLoop.main)
        .removeDuplicates()
        .sink { [weak self] query in
            Task { await self?.search(query: query) }
        }
        .store(in: &cancellables)
}

func search(query: String) async {
    guard !query.isEmpty else {
        searchState = .idle
        return
    }

    searchState = .loading

    do {
        let results = try await repository.search(query: query)
        searchState = .success(results)
    } catch {
        searchState = .error(error.localizedDescription)
    }
}
```

### Criar / salvar

```swift
@Published private(set) var saveState: ViewState<Void> = .idle

func save() async {
    saveState = .loading

    do {
        // TODO: Construa o model a partir do estado do form
        // let newItem = <Model>(...)
        // try await repository.create(newItem)
        saveState = .success(())
    } catch {
        saveState = .error(error.localizedDescription)
    }
}
```

### Paginacao

```swift
@Published private(set) var state: ViewState<[<Model>]> = .idle
private(set) var hasMorePages = true
private var currentPage = 0

func loadNextPage() async {
    guard hasMorePages else { return }
    if case .loading = state { return }

    let currentItems = state.value ?? []
    state = .loading

    do {
        let newItems = try await repository.fetch(page: currentPage)
        state = .success(currentItems + newItems)
        hasMorePages = !newItems.isEmpty
        currentPage += 1
    } catch {
        state = .error(error.localizedDescription)
    }
}
```

### Multiplos estados independentes

Quando a tela possui acoes independentes (ex: carregar dados + salvar formulario), use propriedades `ViewState` separadas:

```swift
@Published private(set) var state: ViewState<[<Model>]> = .idle
@Published private(set) var saveState: ViewState<Void> = .idle
@Published private(set) var deleteState: ViewState<Void> = .idle
```

## Apos criar o arquivo

Informe o usuario que ainda precisa:
1. Verificar se `Utilities/ViewState.swift` existe no projeto — se nao, crie-o
2. Criar o Repository correspondente em `Repositories/` (se ainda nao existir), com Protocol + implementacao concreta
3. Conectar o ViewModel na View correspondente usando `@StateObject`
4. Criar testes unitarios em `Tests/` seguindo o padrao:

```swift
import Testing
@testable import ProjectName

@Suite("<Name>ViewModel Tests")
struct <Name>ViewModelTests {

    @Test("Estado inicial e idle")
    func initialState() {
        let viewModel = <Name>ViewModel(repository: Mock<Repository>())
        #expect(viewModel.state == .idle)
    }

    @Test("Carrega dados com sucesso")
    func loadSuccess() async {
        let mockRepo = Mock<Repository>(state: .success)
        let viewModel = <Name>ViewModel(repository: mockRepo)

        await viewModel.load()

        #expect(viewModel.state.value != nil)
        #expect(viewModel.state.errorMessage == nil)
    }

    @Test("Exibe erro quando falha")
    func loadFailure() async {
        let mockRepo = Mock<Repository>(state: .failure)
        let viewModel = <Name>ViewModel(repository: mockRepo)

        await viewModel.load()

        #expect(viewModel.state.errorMessage != nil)
        #expect(viewModel.state.value == nil)
    }

    @Test("Estado loading durante carregamento")
    func loadingState() async {
        let mockRepo = Mock<Repository>(state: .success)
        let viewModel = <Name>ViewModel(repository: mockRepo)

        #expect(viewModel.state.isLoading == false)
    }
}
```

## Regras

- Nunca importar SwiftUI — apenas `Foundation`; adicione `import Combine` apenas quando usar publishers reativos (busca com debounce, etc.)
- Conforma com `ObservableObject` — nunca `@Observable` (requer iOS 17)
- Sempre marcar como `@MainActor`
- Sempre marcar como `final class`
- Use `ViewState<T>` para gerenciar estado — nunca booleans avulsos (`isLoading`, `hasError`)
- `@Published private(set)` em todas as propriedades de estado — imutavel externamente
- Dependencias injetadas via `init` com valor padrao (para testabilidade)
- Metodos publicos representam intencoes/acoes do usuario
- Use `async/await` para concorrencia — prefira sobre Combine para novas features
- Dependency Inversion — dependa de protocolos (`<Repository>Protocol`), nao de implementacoes concretas
- Organize com `// MARK: -` seguindo a ordem: State, Dependencies, Init, Actions
- Para acoes independentes, use propriedades `ViewState` separadas (ex: `state`, `saveState`, `deleteState`)

### APIs proibidas (acima do iOS 15)
| NAO usar | Requer | Usar no lugar |
|----------|--------|---------------|
| `@Observable` | iOS 17 | `ObservableObject` + `@Published` |
| `Observation` framework | iOS 17 | `Combine` |

## Checklist de Revisao

- [ ] `final class` com `ObservableObject` (nunca `struct`, nunca `@Observable`)
- [ ] `@MainActor` aplicado na classe
- [ ] Sem `import SwiftUI` — apenas `Foundation` (+ `Combine` se necessario)
- [ ] `ViewState<T>` para todos os estados — sem booleans avulsos (`isLoading`, `hasError`)
- [ ] `@Published private(set)` em todas as propriedades de estado
- [ ] Dependencias injetadas via `init` com valor padrao concreto
- [ ] Dependencias tipadas como Protocol (nao como implementacao concreta)
- [ ] Metodos publicos nomeados como intencoes do usuario (`loadUsers`, `deleteItem`, `save`)
- [ ] Erros capturados e convertidos para `ViewState.error(message)` — sem `throws` para a View
- [ ] `MARK: -` separando State / Dependencies / Init / Actions
- [ ] `ViewState.swift` existe em `Utilities/` antes de usar `ViewState<T>`
- [ ] Testes unitarios com `Mock<Repository>` para sucesso, falha e estado inicial
