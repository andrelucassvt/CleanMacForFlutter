---
name: liquid-glass
description: Implementa efeitos Liquid Glass (iOS 26+) com fallbacks corretos para versoes anteriores. Use APENAS quando o usuario pedir explicitamente para adotar Liquid Glass, glass effects, glassEffect modifier, ou o novo visual design do iOS 26.
argument-hint: card | toolbar | button | segmented | morphing | fallback
---

Implemente efeitos Liquid Glass (iOS 26+) seguindo as diretrizes de design e as regras de API da Apple.

> **Regra obrigatoria**: Adote Liquid Glass APENAS quando o usuario pedir explicitamente. Nunca converta UI existente para glass proativamente.

## Argumentos

Tipo de componente: `$ARGUMENTS`

Se `$ARGUMENTS` estiver vazio, pergunte:
- "Qual componente precisa de Liquid Glass?"
  - `card` — superficie de card com glassEffect
  - `toolbar` — barra de botoes com glass
  - `button` — botao individual com glass
  - `segmented` — controle segmentado com glass + morphing
  - `morphing` — transicao entre dois elementos glass
  - `fallback` — helper reutilizavel com fallback automatico

---

## Disponibilidade — regra absoluta

**Todos os APIs de Liquid Glass requerem iOS 26+. Sempre forneca fallback.**

```swift
if #available(iOS 26, *) {
    // Implementacao Liquid Glass
} else {
    // Fallback com material
}
```

Materiais de fallback (do mais proximo ao mais opaco):

| Material | Quando usar |
|----------|-------------|
| `.ultraThinMaterial` | Mais proximo ao glass — padrao para fallback |
| `.thinMaterial` | Levemente mais opaco |
| `.regularMaterial` | Opaco padrao |
| `.thickMaterial` / `.ultraThickMaterial` | Fundo de alta cobertura |

---

## Ordem de modificadores — regra critica

```swift
// CORRETO — glassEffect SEMPRE apos layout e visual modifiers
Text("Label")
    .font(.headline)            // 1. Tipografia
    .foregroundStyle(.primary)  // 2. Cor
    .padding()                  // 3. Layout
    .glassEffect()              // 4. Glass ULTIMO

// ERRADO — glass antes de padding/frame
Text("Label")
    .glassEffect()   // Errado!
    .padding()
    .font(.headline)
```

---

## GlassEffectContainer — quando e obrigatorio

**Glass nao pode amostrar outro glass.** O material glass refrata luz de uma area maior que si mesmo. Dois elementos glass proximos sem container produziram resultados visuais inconsistentes.

```swift
// CORRETO — glass agrupado em container
GlassEffectContainer(spacing: 16) {
    HStack(spacing: 16) {
        Button("A") { }.glassEffect()
        Button("B") { }.glassEffect()
    }
}

// ERRADO — glass sem container
HStack {
    Button("A") { }.glassEffect()   // Incosistente!
    Button("B") { }.glassEffect()
}
```

> O parametro `spacing:` do container deve ser igual ao spacing do layout interno.

---

## Opcao 1: `card` — Card com glass

```swift
struct GlassCard: View {
    let title: String
    let subtitle: String

    var body: some View {
        if #available(iOS 26, *) {
            cardContent
                .glassEffect(.regular, in: .rect(cornerRadius: 20))
        } else {
            cardContent
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20))
        }
    }

    private var cardContent: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)
            Text(subtitle)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
```

### Variantes de estilo

```swift
// Padrao
.glassEffect(.regular, in: .rect(cornerRadius: 16))

// Mais destaque (CTA, estados selecionados)
.glassEffect(.prominent, in: .rect(cornerRadius: 16))

// Com tint de cor
.glassEffect(.regular.tint(.blue.opacity(0.3)), in: .rect(cornerRadius: 16))

// Shapes comuns
.glassEffect(in: .circle)
.glassEffect(in: .capsule)
.glassEffect(in: .rect(cornerRadius: 12))
```

---

## Opcao 2: `toolbar` — Barra de botoes

```swift
struct GlassToolbar: View {
    var body: some View {
        if #available(iOS 26, *) {
            GlassEffectContainer(spacing: 16) {
                HStack(spacing: 16) {
                    ToolbarButton(icon: "pencil", action: { })
                    ToolbarButton(icon: "eraser", action: { })
                    ToolbarButton(icon: "scissors", action: { })
                    Spacer()
                    ToolbarButton(icon: "square.and.arrow.up", action: { })
                }
                .padding(.horizontal)
            }
        } else {
            HStack(spacing: 16) {
                ToolbarButton(icon: "pencil", action: { })
                ToolbarButton(icon: "eraser", action: { })
                ToolbarButton(icon: "scissors", action: { })
                Spacer()
                ToolbarButton(icon: "square.and.arrow.up", action: { })
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
            .background(.ultraThinMaterial)
        }
    }
}

struct ToolbarButton: View {
    let icon: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.title2)
                .frame(width: 44, height: 44)
        }
        .glassEffect(.regular.interactive(), in: .circle)
    }
}
```

> **Design note**: Icons de toolbar usam rendering monocromatico por padrao no iOS 26. Use `tint(_:)` apenas para transmitir significado (ex: acao destrutiva), nunca por efeito visual.

---

## Opcao 3: `button` — Botao com glass

```swift
// Button styles built-in
Button("Acao") { }
    .buttonStyle(.glass)

Button("Acao Principal") { }
    .buttonStyle(.glassProminent)

// Controle total via glassEffect manual
Button(action: { }) {
    Label("Configuracoes", systemImage: "gear")
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
}
.glassEffect(.regular.interactive(), in: .capsule)

// Com fallback
Button(action: { }) {
    Label("Compartilhar", systemImage: "square.and.arrow.up")
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
}
.modifier(GlassButtonModifier())

// Modifier com fallback embutido
struct GlassButtonModifier: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 26, *) {
            content.glassEffect(.regular.interactive(), in: .capsule)
        } else {
            content
                .background(.ultraThinMaterial, in: Capsule())
                .overlay(Capsule().strokeBorder(.secondary.opacity(0.2)))
        }
    }
}
```

> `.interactive()` apenas em elementos que respondem a input do usuario (botoes, views tapeaveis, elementos focaveis). Nunca em conteudo estatico.

---

## Opcao 4: `segmented` — Controle segmentado com morphing

```swift
struct GlassSegmentedControl: View {
    @Binding var selection: Int
    let options: [String]
    @Namespace private var animation

    var body: some View {
        if #available(iOS 26, *) {
            GlassEffectContainer(spacing: 4) {
                HStack(spacing: 4) {
                    ForEach(options.indices, id: \.self) { index in
                        Button(options[index]) {
                            withAnimation(.smooth) {
                                selection = index
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .glassEffect(
                            selection == index ? .prominent.interactive() : .regular.interactive(),
                            in: .capsule
                        )
                        .glassEffectID(
                            selection == index ? "selected" : "option\(index)",
                            in: animation
                        )
                    }
                }
                .padding(4)
            }
        } else {
            Picker("", selection: $selection) {
                ForEach(options.indices, id: \.self) { index in
                    Text(options[index]).tag(index)
                }
            }
            .pickerStyle(.segmented)
        }
    }
}
```

---

## Opcao 5: `morphing` — Transicao entre elementos glass

> Use `glassEffectID` + `@Namespace` para animar a transicao entre dois estados de um elemento glass.

```swift
struct MorphingCard: View {
    @Namespace private var glassNamespace
    @State private var isExpanded = false

    var body: some View {
        GlassEffectContainer {
            if isExpanded {
                ExpandedView()
                    .glassEffect(.regular, in: .rect(cornerRadius: 20))
                    .glassEffectID("card", in: glassNamespace)
            } else {
                CompactView()
                    .glassEffect(.regular, in: .rect(cornerRadius: 12))
                    .glassEffectID("card", in: glassNamespace)
            }
        }
        .animation(.smooth, value: isExpanded)
        .onTapGesture {
            isExpanded.toggle()
        }
    }
}
```

### Requisitos obrigatorios para morphing

1. Ambas as views devem ter o mesmo `glassEffectID`
2. O mesmo `@Namespace` em ambas
3. Envolvidas em `GlassEffectContainer`
4. Animacao aplicada no container ou view pai

---

## Opcao 6: `fallback` — Helper reutilizavel

Para aplicar glass com fallback em qualquer view do projeto:

```swift
extension View {
    @ViewBuilder
    func glassEffectWithFallback(
        cornerRadius: CGFloat = 16,
        prominent: Bool = false,
        interactive: Bool = false
    ) -> some View {
        if #available(iOS 26, *) {
            let style: GlassEffectStyle = prominent
                ? (interactive ? .prominent.interactive() : .prominent)
                : (interactive ? .regular.interactive() : .regular)
            self.glassEffect(style, in: .rect(cornerRadius: cornerRadius))
        } else {
            self.background(
                .ultraThinMaterial,
                in: RoundedRectangle(cornerRadius: cornerRadius)
            )
        }
    }
}

// Uso
Text("Conteudo")
    .padding()
    .glassEffectWithFallback(cornerRadius: 20, interactive: true)
```

---

## Notas de design do iOS 26

### Sheets
Sheets de altura parcial usam background Liquid Glass por padrao. Remova `presentationBackground(_:)` customizado para deixar o material padrao aparecer:

```swift
// Remover isto se existir:
// .presentationBackground(.ultraThinMaterial)

// Deixar o sistema aplicar automaticamente
.sheet(isPresented: $showSheet) {
    SheetContent()
    // Sem presentationBackground — usa glass automaticamente no iOS 26
}
```

### Scroll edge effect
O iOS 26 aplica automaticamente blur/fade sob toolbars do sistema. Remova qualquer background escurecido customizado atras de bar items — ele vai conflitar com o efeito automatico.

---

## Checklist de Revisao

- [ ] Todo uso de `.glassEffect()` gateado com `#available(iOS 26, *)`
- [ ] Fallback com `.background(.ultraThinMaterial, in: <shape>)` fornecido
- [ ] `.glassEffect()` aplicado APOS `.padding()`, `.frame()`, `.font()`, `.foregroundStyle()`
- [ ] Elementos glass proximos envolvidos em `GlassEffectContainer`
- [ ] `spacing:` do container igual ao spacing do layout interno
- [ ] `.interactive()` apenas em botoes/views tapeaveis — nunca em conteudo estatico
- [ ] Morphing: `glassEffectID` igual em ambos os estados + mesmo `@Namespace` + `GlassEffectContainer`
- [ ] `@Namespace` declarado como `private` na View
- [ ] Animacao de morphing aplicada no container ou view pai (nao nas views individuais)
- [ ] `presentationBackground` customizado removido de sheets (usa glass automatico do iOS 26)
- [ ] Toolbar icons sem tinting decorativo — `tint` apenas para significado
