---
name: view
description: Cria uma nova View SwiftUI seguindo o padrao MVVM do projeto (iOS 15+). Use quando o usuario pedir para criar uma nova tela, view ou screen.
argument-hint: <NomeDaView> (ex: ProductDetail, Profile)
---

Crie uma nova View SwiftUI seguindo o padrao MVVM do projeto. Target minimo: **iOS 15**.

## Argumentos

Nome da View em PascalCase: `$ARGUMENTS`

Se `$ARGUMENTS` estiver vazio, pergunte: "Qual o nome da View? (ex: `ProductDetail`, `Profile`)"

A partir do nome PascalCase, derive:
- `<Name>View` para o nome da struct da View
- `<Name>ViewModel` para o nome da classe do ViewModel
- Diretorio: `Views/<Name>/`

## Perguntas a fazer (se nao informadas nos argumentos)

1. **ViewModel dedicado**: precisa de ViewModel? (padrao: sim)
2. **Repository**: qual Repository sera injetado no ViewModel? (ex: `UserRepository`) — se nao souber, use um placeholder
3. **Navegacao**: a View sera usada dentro de um `NavigationView`? (padrao: sim)

## O que criar

### 1. `Views/<Name>/<Name>View.swift`

Para suportar previews com estados diferentes, use o init com `StateObject` injetavel:

```swift
import SwiftUI

struct <Name>View: View {

    @StateObject private var viewModel: <Name>ViewModel

    init(viewModel: <Name>ViewModel = <Name>ViewModel()) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }

    var body: some View {
        NavigationView {
            Group {
                switch viewModel.state {
                case .idle:
                    EmptyView()

                case .loading:
                    ProgressView("Carregando...")

                case .success(let data):
                    content(data)

                case .error(let message):
                    ErrorStateView(message: message) {
                        Task { await viewModel.load() }
                    }
                }
            }
            .navigationTitle("<Name>")
        }
        .navigationViewStyle(.stack)
        .task {
            await viewModel.load()
        }
    }

    // MARK: - Subviews

    private func content(_ data: <DataType>) -> some View {
        ScrollView {
            VStack(spacing: 16) {
                // TODO: Adicione o conteudo aqui
            }
            .padding()
        }
    }
}

// MARK: - Preview

#Preview {
    <Name>View()
}

#Preview("Loading") {
    <Name>View(viewModel: <Name>ViewModel(repository: Mock<Repository>(forceLoading: true)))
}

#Preview("Error") {
    <Name>View(viewModel: <Name>ViewModel(repository: Mock<Repository>(forceError: true)))
}
```

### 2. `ViewModels/<Name>ViewModel.swift` (se solicitado)

```swift
import Foundation
import Combine

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

### 3. `Views/<Name>/Components/` (diretorio)

Crie o diretorio para componentes futuros da View. Nao crie arquivos dentro dele, apenas informe o usuario que subcomponentes devem ser colocados aqui.

## Apos criar os arquivos

Informe o usuario que ainda precisa:
1. Verificar se `Utilities/ViewState.swift` existe no projeto — se nao, crie-o
2. Verificar se `Views/Shared/ErrorStateView.swift` existe no projeto — se nao, crie o arquivo com o codigo abaixo:

```swift
import SwiftUI

struct ErrorStateView: View {

    let message: String
    let retryAction: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 48))
                .foregroundColor(.secondary)

            Text(message)
                .font(.body)
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)

            Button(action: retryAction) {
                Text("Tentar novamente")
                    .fontWeight(.medium)
            }
            .buttonStyle(.bordered)
        }
        .padding()
    }
}
```

3. Criar o Repository correspondente em `Repositories/` (se ainda nao existir), seguindo o padrao Protocol + implementacao concreta
4. Adicionar a rota no `AppRouter` se estiver usando navegacao centralizada

## Regras

### View
- Structs que conformam com `View` — nunca classes
- Declarativas e enxutas — sem logica de negocio no body
- Extraia subviews privadas quando o body ultrapassar ~40 linhas
- Use `@State` para estado local da View (toggle, campo de texto)
- Use `@StateObject` para criar o ViewModel, `@ObservedObject` para receber de fora
- Prefira `.task {}` para chamadas async ao aparecer a View
- Use `switch` sobre o `ViewState` para reagir a cada estado
- Use `NavigationView` + `.navigationViewStyle(.stack)` — nunca `NavigationStack` (requer iOS 16)
- Use `NavigationLink(destination:)` — nunca `NavigationLink(value:)` (requer iOS 16)
- Toda View deve ter um `#Preview` funcional

### ViewModel
- Nunca importar SwiftUI — apenas `Foundation` e `Combine`
- Conforma com `ObservableObject` — nunca `@Observable` (requer iOS 17)
- Marcado como `@MainActor`
- Usa `ViewState<T>` para gerenciar estado — nunca booleans avulsos
- Propriedades de estado usam `@Published private(set)`
- Dependencias injetadas via `init` (para testabilidade)
- Metodos publicos representam acoes do usuario

### Nomenclatura
| Tipo | Convencao | Exemplo |
|------|-----------|---------|
| View | `PascalCase` + sufixo `View` | `ProductDetailView` |
| ViewModel | `PascalCase` + sufixo `ViewModel` | `ProductDetailViewModel` |
| Componente | `PascalCase` + sufixo `View` | `ProductCardView` |
| Diretorio | `PascalCase` (nome da feature) | `Views/ProductDetail/` |

### APIs proibidas (acima do iOS 15)
| NAO usar | Requer | Usar no lugar |
|----------|--------|---------------|
| `@Observable` | iOS 17 | `ObservableObject` + `@Published` |
| `@State` com class | iOS 17 | `@StateObject` |
| `@Bindable` | iOS 17 | `@ObservedObject` |
| `NavigationStack` | iOS 16 | `NavigationView` + `.navigationViewStyle(.stack)` |
| `NavigationLink(value:)` | iOS 16 | `NavigationLink(destination:)` |
| `navigationDestination(for:)` | iOS 16 | Remover |
| `ContentUnavailableView` | iOS 17 | `ErrorStateView` customizada |
| `.environment()` com Observable | iOS 17 | `@EnvironmentObject` |

### Geral
- Nenhum import SwiftUI fora de Views
- `async/await` para concorrencia — prefira sobre Combine para novas features
- Dependency Inversion — ViewModels dependem de protocolos, nao de implementacoes concretas
- Unidirectional Data Flow — View observa ViewModel, ViewModel atualiza estado, View re-renderiza

## Checklist de Revisao

- [ ] Struct conforma com `View` (nunca `class`)
- [ ] Sem logica de negocio no `body`
- [ ] `@StateObject` com init injetavel para suportar previews
- [ ] Subviews extraidas quando body > 40 linhas
- [ ] `switch` exaustivo sobre `ViewState` (todos os 4 casos tratados)
- [ ] `.task {}` usado para carregamento async (nao `onAppear`)
- [ ] `NavigationView` + `.navigationViewStyle(.stack)` (nunca `NavigationStack`)
- [ ] `NavigationLink(destination:)` (nunca `NavigationLink(value:)`)
- [ ] `ErrorStateView` presente em `Views/Shared/`
- [ ] `ViewState.swift` presente em `Utilities/`
- [ ] `#Preview` funcional com pelo menos estado de sucesso
- [ ] Diretorio `Components/` criado para subcomponentes futuros
