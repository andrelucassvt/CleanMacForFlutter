---
name: macos
description: >
  Implementa funcionalidades específicas de macOS em apps SwiftUI — Scenes (Settings, MenuBarExtra,
  WindowGroup, Window, UtilityWindow, DocumentGroup), estilos de janela e toolbar, NavigationSplitView,
  Inspector, Commands, HSplitView, Table, operações de arquivo, drag-drop entre apps, e interop AppKit.
  Use quando o usuário precisar de qualquer API exclusiva ou com comportamento diferenciado no macOS.
argument-hint: >
  Informe o modo desejado:
    • scenes   — criar/configurar cenas do app (Settings, MenuBarExtra, WindowGroup, Window, UtilityWindow, DocumentGroup)
    • window   — toolbar styles, sizing, Inspector, NavigationSplitView, Commands/atalhos de teclado
    • views    — HSplitView/VSplitView, Table, PasteButton, operações de arquivo, drag-drop, NSViewRepresentable
  Se não especificado, pergunte ao usuário qual modo usar.
---

# Skill: macOS

Você é um especialista em APIs SwiftUI específicas do macOS.  
**Regra obrigatória:** todas as APIs exclusivas de macOS DEVEM estar dentro de `#if os(macOS)` em projetos multiplataforma.

---

## Identificação do Modo

Se `$ARGUMENTS` não especificar o modo, pergunte:

> "Qual aspecto macOS você quer implementar?
> - **scenes** — configurar cenas do app (Settings, MenuBarExtra, Window…)
> - **window** — estilos de toolbar/janela, Inspector, NavigationSplitView, Commands
> - **views** — HSplitView, Table, arquivos, drag-drop, NSViewRepresentable"

---

## Modo: `scenes`

### Antes de criar

1. Leia o `@main` App atual para entender as cenas existentes.
2. Identifique qual cena adicionar ou ajustar.
3. Wrap sempre em `#if os(macOS)` quando o projeto é multiplataforma.

---

### Referência de Cenas

| Cena | Disponibilidade | macOS-only? | Uso |
|------|----------------|:-----------:|-----|
| `WindowGroup` | macOS 11.0+ | Não | Múltiplas janelas, tabs, Window menu automático |
| `Window` | macOS 13.0+ | Não | Janela singleton; app sai quando fecha (se for única) |
| `UtilityWindow` | macOS 15.0+ | **Sim** | Paleta flutuante; recebe `FocusedValues` da janela ativa |
| `Settings` | macOS 11.0+ | **Sim** | Janela de preferências (Cmd+,) |
| `MenuBarExtra` | macOS 13.0+ | **Sim** | Ícone/menu persistente na barra de menus |
| `DocumentGroup` | macOS 11.0+ | Não | Menus File automáticos; múltiplos documentos |

---

### Settings

```swift
#if os(macOS)
Settings {
    TabView {
        Tab("General", systemImage: "gear") { GeneralSettingsView() }
        Tab("Advanced", systemImage: "star") { AdvancedSettingsView() }
    }
    .scenePadding()
    .frame(maxWidth: 350, minHeight: 100)
}
#endif
```

**Abrir programaticamente (macOS 14.0+):**
```swift
struct OpenSettingsButton: View {
    @Environment(\.openSettings) private var openSettings

    var body: some View {
        Button("Preferências") { openSettings() }
    }
}
```

**SettingsLink (macOS 14.0+):**
```swift
SettingsLink {
    Label("Preferências", systemImage: "gear")
}
```

---

### MenuBarExtra

**Estilo menu (dropdown):**
```swift
#if os(macOS)
MenuBarExtra("MyApp", systemImage: "hammer") {
    Button("Ação") { /* ... */ }
    Divider()
    Button("Sair") { NSApplication.shared.terminate(nil) }
}
#endif
```

**Estilo window (painel popover):**
```swift
#if os(macOS)
MenuBarExtra("Status", systemImage: "chart.bar") {
    DashboardView()
        .frame(width: 240)
}
.menuBarExtraStyle(.window)
#endif
```

**App somente na barra de menus:**
- Use `MenuBarExtra` como única cena
- Adicione `LSUIElement = YES` no Info.plist para ocultar o ícone no Dock
- O app se encerra automaticamente se o usuário remover o ícone da barra

**Visibilidade controlável:**
```swift
@AppStorage("showMenuBarExtra") private var showMenuBarExtra = true

MenuBarExtra("Status", systemImage: "bolt", isInserted: $showMenuBarExtra) { ... }
```

---

### WindowGroup (macOS)

```swift
@main
struct MyApp: App {
    var body: some Scene {
        // Janela principal (suporta múltiplas instâncias + tabs)
        WindowGroup {
            ContentView()
        }

        // Janela de dados tipados — aberta programaticamente
        WindowGroup("Detalhe", for: Item.ID.self) { $itemID in
            ItemDetailView(itemID: itemID)
        }
    }
}

// Abrir programaticamente
struct OpenButton: View {
    var item: Item
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        Button("Abrir Detalhe") {
            openWindow(value: item.id)
        }
    }
}
```

---

### Window (singleton)

```swift
@main
struct MyApp: App {
    var body: some Scene {
        WindowGroup { ContentView() }

        // Janela singleton suplementar
        Window("Connection Doctor", id: "connection-doctor") {
            ConnectionDoctorView()
        }
    }
}

// Abrir — traz ao frente se já aberta
struct OpenDoctorButton: View {
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        Button("Connection Doctor") {
            openWindow(id: "connection-doctor")
        }
    }
}
```

> Prefira `WindowGroup` para a cena principal. Use `Window` apenas para
> janelas suplementares singleton.

---

### UtilityWindow (macOS 15.0+)

Paleta flutuante que recebe `FocusedValues` da janela principal ativa.

```swift
#if os(macOS)
UtilityWindow("Informações", id: "photo-info") {
    PhotoInfoViewer()
}
#endif

// Dentro da UtilityWindow — reflete seleção da janela ativa
struct PhotoInfoViewer: View {
    @FocusedValue(PhotoSelection.self) private var selectedPhotos

    var body: some View {
        if let photos = selectedPhotos {
            Text("\(photos.count) fotos selecionadas")
        } else {
            Text("Sem seleção").foregroundStyle(.secondary)
        }
    }
}
```

---

### DocumentGroup

```swift
DocumentGroup(newDocument: MyDocument()) { config in
    ContentView(document: config.$document)
}
```

```swift
struct MyDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.plainText] }
    var text: String = ""

    init() {}
    init(configuration: ReadConfiguration) throws {
        text = String(data: configuration.file.regularFileContents ?? Data(),
                      encoding: .utf8) ?? ""
    }
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: Data(text.utf8))
    }
}
```

---

## Modo: `window`

### Toolbar Styles (macOS-only)

Aplique no nível da Scene:

```swift
WindowGroup { ContentView() }
    .windowToolbarStyle(.unified)           // Título + toolbar em uma linha (recomendado)
    .windowToolbarStyle(.unifiedCompact)    // Idem, menor altura vertical
    .windowToolbarStyle(.expanded)          // Título acima da toolbar
    .windowToolbarStyle(.unified(showsTitle: false))  // Sem título
```

**Conteúdo da toolbar na View:**
```swift
.toolbar {
    ToolbarItem(placement: .automatic) {
        Button(action: addItem) {
            Label("Adicionar", systemImage: "plus")
        }
    }
}
.searchable(text: $searchText, placement: .sidebar)
```

---

### Window Sizing & Positioning

```swift
WindowGroup {
    ContentView()
        .frame(minWidth: 600, minHeight: 400)   // Mínimos no conteúdo
}
.defaultSize(width: 900, height: 600)           // Tamanho inicial
.defaultPosition(.center)                       // Posição inicial
.windowResizability(.contentMinSize)            // Usa minWidth/minHeight do frame
```

**`windowResizability` opções:**
| Valor | Comportamento |
|-------|--------------|
| `.automatic` | Sistema decide |
| `.contentSize` | Tamanho fixo, sem redimensione |
| `.contentMinSize` | Redimensionável com mínimo pelo frame |

**Posicionamento preciso (macOS 15.0+):**
```swift
.windowIdealPlacement { context in
    let screen = context.defaultDisplay.visibleArea
    return WindowPlacement(x: screen.midX, y: screen.midY,
                           width: screen.width / 2,
                           height: screen.height)
}
```

---

### Window Style

```swift
// Padrão — barra de título visível
WindowGroup { ContentView() }
    .windowStyle(.titleBar)

// Sem barra de título — janelas imersivas
WindowGroup { ContentView() }
    .windowStyle(.hiddenTitleBar)
```

---

### NavigationSplitView no macOS

No macOS, as colunas são exibidas lado a lado (nunca sobrepostas). A sidebar recebe fundo translúcido automaticamente.

```swift
NavigationSplitView {
    List(items, selection: $selectedID) { item in
        Text(item.name)
    }
    .navigationSplitViewColumnWidth(min: 180, ideal: 220, max: 300)
} detail: {
    DetailView(id: selectedID)
}
.navigationSplitViewStyle(.balanced)
```

**Três colunas:**
```swift
NavigationSplitView {
    SidebarView()
} content: {
    ContentListView(selection: $selectedItem)
} detail: {
    DetailView(item: selectedItem)
}
```

---

### Inspector (macOS 14.0+)

Painel lateral direito redimensionável pelo usuário.

```swift
struct ContentView: View {
    @State private var showInspector = false

    var body: some View {
        MainContent()
            .inspector(isPresented: $showInspector) {
                InspectorView()
                    .inspectorColumnWidth(min: 200, ideal: 250, max: 400)
            }
            .toolbar {
                ToolbarItem {
                    Button {
                        showInspector.toggle()
                    } label: {
                        Label("Inspetor", systemImage: "info.circle")
                    }
                }
            }
    }
}
```

---

### Commands & Atalhos de Teclado

```swift
// Na Scene
.commands {
    CommandMenu("Ferramentas") {
        Button("Executar Análise") { /* ... */ }
            .keyboardShortcut("r", modifiers: [.command, .shift])
    }
    CommandGroup(after: .newItem) {
        Button("Novo Pelo Template…") { /* ... */ }
    }
}
```

**Atalhos em botões:**
```swift
Button("Salvar") { save() }
    .keyboardShortcut("s", modifiers: .command)

Button("Excluir") { delete() }
    .keyboardShortcut(.delete, modifiers: .command)
```

**Posicionamentos de CommandGroup:** `.newItem`, `.saveItem`, `.help`, `.toolbar`, `.sidebar`  
Use `.replacing(_:)` para substituir um grupo do sistema.

---

## Modo: `views`

### HSplitView / VSplitView (macOS-only)

Use para layouts IDE-style onde todos os painéis são pares iguais. Para navegação
sidebar → conteúdo, prefira `NavigationSplitView`.

```swift
HSplitView {
    FileTreeView()
        .frame(minWidth: 200)
    CodeEditorView()
        .frame(minWidth: 400)
    PreviewPane()
        .frame(minWidth: 200)
}
```

`VSplitView` é idêntico mas divide verticalmente (use `minHeight` em vez de `minWidth`).

---

### Table (macOS 12.0+)

```swift
struct PeopleTable: View {
    @State private var people: [Person] = Person.samples
    @State private var selection: Set<Person.ID> = []
    @State private var sortOrder = [KeyPathComparator(\Person.name)]

    var body: some View {
        Table(people, selection: $selection, sortOrder: $sortOrder) {
            TableColumn("Nome", value: \.name)
            TableColumn("Idade") { Text("\($0.age)") }
            TableColumn("Departamento", value: \.department)
        }
        .tableStyle(.bordered(alternatesRowBackgrounds: true))
        .onChange(of: sortOrder) {
            people.sort(using: sortOrder)
        }
    }
}
```

**Estilos de tabela (macOS-only):**
```swift
.tableStyle(.bordered)                              // Grade visível
.tableStyle(.bordered(alternatesRowBackgrounds: true))  // Grade + linhas alternadas
.tableStyle(.inset)                                 // Sem bordas
.tableColumnHeaders(.hidden)                        // Ocultar cabeçalhos
```

---

### PasteButton & CopyButton

**PasteButton** (lê clipboard; não valida automaticamente no macOS):
```swift
PasteButton(payloadType: String.self) { strings in
    pastedText = strings[0]
}
```

**CopyButton (macOS 15.0+, macOS-only):**
```swift
HStack {
    Text(shareableText)
    CopyButton(item: shareableText)   // Requer conformidade Transferable
}
```

---

### Operações de Arquivo

**fileImporter:**
```swift
.fileImporter(
    isPresented: $showImporter,
    allowedContentTypes: [.pdf],
    allowsMultipleSelection: false
) { result in
    if case .success(let urls) = result, let url = urls.first {
        guard url.startAccessingSecurityScopedResource() else { return }
        defer { url.stopAccessingSecurityScopedResource() }
        // usar url
    }
}
```

> **OBRIGATÓRIO:** sempre chame `startAccessingSecurityScopedResource()` em URLs
> retornadas e `stopAccessingSecurityScopedResource()` ao terminar.

**fileExporter:**
```swift
.fileExporter(
    isPresented: $showExporter,
    document: myDocument,
    contentType: .plainText,
    defaultFilename: "MeuArquivo.txt"
) { result in
    // tratar Result<URL, Error>
}
```

**Personalização dos painéis (macOS 13.0+, macOS-only):**
```swift
.fileImporter( /* ... */ ) { result in }
.fileDialogMessage("Selecione uma imagem para o perfil")
.fileDialogConfirmationLabel("Usar esta foto")

.fileExporter( /* ... */ ) { result in }
.fileExporterFilenameLabel("Exportar como:")
```

---

### Drag & Drop entre Apps

**Moderno (Transferable — preferido):**
```swift
// Arrastar
Text(item.title)
    .draggable(item)           // item deve conformar Transferable

// Soltar
VStack { /* conteúdo */ }
    .dropDestination(for: MyItem.self) { items, location in
        droppedItems.append(contentsOf: items)
        return true
    }
```

**Legado (NSItemProvider — somente para compatibilidade):**
```swift
// Arrastar
Image(systemName: "doc")
    .onDrag {
        NSItemProvider(object: fileURL as NSURL)
    }

// Soltar
Text("Arraste arquivos aqui")
    .onDrop(of: [.fileURL], isTargeted: nil) { providers in
        // tratar providers
        return true
    }
```

---

### AppKit Interop

**NSViewRepresentable (sem Coordinator):**
```swift
struct WebView: NSViewRepresentable {
    let url: URL

    func makeNSView(context: Context) -> WKWebView { WKWebView() }

    func updateNSView(_ nsView: WKWebView, context: Context) {
        nsView.load(URLRequest(url: url))
    }
}
```

**NSViewRepresentable com Coordinator (para delegates/callbacks):**
```swift
struct SearchField: NSViewRepresentable {
    @Binding var text: String

    func makeNSView(context: Context) -> NSSearchField {
        let field = NSSearchField()
        field.delegate = context.coordinator
        return field
    }

    func updateNSView(_ nsView: NSSearchField, context: Context) {
        nsView.stringValue = text
    }

    func makeCoordinator() -> Coordinator { Coordinator(text: $text) }

    class Coordinator: NSObject, NSSearchFieldDelegate {
        var text: Binding<String>
        init(text: Binding<String>) { self.text = text }

        func controlTextDidChange(_ obj: Notification) {
            if let field = obj.object as? NSSearchField {
                text.wrappedValue = field.stringValue
            }
        }
    }
}
```

> **Nunca** defina `frame`/`bounds` diretamente no `NSView` gerenciado — o SwiftUI controla o layout.

**NSViewControllerRepresentable:**
```swift
struct MapViewWrapper: NSViewControllerRepresentable {
    func makeNSViewController(context: Context) -> MapViewController {
        MapViewController()
    }

    func updateNSViewController(_ nsViewController: MapViewController, context: Context) {
        // Atualizar ao mudar estado SwiftUI
    }
}
```

**NSHostingController / NSHostingView (AppKit → SwiftUI):**
```swift
// Hospedar SwiftUI num NSViewController
let hostingController = NSHostingController(rootView: MySwiftUIView())
window.contentViewController = hostingController

// Hospedar SwiftUI diretamente como NSView
let hostingView = NSHostingView(rootView: MySwiftUIView())
someNSView.addSubview(hostingView)
```

---

## Checklist de Revisão

- [ ] APIs exclusivas macOS estão dentro de `#if os(macOS)` (projetos multiplataforma)
- [ ] `Settings` usa `TabView` com `Tab` + `Form`; tamanho máximo definido
- [ ] `MenuBarExtra` com estilo correto (`.menu` ou `.window`)
- [ ] `WindowGroup` é a cena principal; `Window` só para singletons suplementares
- [ ] `UtilityWindow` disponível apenas macOS 15.0+ — guarded com `@available`
- [ ] `windowResizability` + `defaultSize` + `.frame(minWidth:minHeight:)` definidos em conjunto
- [ ] `NavigationSplitView` para sidebar-driven; `HSplitView` para painéis iguais
- [ ] `startAccessingSecurityScopedResource()` + `defer { stop... }` em todo `fileImporter`
- [ ] Drag & drop usa `Transferable` (moderno); `NSItemProvider` apenas para legado
- [ ] `NSViewRepresentable` usa Coordinator quando precisa de delegate callbacks
- [ ] `frame`/`bounds` não definidos diretamente em views de `NSViewRepresentable`
- [ ] `Table` usa `.tableStyle(.bordered(alternatesRowBackgrounds: true))` no macOS
- [ ] `CopyButton` e `UtilityWindow` guardados com `@available(macOS 15, *)`
- [ ] `Inspector` guardado com `@available(macOS 14, *)`
