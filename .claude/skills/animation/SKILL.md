---
name: animation
description: Implementa animacoes SwiftUI seguindo as melhores praticas de performance e corretude. Use quando o usuario pedir para animar views, criar transicoes, usar phaseAnimator, keyframeAnimator, ou matchedGeometryEffect.
argument-hint: basics | transition | phase | keyframe | geometry | custom
---

Implemente animacoes SwiftUI seguindo as melhores praticas de performance e corretude.

## Argumentos

Tipo de animacao: `$ARGUMENTS`

Se `$ARGUMENTS` estiver vazio, pergunte:
- "Qual tipo de animacao precisa implementar?"
  - `basics` — animacao implicita/explicita em propriedades existentes
  - `transition` — animacao de entrada/saida de views (`if/else`, listas)
  - `phase` — sequencia multi-passo com `phaseAnimator` (iOS 17+)
  - `keyframe` — controle preciso de timing com `keyframeAnimator` (iOS 17+)
  - `geometry` — animacao de elemento compartilhado entre views (`matchedGeometryEffect`)
  - `custom` — transicao customizada ou protocolo `Animatable`

---

## Regra fundamental: animacao implicita sempre com `value:`

```swift
// CORRETO
.animation(.spring, value: isExpanded)

// ERRADO — deprecated, anima tudo inesperadamente
.animation(.spring)
```

> Esta e uma hard rule. Violacoes sao sempre bugs.

---

## Opcao 1: `basics` — Animacoes em propriedades

### Implicita (ligada a um valor especifico)

```swift
// Use quando a animacao e uma resposta visual direta a um estado
Rectangle()
    .frame(width: isExpanded ? 200 : 100, height: 50)
    .foregroundStyle(isExpanded ? .blue : .red)
    .animation(.spring, value: isExpanded)
    .onTapGesture { isExpanded.toggle() }
```

### Explicita (disparada por evento)

```swift
// Use para acoes do usuario (botoes, gestos)
Button("Toggle") {
    withAnimation(.spring) {
        isExpanded.toggle()
    }
}
```

### Quando usar cada uma

| Situacao | Abordagem |
|----------|-----------|
| Animacao visual de um unico estado | Implicita com `.animation(_:value:)` |
| Botao ou gesto aciona mudanca | Explicita com `withAnimation` |
| Multiplas propriedades animam juntas | Explicita com `withAnimation` |
| Animacao scoped a uma subview especifica | Implicita na subview |

### Timing (escolha correta)

```swift
// Interacoes do usuario — spring e o padrao ideal
withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) { ... }

// Aparicao/desaparicao de conteudo
withAnimation(.easeInOut(duration: 0.25)) { ... }

// Feedback rapido (botao pressionado)
withAnimation(.spring(response: 0.2, dampingFraction: 0.6)) { ... }

// Modificadores uteis
.animation(.spring.speed(1.5), value: flag)         // Mais rapido
.animation(.easeOut.delay(0.1), value: flag)        // Com delay
.animation(.spring.repeatCount(3), value: flag)     // Repeticao

// PROIBIDO para feedback de UI — parece robotico
.animation(.linear(duration: 1.0), value: flag)
```

### Performance: prefira transforms a layout

```swift
// CORRETO — GPU accelerated, sem recalculo de layout
.scaleEffect(isActive ? 1.5 : 1.0)
.offset(x: isActive ? 50 : 0)
.rotationEffect(.degrees(isActive ? 45 : 0))
.opacity(isActive ? 1 : 0)

// EVITAR — recalcula o layout a cada frame
.frame(width: isActive ? 150 : 100)
.padding(isActive ? 24 : 0)
```

### Escopo da animacao

```swift
// CORRETO — animacao scoped apenas ao componente que muda
VStack {
    HeaderView()
    ExpandableContent(isExpanded: isExpanded)
        .animation(.spring, value: isExpanded)  // So esta view
    FooterView()
}

// EVITAR — anima toda a arvore desnecessariamente
VStack {
    HeaderView()
    ExpandableContent(isExpanded: isExpanded)
    FooterView()
}
.animation(.spring, value: isExpanded)  // Afeta Header e Footer tambem
```

### Desabilitar animacao

```swift
// Via transaction (correto)
Text("Valor: \(count)")
    .transaction { $0.animation = nil }

// Via contexto pai
DataView()
    .transaction { $0.disablesAnimations = true }
```

---

## Opcao 2: `transition` — Entrada e saida de views

> Transicoes animam views sendo **inseridas ou removidas** da arvore. Diferenciam-se das animacoes de propriedade.

### Regra critica: contexto de animacao deve estar fora do condicional

```swift
// CORRETO — animation no container externo
VStack {
    if showDetail {
        DetailView()
            .transition(.slide)
    }
}
.animation(.spring, value: showDetail)

// CORRETO — withAnimation na acao
Button("Mostrar") {
    withAnimation(.spring) {
        showDetail.toggle()
    }
}

// ERRADO — animation dentro do bloco condicional (some on removal!)
if showDetail {
    DetailView()
        .transition(.slide)
        .animation(.spring, value: showDetail)  // Removido junto com a view!
}
```

### Transicoes built-in

```swift
.transition(.opacity)                          // Fade
.transition(.scale)                            // Escala
.transition(.slide)                            // Desliza pela leading edge
.transition(.move(edge: .bottom))              // Move por borda especifica
.transition(.offset(x: 0, y: 100))            // Desloca por offset

// Combinando
.transition(.scale.combined(with: .opacity))
.transition(.move(edge: .top).combined(with: .opacity))
```

### Transicao assimetrica (entrada diferente da saida)

```swift
if showCard {
    CardView()
        .transition(
            .asymmetric(
                insertion: .scale.combined(with: .opacity),
                removal: .move(edge: .bottom).combined(with: .opacity)
            )
        )
}
```

### Transicao customizada (iOS 15)

```swift
struct BlurModifier: ViewModifier {
    var radius: CGFloat
    func body(content: Content) -> some View {
        content.blur(radius: radius)
    }
}

extension AnyTransition {
    static func blur(radius: CGFloat = 10) -> AnyTransition {
        .modifier(
            active: BlurModifier(radius: radius),
            identity: BlurModifier(radius: 0)
        )
    }
}

// Uso
.transition(.blur(radius: 12).combined(with: .opacity))
```

### Transicao customizada (iOS 17+ — Transition protocol)

```swift
// Gate com #available
struct BlurTransition: Transition {
    var radius: CGFloat = 10

    func body(content: Content, phase: TransitionPhase) -> some View {
        content
            .blur(radius: phase.isIdentity ? 0 : radius)
            .opacity(phase.isIdentity ? 1 : 0)
    }
}

// Uso com fallback
if showContent {
    ContentView()
        .modifier(transitionModifier)
}

// Helper com fallback iOS 15
@ViewBuilder
private var transitionModifier: some ViewModifier {
    if #available(iOS 17, *) {
        BlurTransition(radius: 10)  // Nao e ViewModifier, use .transition()
    }
}

// Mais simples: aplicar diretamente com #available no site de uso
if showContent {
    ContentView()
        .transition(blurTransition)
}

@available(iOS 17, *)
private var blurTransition: some Transition { BlurTransition(radius: 10) }
```

### Identidade e transicoes

```swift
// ATENCAO: if/else gera identidades diferentes -> transicao, nao animacao de propriedade
// Use propriedade animada quando quiser interpolacoes suaves
if isExpanded {
    Rectangle().frame(width: 200, height: 50)  // Transicao!
} else {
    Rectangle().frame(width: 100, height: 50)  // Transicao!
}

// CORRETO para interpolacao suave
Rectangle()
    .frame(width: isExpanded ? 200 : 100, height: 50)
    .animation(.spring, value: isExpanded)
```

---

## Opcao 3: `phase` — Sequencias multi-passo (iOS 17+)

> Use para animacoes com multiplos passos sequenciais. Substitui o padrao anti-pattern de `DispatchQueue.asyncAfter`.

```swift
// Requer iOS 17 — sempre gate com #available
```

### Trigger manual

```swift
@State private var trigger = 0

Button("Animar") { trigger += 1 }
    .phaseAnimator(
        [0.0, -10.0, 10.0, -5.0, 5.0, 0.0],
        trigger: trigger
    ) { content, offset in
        content.offset(x: offset)
    }
```

### Loop continuo (sem trigger)

```swift
Circle()
    .phaseAnimator([0.9, 1.0, 1.1, 1.0]) { content, scale in
        content.scaleEffect(scale)
    } animation: { _ in .easeInOut(duration: 0.6) }
```

### Enum phases (recomendado para clareza)

```swift
enum BouncePhase: CaseIterable {
    case idle, up, down, settle

    var scale: CGFloat {
        switch self {
        case .idle:   1.0
        case .up:     1.2
        case .down:   0.9
        case .settle: 1.0
        }
    }

    var animation: Animation {
        switch self {
        case .up:   .spring(response: 0.2)
        case .down: .spring(response: 0.15)
        default:    .smooth
        }
    }
}

Image(systemName: "heart.fill")
    .phaseAnimator(BouncePhase.allCases, trigger: trigger) { content, phase in
        content.scaleEffect(phase.scale)
    } animation: { phase in
        phase.animation
    }
```

### Anti-pattern substituido

```swift
// NUNCA faca isso
Button("Animar") {
    withAnimation(.easeOut(duration: 0.1)) { offset = -10 }
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
        withAnimation { offset = 10 }
    }
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
        withAnimation { offset = 0 }
    }
}

// USE phaseAnimator
Button("Animar") { trigger += 1 }
    .phaseAnimator([0, -10.0, 10.0, 0], trigger: trigger) { content, offset in
        content.offset(x: offset)
    }
```

---

## Opcao 4: `keyframe` — Controle preciso de timing (iOS 17+)

> Use para animacoes com timing exato em multiplas propriedades sincronizadas. As tracks rodam em **paralelo**.

```swift
struct AnimationValues {
    var scale: CGFloat = 1.0
    var rotation: Double = 0
    var verticalOffset: CGFloat = 0
}

@State private var trigger = 0

Image(systemName: "bell.fill")
    .keyframeAnimator(
        initialValue: AnimationValues(),
        trigger: trigger
    ) { content, value in
        content
            .scaleEffect(value.scale)
            .rotationEffect(.degrees(value.rotation))
            .offset(y: value.verticalOffset)
    } keyframes: { _ in
        KeyframeTrack(\.scale) {
            SpringKeyframe(1.1, duration: 0.15)
            CubicKeyframe(1.0, duration: 0.25)
        }
        KeyframeTrack(\.rotation) {
            CubicKeyframe(15, duration: 0.1)
            CubicKeyframe(-15, duration: 0.1)
            CubicKeyframe(10, duration: 0.1)
            CubicKeyframe(0, duration: 0.1)
        }
        KeyframeTrack(\.verticalOffset) {
            LinearKeyframe(-10, duration: 0.2)
            SpringKeyframe(0, duration: 0.3)
        }
    }
```

### Tipos de Keyframe

| Tipo | Comportamento |
|------|---------------|
| `CubicKeyframe` | Interpolacao suave (mais comum) |
| `LinearKeyframe` | Linha reta, sem curva |
| `SpringKeyframe` | Fisica de mola |
| `MoveKeyframe` | Salto instantaneo sem interpolacao |

### quando usar `phase` vs `keyframe`

| `phaseAnimator` | `keyframeAnimator` |
|---|---|
| Passos discretos com animacoes proprias | Timing preciso em ms |
| Ciclos infinitos | Multiplas propriedades sincronizadas |
| Logica simples | Animacoes cinematograficas |

---

## Opcao 5: `geometry` — Elemento compartilhado entre views

> `matchedGeometryEffect` anima a posicao/tamanho de um elemento que "se move" de uma view para outra.

```swift
@Namespace private var heroNamespace

// View de origem
ForEach(items) { item in
    Image(item.imageName)
        .matchedGeometryEffect(id: item.id, in: heroNamespace)
        .onTapGesture {
            withAnimation(.spring(response: 0.4)) {
                selectedItem = item
            }
        }
}

// View de destino (detail)
if let item = selectedItem {
    Image(item.imageName)
        .matchedGeometryEffect(id: item.id, in: heroNamespace)
        .onTapGesture {
            withAnimation(.spring(response: 0.4)) {
                selectedItem = nil
            }
        }
}
```

### Regras do `matchedGeometryEffect`

```swift
// CORRETO — apenas uma view com isSource: true por ID (padrao)
ImageView()
    .matchedGeometryEffect(id: item.id, in: namespace)  // isSource: true (default)

// Destino recebe as propriedades da fonte
DetailImageView()
    .matchedGeometryEffect(id: item.id, in: namespace, isSource: false)

// ERRADO — ambas as views visiveis ao mesmo tempo sem isSource diferenciado
// causara comportamento indefinido
```

---

## Opcao 6: `custom` — Protocolo Animatable

> Use para interpolar propriedades customizadas de `ViewModifier` ou `Shape` durante uma animacao.

```swift
struct ShakeModifier: ViewModifier, Animatable {
    var shakeCount: Double

    var animatableData: Double {
        get { shakeCount }
        set { shakeCount = newValue }
    }

    func body(content: Content) -> some View {
        content.offset(x: sin(shakeCount * .pi * 2) * 10)
    }
}

extension View {
    func shake(count: Int) -> some View {
        modifier(ShakeModifier(shakeCount: Double(count)))
    }
}

// Uso
@State private var shakeCount = 0

Button("Validar") {
    withAnimation(.default) { shakeCount += 3 }
}
.shake(count: shakeCount)
```

### Multiplas propriedades com `AnimatablePair`

```swift
struct WaveShape: Shape, Animatable {
    var amplitude: Double
    var frequency: Double

    var animatableData: AnimatablePair<Double, Double> {
        get { AnimatablePair(amplitude, frequency) }
        set { amplitude = newValue.first; frequency = newValue.second }
    }

    func path(in rect: CGRect) -> Path { ... }
}
```

---

## Checklist de Revisao

### Hard rules (violacoes sao sempre bugs)
- [ ] `.animation(_:value:)` sempre inclui o parametro `value:` — nunca `.animation(.spring)` sem value
- [ ] Transicoes tem contexto de animacao fora do bloco condicional
- [ ] `phaseAnimator` e `keyframeAnimator` gateados com `#available(iOS 17, *)`
- [ ] `matchedGeometryEffect` — `@Namespace` declarado como `private` na View
- [ ] `matchedGeometryEffect` — IDs unicos por namespace

### Performance
- [ ] Preferencia por `scaleEffect`, `offset`, `rotationEffect`, `opacity` (transforms) sobre mudancas de `frame`/`padding`
- [ ] Animacao scoped a subview especifica, nao ao container raiz
- [ ] Hot paths (scroll, timers) nao disparam `withAnimation` a cada frame — apenas ao cruzar threshold

### Compatibilidade
- [ ] `phaseAnimator` gateado com `#available(iOS 17, *)`
- [ ] `keyframeAnimator` gateado com `#available(iOS 17, *)`
- [ ] Transicoes customizadas com `Transition` protocol gateadas com `#available(iOS 17, *)`
- [ ] Fallback compativel com iOS 15 fornecido para qualquer API iOS 17+
