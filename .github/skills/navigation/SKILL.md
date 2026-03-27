---
name: navigation
description: Configura a navegacao SwiftUI seguindo o padrao MVVM do projeto (iOS 15+). Use quando o usuario pedir para criar o AppRouter, adicionar rotas, configurar NavigationView, ou implementar navegacao programatica.
argument-hint: router | route <NomeDaRota> | setup
---

Crie ou atualize a camada de navegacao seguindo o padrao MVVM do projeto. Target minimo: **iOS 15**.

## Argumentos

Tipo de operacao: `$ARGUMENTS`

Se `$ARGUMENTS` estiver vazio, pergunte:
- "O que precisa fazer com navegacao?"
  - `setup` — criar a estrutura completa de navegacao (AppRouter + AppRootView + Route enum)
  - `route <Nome>` — adicionar uma nova rota ao `AppRouter` existente
  - `router` — apenas criar/recriar o `AppRouter`

---

## Regra fundamental de compatibilidade

| Usar | NAO usar (requer iOS 16+) |
|------|---------------------------|
| `NavigationView` + `.navigationViewStyle(.stack)` | `NavigationStack` |
| `NavigationLink(destination:)` | `NavigationLink(value:)` |
| `@EnvironmentObject` para o router | `navigationDestination(for:)` |
| `ObservableObject` + `@Published` | `NavigationPath` |

> **iOS 16+ migration note**: Quando o target minimo for atualizado para iOS 16+, migre para `NavigationStack` + `NavigationPath` + `navigationDestination(for:)` + `NavigationLink(value:)`.

---

## O que criar

### Opcao 1: `setup` — Estrutura completa de navegacao

Crie 3 arquivos:

#### `App/AppRootView.swift`

```swift
import SwiftUI

struct AppRootView: View {

    @StateObject private var router = AppRouter()

    var body: some View {
        NavigationView {
            HomeView()
        }
        .navigationViewStyle(.stack)
        .environmentObject(router)
    }
}

#Preview {
    AppRootView()
}
```

> Substitua `HomeView()` pela tela inicial real do projeto.

---

#### `App/AppRouter.swift`

```swift
import Foundation

final class AppRouter: ObservableObject {

    // MARK: - State

    @Published var activeRoute: Route?

    // MARK: - Actions

    func navigate(to route: Route) {
        activeRoute = route
    }

    func pop() {
        activeRoute = nil
    }

    func popToRoot() {
        activeRoute = nil
    }
}
```

---

#### `App/Route.swift`

```swift
import Foundation

enum Route: Hashable {
    // Adicione os casos conforme as telas do projeto
    // Exemplo:
    // case profile(User)
    // case productDetail(Product)
    // case settings
    // case createProduct
}
```

> Cada caso do enum representa uma rota possivel. Use associated values para passar dados entre telas.

---

### Opcao 2: `route <Nome>` — Adicionar nova rota

Adicione o caso ao enum `Route` existente e o `NavigationLink` correspondente na View de origem.

#### Em `App/Route.swift`:

```swift
// Adicionar:
case <nome>(<Model>)     // se precisar passar dados
// ou
case <nome>             // se nao precisar passar dados
```

#### Na View de origem, adicionar o link:

```swift
// Dentro de List ou VStack:
NavigationLink(destination: <Nome>View(<parametros>)) {
    <CelulaOuBotao>
}

// Ou navegacao programatica via router (para acoes de botao):
Button("Ir para <Nome>") {
    router.navigate(to: .<nome>(<dados>))
}

// E no body da View raiz, observar a rota ativa:
NavigationLink(
    destination: destinationView(),
    isActive: Binding(
        get: { router.activeRoute == .<nome>(<dados>) },
        set: { if !$0 { router.pop() } }
    )
) {
    EmptyView()
}
```

---

### Padrao de navegacao programatica

Para acionar navegacao a partir do ViewModel (ex: apos salvar com sucesso), use um `@Published` dedicado na View:

```swift
// No ViewModel:
@Published private(set) var shouldNavigateToDetail: <Model>? = nil

func save() async {
    // ... logica de salvar ...
    shouldNavigateToDetail = savedItem
}

// Na View, observando o ViewModel:
.onChange(of: viewModel.shouldNavigateToDetail) { item in
    guard let item else { return }
    router.navigate(to: .detail(item))
}
```

---

### Padrao de Sheet / Modal

Para apresentar telas como sheet (nao como push de navegacao):

```swift
// Na View:
@State private var presentedRoute: Route? = nil

// No body:
.sheet(item: $presentedRoute) { route in
    switch route {
    case .createProduct:
        CreateProductView()
    default:
        EmptyView()
    }
}

// Para abrir:
Button("Novo Produto") {
    presentedRoute = .createProduct
}
```

> Use `.sheet` para fluxos de criacao/edicao e `NavigationLink` para fluxos de detalhamento.

---

### Estrutura de pastas recomendada

```
App/
├── ProjectNameApp.swift    # @main entry point
├── AppRootView.swift       # NavigationView raiz + .environmentObject(router)
├── AppRouter.swift         # ObservableObject com activeRoute
└── Route.swift             # enum Route: Hashable
```

---

## Como usar o router nas Views

```swift
struct HomeView: View {

    @EnvironmentObject private var router: AppRouter

    var body: some View {
        List(items) { item in
            NavigationLink(destination: DetailView(item: item)) {
                ItemRowView(item: item)
            }
        }
        .navigationTitle("Inicio")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Configuracoes") {
                    router.navigate(to: .settings)
                }
            }
        }
    }
}
```

> Se a View nao precisa de navegacao programatica, use `NavigationLink` diretamente sem o router.

---

## Entry point (`@main`)

Garanta que `AppRootView` e o entry point do app:

```swift
import SwiftUI

@main
struct ProjectNameApp: App {
    var body: some Scene {
        WindowGroup {
            AppRootView()
        }
    }
}
```

---

## Apos criar os arquivos

Informe o usuario que ainda precisa:
1. Substituir `HomeView()` em `AppRootView` pela tela inicial real
2. Adicionar os casos reais ao enum `Route` conforme as telas do projeto
3. Garantir que `ProjectNameApp.swift` usa `AppRootView()` no `WindowGroup`
4. Para cada tela filha que usa navegacao programatica, injetar o router via `@EnvironmentObject private var router: AppRouter`

---

## Regras

- `AppRouter` e `ObservableObject` — nunca `@Observable` (requer iOS 17)
- `NavigationView` + `.navigationViewStyle(.stack)` — nunca `NavigationStack` (requer iOS 16)
- `NavigationLink(destination:)` — nunca `NavigationLink(value:)` (requer iOS 16)
- Router injetado via `.environmentObject` a partir do `AppRootView` — nunca instanciado diretamente nas Views filhas
- Views filhas recebem o router via `@EnvironmentObject` — nunca via `init`
- `Route` como `enum` com `Hashable` — suporta associated values para dados
- Logica de navegacao no ViewModel via `@Published` — View observa e chama `router.navigate`
- Sem `import SwiftUI` no `AppRouter` e no `Route` — apenas `Foundation`

---

## Checklist de Revisao

- [ ] `AppRouter` e `final class` com `ObservableObject` (nunca `@Observable`)
- [ ] `AppRouter` sem `import SwiftUI` — apenas `Foundation`
- [ ] `Route` sem `import SwiftUI` — apenas `Foundation`
- [ ] `Route` conforma com `Hashable`
- [ ] `AppRootView` usa `NavigationView` + `.navigationViewStyle(.stack)` (nunca `NavigationStack`)
- [ ] `AppRootView` injeta `.environmentObject(router)`
- [ ] `@main` entry point usa `AppRootView()` no `WindowGroup`
- [ ] Views filhas recebem o router via `@EnvironmentObject` (nunca via `init`)
- [ ] `NavigationLink(destination:)` usado (nunca `NavigationLink(value:)`)
- [ ] Apresentacao de sheets via `@State private var presentedRoute: Route?`
- [ ] Navegacao programatica do ViewModel via `@Published` observado na View
