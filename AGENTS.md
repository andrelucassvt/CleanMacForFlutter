# AGENTS.md

Este arquivo fornece orientações para agentes de IA (Codex, OpenAI Agents) ao trabalhar com código neste repositório.

## Sobre Este Repositório

Repositório de **templates de instruções e skills para projetos SwiftUI iOS** usando o padrão MVVM. Não é um app executável — contém arquivos de instrução reutilizáveis, skills e um script de sincronização distribuídos para projetos SwiftUI reais.

## Estrutura do Repositório

- `.agents/skills/` — Skills de scaffolding que geram código SwiftUI (model, view, view-model, repository, service, navigation, animation, performance, liquid-glass, macos)
- `.github/` e `.claude/` — Espelhos das skills/instruções para GitHub Copilot e Claude Code
- `sync-instructions.sh` — Script que clona este repo e distribui arquivos para projetos-alvo
- `skills-lock.json` — Rastreia dependências de skills externas (ex: `avdlee/swiftui-agent-skill`)

## Arquitetura: MVVM para SwiftUI (iOS 15+)

Mandato arquitetural definido em `mvvm-architecture-instructions.md`:

- **Target mínimo: iOS 15** — use `NavigationView` (não `NavigationStack`), `ObservableObject` (não `@Observable`), `@StateObject`/`@ObservedObject` (não `@Bindable`)
- **Enum ViewState\<T\>** — todo estado async em ViewModels deve usar `ViewState<T>` (.idle/.loading/.success/.error), nunca booleans avulsos
- **Sem import SwiftUI fora de Views** — Models, ViewModels, Repositories e Services usam apenas Foundation/Combine
- **@MainActor em todos os ViewModels** — obrigatório para atualizações thread-safe de UI
- **Injeção de dependência via init** — todas as dependências externas injetadas via inicializador para testabilidade
- **Padrão Repository** — Protocol + implementação concreta abstraindo fontes de dados
- **Swift Testing framework** — testes usam `@Test`, `@Suite`, `#expect` (não XCTest)

## Script de Sincronização

`sync-instructions.sh` copia arquivos deste repo para projetos-alvo:
```
./sync-instructions.sh
```
Clona este repo para um diretório temporário e faz rsync de instruções/skills para `.github/`, `.claude/` e `.agents/` do projeto-alvo. Também se auto-atualiza.

## Skills

Cada skill em `.agents/skills/<nome>/SKILL.md` é um template de prompt que gera código scaffolding:

| Skill | Gera |
|-------|------|
| `model` | Structs Codable/Identifiable com CodingKeys e dados mock |
| `view` | Views SwiftUI com switch ViewState, previews e binding de ViewModel |
| `view-model` | @MainActor ObservableObject com ViewState e DI |
| `repository` | Protocol + implementação + mock para acesso a dados |
| `service` | APIClient/Endpoint/NetworkError ou serviços de storage |
| `navigation` | AppRouter, enum Route, setup NavigationView |
| `animation` | Padrões de animação com APIs adequadas à versão do iOS |
| `performance` | Checklist de auditoria de Views e padrões de otimização |
| `liquid-glass` | Efeitos Liquid Glass (iOS 26) com fallbacks de material |
| `macos` | Scenes, windows e interop AppKit específicos do macOS |

## Convenções de Nomenclatura

- Views: `*View` (ex: `HomeView`, `ProductCardView`)
- ViewModels: `*ViewModel` (ex: `HomeViewModel`)
- Repositories: `*Repository` / `*RepositoryProtocol`
- Extensions: `Type+Context` (ex: `View+Extensions`)
- Models: substantivos simples (ex: `User`, `Product`)
