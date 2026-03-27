#!/usr/bin/env bash
# sync-instructions.sh
# Sincroniza as instruções de IA do repositório central para este projeto.
#
# Uso:
#   chmod +x sync-instructions.sh
#   ./sync-instructions.sh
#
# Coloque este script na raiz de cada projeto Flutter.
# Pode ser chamado manualmente ou via git hook / CI.

set -euo pipefail

# ============================================================
# CONFIGURAÇÃO — ajuste estas variáveis
# ============================================================

# URL do repositório de instruções (SSH ou HTTPS)
SOURCE_REPO="git@github.com:ANL-Software/swiftUI-instructions-ia.git"
# Branch de referência
SOURCE_BRANCH="main"

# ============================================================
# NÃO EDITE ABAIXO (a menos que saiba o que está fazendo)
# ============================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TMP_DIR=$(mktemp -d)

cleanup() {
  rm -rf "$TMP_DIR"
}
trap cleanup EXIT

echo "⬇️  Clonando instruções mais recentes..."
git clone --depth 1 --branch "$SOURCE_BRANCH" "$SOURCE_REPO" "$TMP_DIR" --quiet

# ── Arquivos raiz ──────────────────────────────────────────
echo "📄 Sincronizando arquivos raiz..."
cp "$TMP_DIR/AGENTS.md" "$SCRIPT_DIR/AGENTS.md"
cp "$TMP_DIR/CLAUDE.md" "$SCRIPT_DIR/CLAUDE.md"

# ── .github/copilot-instructions.md ───────────────────────
if [ -f "$TMP_DIR/.github/copilot-instructions.md" ]; then
  echo "📄 Sincronizando copilot-instructions.md..."
  mkdir -p "$SCRIPT_DIR/.github"
  cp "$TMP_DIR/.github/copilot-instructions.md" "$SCRIPT_DIR/.github/copilot-instructions.md"
else
  echo "⏭️  .github/copilot-instructions.md não encontrado no repositório fonte. Pulando."
fi

# ── .github/instructions/ ──────────────────────────────────────
if [ -d "$TMP_DIR/.github/instructions" ]; then
  echo "📁 Sincronizando .github/instructions/..."
  mkdir -p "$SCRIPT_DIR/.github/instructions"
  rsync -a --delete "$TMP_DIR/.github/instructions/" "$SCRIPT_DIR/.github/instructions/"
else
  echo "⏭️  .github/instructions/ não encontrado no repositório fonte. Pulando."
fi

# ── .github/prompts/ ──────────────────────────────────────
if [ -d "$TMP_DIR/.github/prompts" ]; then
  echo "📁 Sincronizando .github/prompts/..."
  mkdir -p "$SCRIPT_DIR/.github/prompts"
  rsync -a --delete "$TMP_DIR/.github/prompts/" "$SCRIPT_DIR/.github/prompts/"
else
  echo "⏭️  .github/prompts/ não encontrado no repositório fonte. Pulando."
fi

# ── .github/skills/ ───────────────────────────────────────
if [ -d "$TMP_DIR/.github/skills" ]; then
  echo "📁 Sincronizando .github/skills/..."
  mkdir -p "$SCRIPT_DIR/.github/skills"
  rsync -a --delete "$TMP_DIR/.github/skills/" "$SCRIPT_DIR/.github/skills/"
else
  echo "⏭️  .github/skills/ não encontrado no repositório fonte. Pulando."
fi

# ── PULL_REQUEST_TEMPLATE (opcional) ──────────────────────
if [ -f "$TMP_DIR/.github/PULL_REQUEST_TEMPLATE.md" ]; then
  echo "📄 Sincronizando PULL_REQUEST_TEMPLATE.md..."
  mkdir -p "$SCRIPT_DIR/.github"
  cp "$TMP_DIR/.github/PULL_REQUEST_TEMPLATE.md" "$SCRIPT_DIR/.github/PULL_REQUEST_TEMPLATE.md"
fi

# ── SDK: Claude ────────────────────────────────────────────
# .claude/rules  ← .github/instructions/
if [ -d "$TMP_DIR/.github/instructions" ]; then
  echo "📁 Sincronizando .claude/rules/..."
  mkdir -p "$SCRIPT_DIR/.claude/rules"
  rsync -a --delete "$TMP_DIR/.github/instructions/" "$SCRIPT_DIR/.claude/rules/"
else
  echo "⏭️  .github/instructions/ não encontrado. Pulando .claude/rules/."
fi

# .claude/skills ← .github/skills/
if [ -d "$TMP_DIR/.github/skills" ]; then
  echo "📁 Sincronizando .claude/skills/..."
  mkdir -p "$SCRIPT_DIR/.claude/skills"
  rsync -a --delete "$TMP_DIR/.github/skills/" "$SCRIPT_DIR/.claude/skills/"
else
  echo "⏭️  .github/skills/ não encontrado. Pulando .claude/skills/."
fi

# ── SDK: Codex / Agents ────────────────────────────────────
# .agents/skills ← .github/skills/
if [ -d "$TMP_DIR/.github/skills" ]; then
  echo "📁 Sincronizando .agents/skills/..."
  mkdir -p "$SCRIPT_DIR/.agents/skills"
  rsync -a --delete "$TMP_DIR/.github/skills/" "$SCRIPT_DIR/.agents/skills/"
else
  echo "⏭️  .github/skills/ não encontrado. Pulando .agents/skills/."
fi

# ── Auto-update do próprio script ─────────────────────────
if [ -f "$TMP_DIR/sync-instructions.sh" ]; then
  echo "🔄 Atualizando sync-instructions.sh..."
  cp "$TMP_DIR/sync-instructions.sh" "$SCRIPT_DIR/sync-instructions.sh"
  chmod +x "$SCRIPT_DIR/sync-instructions.sh"
fi

echo ""
echo "✅ Instruções sincronizadas com sucesso!"
echo ""
echo "Arquivos atualizados:"
echo "  • AGENTS.md"
echo "  • CLAUDE.md"

if [ -d "$SCRIPT_DIR/.github/prompts" ]; then
  echo "  • .github/prompts/       ($(ls "$SCRIPT_DIR/.github/prompts/" 2>/dev/null | wc -l | tr -d ' ') arquivos)"
fi

if [ -d "$SCRIPT_DIR/.github/skills" ]; then
  echo "  • .github/skills/        ($(find "$SCRIPT_DIR/.github/skills/" -name "*.md" 2>/dev/null | wc -l | tr -d ' ') arquivos)"
fi

if [ -f "$SCRIPT_DIR/.github/copilot-instructions.md" ]; then
  echo "  • .github/copilot-instructions.md"
fi

if [ -d "$SCRIPT_DIR/.claude/rules" ]; then
  echo "  • .claude/rules/         ($(find "$SCRIPT_DIR/.claude/rules/" -name "*.md" 2>/dev/null | wc -l | tr -d ' ') arquivos)"
fi

if [ -d "$SCRIPT_DIR/.claude/skills" ]; then
  echo "  • .claude/skills/        ($(find "$SCRIPT_DIR/.claude/skills/" -name "*.md" 2>/dev/null | wc -l | tr -d ' ') arquivos)"
fi

if [ -d "$SCRIPT_DIR/.agents/skills" ]; then
  echo "  • .agents/skills/        ($(find "$SCRIPT_DIR/.agents/skills/" -name "*.md" 2>/dev/null | wc -l | tr -d ' ') arquivos)"
fi