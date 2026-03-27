---
name: model
description: Cria uma nova Model (struct) seguindo os padroes MVVM do projeto SwiftUI. Use quando o usuario pedir para criar um novo modelo, entidade ou struct de dados.
argument-hint: <NomeDaModel> (ex: Product)
---

Crie uma nova Model SwiftUI seguindo os padroes MVVM do projeto.

## Argumentos

Nome da Model em PascalCase: `$ARGUMENTS`

Se `$ARGUMENTS` estiver vazio, pergunte: "Qual o nome da Model? (ex: `Product`, `Order`, `Address`)"

Pergunte ao usuario:
1. Quais propriedades a Model deve ter? (nome e tipo de cada uma)
2. A API retorna nomes diferentes das propriedades Swift? (snake_case, etc.) — padrao: sim, usar `CodingKeys`
3. Precisa de dados mockados para Preview? (padrao: sim)

## O que criar

Crie os arquivos no diretorio `Models/`:

### 1. `Models/<PascalCase>.swift`

```swift
import Foundation

struct <PascalCase>: Codable, Identifiable, Equatable {
    let id: String
    // Propriedades informadas pelo usuario

    enum CodingKeys: String, CodingKey {
        case id
        // Mapeamentos snake_case -> camelCase conforme necessario
    }
}
```

**Regras da Model:**

- Sempre `struct`, nunca `class`
- Propriedades sempre `let` (imutavel) — use `var` apenas se houver necessidade explicita de mutacao
- Conformar com `Codable`, `Identifiable` e `Equatable` no minimo
- Adicionar `Hashable` se a Model for usada em `ForEach` sem keypath, `Set`, ou como valor de `NavigationLink`
- Sem logica de negocio — apenas dados
- Sem `import SwiftUI` — apenas `import Foundation`
- Usar `CodingKeys` quando qualquer propriedade da API usar nomenclatura diferente (ex: `snake_case`)
- Propriedades opcionais (`?`) para campos que podem vir `null` da API
- Usar tipos adequados: `URL` para URLs, `Date` para datas, `Decimal` para valores monetarios
- `id: UUID` para objetos criados localmente; `id: String` ou `id: Int` para objetos vindos de API

### 2. `Preview Content/PreviewData+<PascalCase>.swift` (se solicitado)

Extension com dados mockados para uso em Previews:

```swift
import Foundation

extension <PascalCase> {
    static let mock = <PascalCase>(
        id: "1",
        // Dados mockados realistas
    )

    static let mockList: [<PascalCase>] = [
        .mock,
        <PascalCase>(
            id: "2",
            // Segundo item mockado
        ),
        <PascalCase>(
            id: "3",
            // Terceiro item mockado
        ),
    ]
}
```

## Apos criar os arquivos

Informe o usuario sobre os proximos passos comuns:
1. Criar o Repository correspondente em `Repositories/<PascalCase>Repository.swift` com protocolo + implementacao
2. Criar o ViewModel que consome essa Model em `ViewModels/`
3. Criar a View que exibe essa Model em `Views/`
4. Se a Model tiver `Date`, garantir que o `JSONDecoder` usa `.iso8601` como `dateDecodingStrategy`

## Regras

- Sem `import SwiftUI` — apenas `import Foundation`
- Structs imutaveis com `let` — nunca `class` ou `var` sem necessidade
- Conformar com `Codable`, `Identifiable`, `Equatable` no minimo
- Usar `CodingKeys` quando a API retorna nomes diferentes (snake_case -> camelCase)
- Propriedades opcionais para campos que podem ser `null`
- Dados mockados devem ser realistas e variados
- Nao adicionar metodos de logica de negocio na Model
- Usar tipos Swift adequados (`URL`, `Date`, `Decimal`) ao inves de `String` generico
- `id: UUID` para objetos criados localmente; `id: String` ou `id: Int` para objetos de API

## Checklist de Revisao

- [ ] `struct` imutavel com `let` (nunca `class`)
- [ ] Conforma com `Codable`, `Identifiable`, `Equatable` no minimo
- [ ] `Hashable` adicionado se usada em `Set`, `ForEach` sem keypath, ou `NavigationLink(value:)`
- [ ] Sem `import SwiftUI` — apenas `import Foundation`
- [ ] Sem logica de negocio — apenas dados
- [ ] `CodingKeys` presente quando a API usa nomes diferentes das propriedades Swift
- [ ] Campos opcionais (`?`) para propriedades que podem ser `null`
- [ ] Tipos corretos: `URL`, `Date`, `Decimal` ao inves de `String` generico
- [ ] `PreviewData` criado com `mock` e `mockList` com dados realistas e variados
