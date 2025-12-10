<div align="center">
  <img src="CleanMacForFlutters/Assets.xcassets/AppIcon.appiconset/iconMacApp-2.jpg" alt="Ícone do Clean Mac for Flutter" width="150"/>
</div>

# Clean Mac for Flutter

Aplicativo para macOS que limpa artefatos de build de projetos Flutter e libera espaço em disco rapidamente.

## Como funciona
1. Abra o app e conceda **Full Disk Access** quando solicitado (Ajustes do Sistema → Privacidade e Segurança → Acesso total ao disco). Sem essa permissão o app não consegue apagar as pastas dos projetos.
2. Clique em **Selecionar pastas** e escolha as pastas raiz dos projetos Flutter que quer manter na lista.
3. Ative ou desative cada projeto pelo toggle da lista (apenas os ativos serão limpos).
4. Pressione **Run clean**. O app mostra o progresso e, ao final, um resumo com quantidade de pastas removidas e espaço liberado.
5. Os caminhos escolhidos ficam salvos; basta reabrir o app e rodar a limpeza novamente quando precisar.

## O que é removido
- `build/`
- `.dart_tool/`
- `pubspec.lock`
- `ios/Pods`
- `ios/Podfile.lock`
- `ios/Gemfile.lock`

Esses itens são recriados automaticamente pelo Flutter/Swift ao rodar `flutter pub get`, `pod install` ou novos builds, então é seguro removê-los para recuperar espaço.

## Extras
- Botão **Github** abre o repositório do projeto.
- Botão **Apoiar** leva para a página de contribuição.

## Download

Baixe a versão mais recente do aplicativo:

👉 [**Releases - Clean Mac for Flutter**](https://github.com/andrelucassvt/CleanMacForFlutter/releases)
