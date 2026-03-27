# Copilot Instructions

Instruções para GitHub Copilot ao trabalhar com projetos que usam este template de arquitetura SwiftUI MVVM.

## Contexto

Este é um repositório de templates de instruções e skills para projetos SwiftUI iOS com padrão MVVM. Não é um app executável.

## Arquitetura: MVVM para SwiftUI (iOS 15+)

### Regras Obrigatórias

- **Target mínimo: iOS 15** — use `NavigationView` (não `NavigationStack`), `ObservableObject` (não `@Observable`), `@StateObject`/`@ObservedObject` (não `@Bindable`)
- **Enum ViewState\<T\>** — todo estado async em ViewModels deve usar `ViewState<T>` (.idle/.loading/.success/.error), nunca booleans avulsos
- **Sem import SwiftUI fora de Views** — Models, ViewModels, Repositories e Services usam apenas Foundation/Combine
- **@MainActor em todos os ViewModels** — obrigatório para atualizações thread-safe de UI
- **Injeção de dependência via init** — todas as dependências externas injetadas via inicializador
- **Padrão Repository** — Protocol + implementação concreta abstraindo fontes de dados
- **Swift Testing framework** — testes usam `@Test`, `@Suite`, `#expect` (não XCTest)

### Compatibilidade iOS 15+

| Usar | NÃO usar (requer iOS 16/17) |
|------|-----------------------------|
| `ObservableObject` + `@Published` | `@Observable` (iOS 17) |
| `@StateObject` / `@ObservedObject` | `@State` com class / `@Bindable` (iOS 17) |
| `NavigationView` + `.navigationViewStyle(.stack)` | `NavigationStack` (iOS 16) |
| `NavigationLink(destination:)` | `NavigationLink(value:)` (iOS 16) |
| `@EnvironmentObject` | `.environment()` com Observable (iOS 17) |
| `Combine` no ViewModel | `Observation` framework (iOS 17) |

### Convenções de Nomenclatura

- Views: `*View` (ex: `HomeView`, `ProductCardView`)
- ViewModels: `*ViewModel` (ex: `HomeViewModel`)
- Repositories: `*Repository` / `*RepositoryProtocol`
- Extensions: `Type+Context` (ex: `View+Extensions`)
- Models: substantivos simples (ex: `User`, `Product`)

### Princípios

1. **Single Responsibility** — cada camada tem uma única responsabilidade
2. **Dependency Inversion** — ViewModels dependem de protocolos, não de implementações concretas
3. **Unidirectional Data Flow** — View observa ViewModel, ViewModel atualiza estado, View re-renderiza
4. **Testabilidade** — toda dependência externa é injetável via init
5. **async/await** — prefira concorrência estruturada ao invés de Combine para novas features
6. **Previews** — toda View deve ter um `#Preview` funcional com dados mockados
7. **Componentes** — extrair subviews quando body ultrapassa ~40 linhas

### Estrutura de Pastas Padrão

```
ProjectName/
├── App/                  # @main entry point, AppDelegate
├── Models/               # Structs imutáveis Codable
├── ViewModels/           # @MainActor ObservableObject
├── Views/                # SwiftUI Views organizadas por feature
│   ├── Home/Components/
│   ├── Profile/Components/
│   └── Shared/           # Componentes reutilizáveis
├── Services/Networking/  # APIClient, Endpoint, NetworkError
├── Services/Storage/     # Keychain, UserDefaults
├── Repositories/         # Protocol + implementação
├── Extensions/           # Type+Context
├── Utilities/            # Constants, ViewState, Formatters
└── Resources/            # Assets, Localizable
```

## Skills Disponíveis

Skills em `.github/skills/<nome>/SKILL.md` geram código scaffolding: model, view, view-model, repository, service, navigation, animation, performance, liquid-glass, macos.
