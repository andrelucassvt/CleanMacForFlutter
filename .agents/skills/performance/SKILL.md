---
name: performance
description: Otimiza performance de views SwiftUI — atualizacoes de estado, lazy loading, identidade em listas, otimizacao de imagens, e depuracao de re-renders inesperados. Use quando o usuario reportar lentidao, lag em scroll, travamentos, ou quiser auditar o desempenho de uma view.
argument-hint: audit | images | lists | state | debug
---

Audite e otimize a performance de codigo SwiftUI seguindo as melhores praticas.

## Argumentos

Tipo de otimizacao: `$ARGUMENTS`

Se `$ARGUMENTS` estiver vazio, pergunte:
- "Qual aspecto de performance precisa otimizar?"
  - `audit` — revisao geral de uma view ou componente
  - `state` — atualizacoes de estado desnecessarias, dependencias largas
  - `lists` — scroll lento, lazy loading, identidade em ForEach
  - `images` — memoria alta, imagens grandes, downsampling
  - `debug` — identificar qual estado esta causando re-renders

---

## Opcao 1: `audit` — Revisao geral

Execute o seguinte checklist sobre a view em questao e aponte cada violacao encontrada:

### Anti-patterns para detectar

#### Objeto criado dentro do `body`
```swift
// ERRADO — cria novo formatter a cada render
var body: some View {
    let formatter = DateFormatter()
    return Text(formatter.string(from: date))
}

// CORRETO — static lazy
private static let dateFormatter: DateFormatter = {
    let f = DateFormatter()
    f.dateStyle = .long
    return f
}()

var body: some View {
    Text(Self.dateFormatter.string(from: date))
}
```

#### Computacao pesada dentro do `body`
```swift
// ERRADO — ordena a cada render
var body: some View {
    List(items.sorted { $0.name < $1.name }) { ... }
}

// CORRETO — ordena uma vez, atualiza via onChange
@State private var sortedItems: [Item] = []

var body: some View {
    List(sortedItems) { ... }
        .onChange(of: items) { _, newItems in
            sortedItems = newItems.sorted { $0.name < $1.name }
        }
}
```

> Mova sorting, filtering e formatting para o ViewModel ou computed properties. O `body` deve ser pura representacao estrutural do estado.

#### Estado derivado armazenado desnecessariamente
```swift
// ERRADO — itemCount sincronizado manualmente e propenso a bugs
@State private var items: [Item] = []
@State private var itemCount: Int = 0

// CORRETO — valor derivado como computed property
@State private var items: [Item] = []
var itemCount: Int { items.count }
```

#### Update de estado sem verificacao de mudanca
```swift
// ERRADO — dispara re-render mesmo quando o valor e igual
.onReceive(publisher) { value in
    self.currentValue = value
}

// CORRETO — verifica antes de atribuir
.onReceive(publisher) { value in
    if self.currentValue != value {
        self.currentValue = value
    }
}
```

#### Animacao em hot path
```swift
// ERRADO — dispara withAnimation a cada frame de scroll
.onPreferenceChange(ScrollOffsetKey.self) { offset in
    withAnimation { self.offset = offset.y }
}

// CORRETO — anima apenas ao cruzar threshold
.onPreferenceChange(ScrollOffsetKey.self) { offset in
    let shouldShow = offset.y < -50
    if shouldShow != showTitle {
        withAnimation(.easeOut(duration: 0.2)) { showTitle = shouldShow }
    }
}
```

#### Escopo de animacao muito amplo
```swift
// ERRADO — anima o container inteiro
VStack {
    HeaderView()
    ExpandableContent(isExpanded: isExpanded)
    FooterView()
}
.animation(.spring, value: isExpanded)

// CORRETO — anima apenas a subview que muda
VStack {
    HeaderView()
    ExpandableContent(isExpanded: isExpanded)
        .animation(.spring, value: isExpanded)
    FooterView()
}
```

#### Closures off-main-thread acessando estado @MainActor
```swift
// ERRADO — erro de compilacao ou comportamento indefinido
.visualEffect { content, geometry in
    content.blur(radius: self.pulse ? 5 : 0)
}

// CORRETO — capture o valor
.visualEffect { [pulse] content, geometry in
    content.blur(radius: pulse ? 5 : 0)
}
```

> Closures que podem rodar fora da main thread: `Shape.path(in:)`, `visualEffect`, `Layout` protocol, `onGeometryChange` transform.

---

## Opcao 2: `state` — Dependencias de estado

### Passe apenas o que a view precisa

```swift
// ERRADO — dependencia ampla no model inteiro
struct ItemRow: View {
    @Environment(AppModel.self) private var model
    let item: Item

    var body: some View {
        Text(item.name).foregroundStyle(model.theme.primaryColor)
        // Qualquer mudanca em AppModel re-renderiza esta row
    }
}

// CORRETO — dependencia estreita
struct ItemRow: View {
    let item: Item
    let themeColor: Color  // So depende desta cor

    var body: some View {
        Text(item.name).foregroundStyle(themeColor)
    }
}
```

### ViewModel por item em listas (iOS 17+ com @Observable)

```swift
// ERRADO — mudar um favorito re-renderiza todas as rows
@Observable class ModelData {
    var favorites: [Landmark] = []
}

struct LandmarkRow: View {
    @Environment(ModelData.self) private var model
    let landmark: Landmark
    var body: some View {
        // Qualquer mudanca em favorites re-renderiza TODAS as rows
        if model.favorites.contains(landmark) { ... }
    }
}

// CORRETO — cada row tem seu proprio observable
@Observable class LandmarkViewModel {
    var isFavorite: Bool = false
}

struct LandmarkRow: View {
    let landmark: Landmark
    let viewModel: LandmarkViewModel  // So re-renderiza quando isFavorite muda
    var body: some View {
        if viewModel.isFavorite { ... }
    }
}
```

> Requer `@Observable` (iOS 17+). Gateie com `#available(iOS 17, *)` ou mantenha o padrao `ObservableObject` para iOS 15.

### Views Equatable para bodies caros

```swift
struct ExpensiveView: View, Equatable {
    let data: SomeData

    static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.data.id == rhs.data.id  // Controle preciso de igualdade
    }

    var body: some View { /* computacao cara */ }
}

// Uso
ExpensiveView(data: data).equatable()
```

> Cuidado: se adicionar novas dependencias a view, atualize o `==`.

### Views POD (Plain Old Data) para diffing rapido

Views com apenas `let` e sem property wrappers usam `memcmp` — o diffing mais rapido possivel.

```swift
// POD — diffing por memcmp (rapido)
struct FastRow: View {
    let title: String
    let count: Int
    var body: some View { Text("\(title): \(count)") }
}

// Padrao avancado: wrapper POD para view interna com @State
struct ExpensiveView: View {
    let value: Int  // So este campo e comparado
    var body: some View { ExpensiveViewInternal(value: value) }
}

private struct ExpensiveViewInternal: View {
    let value: Int
    @State private var item: Item?  // Estado interno nao polui o wrapper
    var body: some View { /* rendering caro */ }
}
```

---

## Opcao 3: `lists` — Listas e scroll

### Lazy containers obrigatorios para listas longas

```swift
// ERRADO — cria todas as views de uma vez
ScrollView {
    VStack {
        ForEach(items) { item in ExpensiveRow(item: item) }
    }
}

// CORRETO — cria views sob demanda
ScrollView {
    LazyVStack {
        ForEach(items) { item in ExpensiveRow(item: item) }
    }
}
```

### Identidade estavel em ForEach

```swift
// ERRADO — indices sao instáveis (insercao/remocao muda os indices)
ForEach(items.indices, id: \.self) { index in
    ItemRow(item: items[index])
}

// CORRETO — ID estavel do modelo
ForEach(items) { item in  // Item: Identifiable com id estavel
    ItemRow(item: item)
}

// CORRETO — keypath explicito quando necessario
ForEach(items, id: \.stableID) { item in
    ItemRow(item: item)
}
```

> Identidade instavel causa transicoes erradas, scroll jumps e re-renders completos da lista.

### Task por item para cancelamento correto

```swift
// CORRETO — task cancela automaticamente ao view desaparecer
List(items) { item in
    ItemRow(item: item)
        .task(id: item.id) {
            await item.loadDetails()  // Cancela se item sair da tela
        }
}
```

---

## Opcao 4: `images` — Imagens e memoria

### AsyncImage com tratamento de todos os estados

```swift
AsyncImage(url: imageURL) { phase in
    switch phase {
    case .empty:
        ProgressView()
            .frame(width: 200, height: 200)
    case .success(let image):
        image
            .resizable()
            .aspectRatio(contentMode: .fill)
            .transition(.opacity)
    case .failure:
        Image(systemName: "photo")
            .foregroundStyle(.secondary)
            .frame(width: 200, height: 200)
    @unknown default:
        EmptyView()
    }
}
.animation(.easeInOut, value: imageURL)
```

### Downsampling para UIImage(data:) (otimizacao opcional)

> Sugira quando encontrar `UIImage(data:)` em listas, grids ou galerias.

```swift
// ANTES — decodifica imagem completa na main thread
Image(uiImage: UIImage(data: imageData)!)

// DEPOIS — decodifica e faz downsample em background
struct DownsampledImage: View {
    let imageData: Data
    let targetSize: CGSize
    @State private var image: UIImage?

    var body: some View {
        Group {
            if let image {
                Image(uiImage: image).resizable().aspectRatio(contentMode: .fill)
            } else {
                ProgressView()
            }
        }
        .task {
            image = await downsample(imageData, to: targetSize)
        }
    }

    private func downsample(_ data: Data, to size: CGSize) async -> UIImage? {
        await Task.detached {
            let sourceOptions: [CFString: Any] = [kCGImageSourceShouldCache: false]
            guard let source = CGImageSourceCreateWithData(data as CFData, sourceOptions as CFDictionary) else { return nil }

            let scale = await UIScreen.main.scale
            let maxPixel = max(size.width, size.height) * scale
            let options: [CFString: Any] = [
                kCGImageSourceCreateThumbnailFromImageAlways: true,
                kCGImageSourceThumbnailMaxPixelSize: maxPixel,
                kCGImageSourceCreateThumbnailWithTransform: true,
                kCGImageSourceShouldCacheImmediately: true
            ]
            guard let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else { return nil }
            return UIImage(cgImage: cgImage)
        }.value
    }
}
```

> `kCGImageSourceShouldCache: false` evita cache da imagem em tamanho original.
> `kCGImageSourceShouldCacheImmediately: true` forca decodificacao na criacao (nao no primeiro render).

### UIImage(named:) vs UIImage(contentsOfFile:)

```swift
// UIImage(named:) — adiciona ao cache do sistema (acumula memoria em galerias)
let image = UIImage(named: "Wallpapers/photo_001.jpg")

// UIImage(contentsOfFile:) — sem cache do sistema (preferir para imagens de uso unico)
if let path = Bundle.main.path(forResource: "Wallpapers/photo_001", ofType: "jpg") {
    let image = UIImage(contentsOfFile: path)
}
```

### NSCache com limite definido

```swift
// Para imagens processadas (resize, filtro) — cache controlado
private let imageCache: NSCache<NSString, UIImage> = {
    let cache = NSCache<NSString, UIImage>()
    cache.countLimit = 50  // Maximo de 50 imagens em memoria
    return cache
}()
```

---

## Opcao 5: `debug` — Identificar re-renders

### Self._logChanges() / Self._printChanges()

```swift
struct MinhaView: View {
    var body: some View {
        #if DEBUG
        let _ = Self._logChanges()   // iOS 17+ — loga no subsystem com.apple.SwiftUI
        // let _ = Self._printChanges()  // Alternativa: imprime no console
        #endif

        // corpo da view...
    }
}
```

- `_printChanges()` — imprime no stdout qual propriedade mudou
- `_logChanges()` — loga via `os_log` (visivel no Console.app e Instruments)
- Ambos imprimem `@self` quando o valor da view mudou e `@identity` quando a identidade persistente foi reciclada

### Estrategia de diagnostico

1. Adicione `Self._logChanges()` na view suspeita
2. Identifique qual propriedade dispara o re-render inesperado
3. Extraia a parte que muda em uma subview separada — SwiftUI pode pular o body de subviews quando os inputs nao mudaram
4. Se o re-render for de um estado derivado, converta para computed property
5. Se for de dependencia ampla, estreite passando apenas os valores necessarios
6. Profile com **Instruments > SwiftUI template** para bottlenecks persistentes

### Problemas comuns identificados por _logChanges

| Log impresso | Causa provavel | Solucao |
|---|---|---|
| `@self changed` | Valor da view recriado pelo pai | Extrair subview ou usar `.equatable()` |
| `@identity changed` | Identidade reciclada | Verificar estabilidade do `id` no ForEach |
| `somePublished changed` | `@Published` atualizado frequentemente | Verificar igualdade antes de atribuir |
| `environment changed` | Valor no environment mudando | Evitar valores de alta frequencia no environment |

---

## Checklist de Revisao

### Hard rules
- [ ] Nenhum objeto criado dentro do `body` (`DateFormatter`, `NumberFormatter`, etc.)
- [ ] Nenhuma computacao pesada no `body` (sort, filter, decode) — mover para ViewModel ou `onChange`
- [ ] Nenhum estado derivado armazenado como `@State` — usar computed property
- [ ] `ForEach` usa ID estavel — nunca `.indices` para conteudo dinamico
- [ ] Updates de estado verificam igualdade antes de atribuir em hot paths

### Performance
- [ ] Listas com muitos itens usam `LazyVStack`/`LazyHStack` dentro de `ScrollView`
- [ ] Animacoes em hot paths (scroll, timer) gateadas por threshold — nao disparam a cada frame
- [ ] Escopo de `.animation(_:value:)` limitado a subview que realmente muda
- [ ] Closures off-main-thread (`visualEffect`, `Shape.path`) usam capture list em vez de `self`
- [ ] `UIImage(data:)` em listas sugerido para downsampling off-main-thread

### Diagnostico
- [ ] `Self._logChanges()` adicionado em `#if DEBUG` ao investigar re-renders
- [ ] Dependencias de `@Environment` e `@Observable` estreitadas ao minimo necessario
- [ ] Views caras com inputs estaveis consideram `.equatable()` ou wrapper POD
