#!/usr/bin/env bash
#
# release.sh — preparação de release do gem nfe-io (uso do mantenedor).
#
# Faz apenas a PREPARAÇÃO local de um release: bump de versão, rotação do
# CHANGELOG, commit, tag anotada e push. A PUBLICAÇÃO no RubyGems acontece no
# workflow .github/workflows/release.yml, disparado pelo push da tag (via OIDC).
# Este script NUNCA executa `gem push`.
#
# Forma das versões:
#   - tag git: forma com HÍFEN  -> vX.Y.Z, vX.Y.Z-rc.N, vX.Y.Z-beta.N
#   - Nfe::VERSION / gem:        forma com PONTO -> X.Y.Z, X.Y.Z.rc.N (exigido pelo RubyGems)
#
# Uso:
#   scripts/release.sh [--dry-run] [--skip-tests] [--skip-git] [--help]
#
set -euo pipefail

# --- Cores ------------------------------------------------------------------
if [[ -t 1 ]]; then
  C_RESET=$'\033[0m'
  C_BOLD=$'\033[1m'
  C_RED=$'\033[31m'
  C_GREEN=$'\033[32m'
  C_YELLOW=$'\033[33m'
  C_BLUE=$'\033[34m'
  C_DIM=$'\033[2m'
else
  C_RESET="" C_BOLD="" C_RED="" C_GREEN="" C_YELLOW="" C_BLUE="" C_DIM=""
fi

info()  { printf '%s==>%s %s\n'  "$C_BLUE"   "$C_RESET" "$*"; }
ok()    { printf '%s ✓ %s %s\n'  "$C_GREEN"  "$C_RESET" "$*"; }
warn()  { printf '%s ! %s %s\n'  "$C_YELLOW" "$C_RESET" "$*" >&2; }
err()   { printf '%s ✗ %s %s\n'  "$C_RED"    "$C_RESET" "$*" >&2; }
dry()   { printf '%s[dry-run]%s %s\n' "$C_DIM" "$C_RESET" "$*"; }
die()   { err "$*"; exit 1; }

# --- Localização ------------------------------------------------------------
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
VERSION_FILE="$REPO_ROOT/lib/nfe/version.rb"
CHANGELOG_FILE="$REPO_ROOT/CHANGELOG.md"

# --- Flags ------------------------------------------------------------------
DRY_RUN=0
SKIP_TESTS=0
SKIP_GIT=0

usage() {
  cat <<EOF
${C_BOLD}release.sh${C_RESET} — preparação de release do gem nfe-io

${C_BOLD}USO${C_RESET}
  scripts/release.sh [opções]

${C_BOLD}OPÇÕES${C_RESET}
  --dry-run      Imprime cada passo SEM efeitos colaterais (não escreve arquivos,
                 não roda testes, não toca no git).
  --skip-tests   Pula o gate local (rake spec / rubocop / steep / generate:check).
                 O gate ainda roda no CI após o push da tag.
  --skip-git     Pula commit, tag e push (e dispensa a checagem de working tree limpo).
  --help, -h     Mostra esta ajuda.

${C_BOLD}O QUE FAZ${C_RESET}
  1. Pre-flight: branch master, working tree limpo, último CI verde, ferramentas.
  2. Pergunta a versão (X.Y.Z, X.Y.Z-rc.N ou X.Y.Z-beta.N) e valida.
  3. Recusa se a tag vX.Y.Z já existir.
  4. Atualiza Nfe::VERSION (forma pontilhada) em lib/nfe/version.rb.
  5. Rotaciona o CHANGELOG ([Não lançado] -> [X.Y.Z] - data).
  6. Roda o gate local (a menos que --skip-tests).
  7. Commita chore(release): vX.Y.Z, cria tag anotada vX.Y.Z e dá push.

${C_BOLD}NÃO FAZ${C_RESET}
  - Nunca executa 'gem push'. A publicação no RubyGems acontece no workflow
    release.yml após o push da tag (trusted publishing via OIDC).
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --dry-run)    DRY_RUN=1 ;;
    --skip-tests) SKIP_TESTS=1 ;;
    --skip-git)   SKIP_GIT=1 ;;
    -h|--help)    usage; exit 0 ;;
    *) err "Opção desconhecida: $1"; echo; usage; exit 2 ;;
  esac
  shift
done

cd "$REPO_ROOT"

# --- Helpers ----------------------------------------------------------------

# Converte a forma de tag (hífen) para a forma de gem (ponto):
#   1.0.0          -> 1.0.0
#   1.0.0-rc.1     -> 1.0.0.rc.1
#   1.2.3-beta.4   -> 1.2.3.beta.4
to_dotted() { printf '%s\n' "${1/-/.}"; }

# Extrai a seção de notas do CHANGELOG para a versão informada (forma pontilhada),
# do cabeçalho "## [X.Y.Z]" até o próximo "## " (exclusivo). Stdout.
changelog_notes() {
  local ver="$1"
  awk -v ver="$ver" '
    $0 ~ "^## \\[" ver "\\]" { capture = 1; next }
    capture && /^## / { exit }
    capture { print }
  ' "$CHANGELOG_FILE"
}

# --- Pre-flight -------------------------------------------------------------
info "Pre-flight"

for tool in git ruby bundle; do
  command -v "$tool" >/dev/null 2>&1 || die "Ferramenta obrigatória ausente no PATH: $tool"
done
ok "ferramentas presentes: git, ruby, bundle"

# gh só é obrigatório quando vamos checar o CI (ou seja, quando não pulamos o git).
HAVE_GH=0
if command -v gh >/dev/null 2>&1; then
  HAVE_GH=1
fi

[[ -f "$VERSION_FILE" ]]   || die "Arquivo de versão não encontrado: $VERSION_FILE"
[[ -f "$CHANGELOG_FILE" ]] || die "CHANGELOG não encontrado: $CHANGELOG_FILE"

CURRENT_BRANCH="$(git rev-parse --abbrev-ref HEAD)"
if [[ "$CURRENT_BRANCH" != "master" ]]; then
  if [[ $SKIP_GIT -eq 1 ]]; then
    warn "branch atual é '$CURRENT_BRANCH' (não master); --skip-git ativo, prosseguindo."
  else
    die "Releases são cortados a partir de 'master' (branch atual: '$CURRENT_BRANCH')."
  fi
else
  ok "na branch master"
fi

if [[ $SKIP_GIT -eq 0 ]]; then
  if [[ -n "$(git status --porcelain)" ]]; then
    die "Working tree sujo. Commite ou descarte as mudanças antes de cortar o release (ou use --skip-git)."
  fi
  ok "working tree limpo"

  if [[ $HAVE_GH -eq 1 ]]; then
    CI_CONCLUSION="$(gh run list --branch master --limit 1 --json conclusion --jq '.[0].conclusion' 2>/dev/null || true)"
    case "$CI_CONCLUSION" in
      success)
        ok "último CI em master: success" ;;
      "" | null)
        warn "não foi possível determinar o status do último CI em master; prosseguindo com cautela." ;;
      *)
        die "Último CI em master não passou (conclusion='$CI_CONCLUSION'). Corrija antes de cortar o release." ;;
    esac
  else
    warn "gh não encontrado; pulando a verificação do CI em master."
  fi
else
  warn "--skip-git ativo: pulando checagem de working tree e CI."
fi

# --- Versão -----------------------------------------------------------------
echo
CURRENT_VERSION="$(ruby -r "$VERSION_FILE" -e 'print Nfe::VERSION' 2>/dev/null || true)"
[[ -n "$CURRENT_VERSION" ]] && info "Versão atual (Nfe::VERSION): ${C_BOLD}${CURRENT_VERSION}${C_RESET}"

VERSION_REGEX='^[0-9]+\.[0-9]+\.[0-9]+(-(rc|beta)\.[0-9]+)?$'
VERSION=""
if [[ $DRY_RUN -eq 1 ]] && [[ ! -t 0 ]]; then
  # Em dry-run não-interativo, use um placeholder explícito para conseguir
  # imprimir todos os passos sem travar num prompt.
  VERSION="${RELEASE_VERSION:-1.0.0-rc.1}"
  dry "usando versão de exemplo para o ensaio: $VERSION (defina RELEASE_VERSION para mudar)"
else
  read -rp "Versão a lançar (ex.: 1.0.0, 1.0.0-rc.1, 1.0.0-beta.2): " VERSION
fi

[[ "$VERSION" =~ $VERSION_REGEX ]] || die "Versão inválida: '$VERSION'. Esperado X.Y.Z, X.Y.Z-rc.N ou X.Y.Z-beta.N."

TAG="v$VERSION"                       # forma com hífen (git tag)
DOTTED_VERSION="$(to_dotted "$VERSION")"  # forma com ponto (Nfe::VERSION / gem)

IS_PRERELEASE=0
[[ "$VERSION" == *-* ]] && IS_PRERELEASE=1

ok "versão validada: tag=${C_BOLD}${TAG}${C_RESET}  gem=${C_BOLD}${DOTTED_VERSION}${C_RESET}  prerelease=${IS_PRERELEASE}"

# Recusa se a tag já existir (local ou remota).
if git rev-parse -q --verify "refs/tags/$TAG" >/dev/null 2>&1; then
  die "A tag '$TAG' já existe localmente. Aborte (delete a tag se for um retag intencional)."
fi
if [[ $SKIP_GIT -eq 0 ]] && git ls-remote --exit-code --tags origin "refs/tags/$TAG" >/dev/null 2>&1; then
  die "A tag '$TAG' já existe em origin. Aborte."
fi
ok "tag '$TAG' está livre"

DATE="$(date +%F)"

# --- Atualizar lib/nfe/version.rb -------------------------------------------
echo
info "Atualizando Nfe::VERSION -> \"$DOTTED_VERSION\" (forma pontilhada)"
if [[ $DRY_RUN -eq 1 ]]; then
  dry "escreveria VERSION = \"$DOTTED_VERSION\" em $VERSION_FILE"
else
  # Substitui o literal entre aspas após VERSION =, preservando o resto do arquivo.
  ruby -e '
    file, ver = ARGV
    src = File.read(file)
    updated = src.sub(/VERSION\s*=\s*"[^"]*"/, %(VERSION = "#{ver}"))
    abort("não encontrei a constante VERSION em #{file}") if updated == src
    File.write(file, updated)
  ' "$VERSION_FILE" "$DOTTED_VERSION"
  # Confirma que o Ruby lê exatamente o valor esperado.
  WRITTEN="$(ruby -r "$VERSION_FILE" -e 'print Nfe::VERSION')"
  [[ "$WRITTEN" == "$DOTTED_VERSION" ]] || die "Falha ao escrever a versão: Nfe::VERSION='$WRITTEN' != '$DOTTED_VERSION'"
  ok "Nfe::VERSION = \"$WRITTEN\""
fi

# --- Rotacionar CHANGELOG ---------------------------------------------------
echo
info "Rotacionando CHANGELOG: [Não lançado] -> [$DOTTED_VERSION] - $DATE"
if [[ $DRY_RUN -eq 1 ]]; then
  dry "renomearia o cabeçalho de 'não lançado' para '## [$DOTTED_VERSION] - $DATE' e abriria uma nova seção vazia"
else
  ruby -e '
    file, ver, date = ARGV
    src = File.read(file)
    # Aceita o marcador canônico em pt-BR e o legado em inglês.
    header_re = /^## \[(Não lançado|Nao lancado|Unreleased)\]\s*$/
    abort("não encontrei o cabeçalho de não-lançado em #{file}") unless src =~ header_re
    new_unreleased = "## [Não lançado]\n\n## [#{ver}] - #{date}"
    src = src.sub(header_re, new_unreleased)
    File.write(file, src)
  ' "$CHANGELOG_FILE" "$DOTTED_VERSION" "$DATE"
  ok "CHANGELOG rotacionado"
fi

# --- Gate local -------------------------------------------------------------
echo
if [[ $SKIP_TESTS -eq 1 ]]; then
  warn "--skip-tests ativo: pulando rake spec / rubocop / steep / generate:check (o CI ainda roda após o push)."
else
  info "Rodando o gate local (mesmos comandos do CI)"
  GATE=(
    "bundle exec rake spec"
    "bundle exec rubocop"
    "bundle exec steep check"
    "bundle exec rake generate:check"
  )
  for cmd in "${GATE[@]}"; do
    if [[ $DRY_RUN -eq 1 ]]; then
      dry "$cmd"
    else
      info "$cmd"
      eval "$cmd" || die "Gate falhou em: $cmd"
    fi
  done
  [[ $DRY_RUN -eq 1 ]] || ok "gate local passou"
fi

# --- Git: commit + tag + push -----------------------------------------------
echo
if [[ $SKIP_GIT -eq 1 ]]; then
  warn "--skip-git ativo: pulando commit, tag e push. Mudanças ficam no working tree."
else
  COMMIT_MSG="chore(release): $TAG"

  # Mensagem da tag anotada: título + notas do CHANGELOG da versão.
  NOTES="$(changelog_notes "$DOTTED_VERSION" || true)"
  TAG_FILE="$(mktemp "${TMPDIR:-/tmp}/nfe-release-tag.XXXXXX")"
  trap 'rm -f "$TAG_FILE"' EXIT
  {
    printf 'nfe-io %s\n' "$TAG"
    if [[ -n "${NOTES// /}" ]]; then
      printf '\n%s\n' "$NOTES"
    fi
  } >"$TAG_FILE"

  if [[ $DRY_RUN -eq 1 ]]; then
    dry "git add $VERSION_FILE $CHANGELOG_FILE"
    dry "git commit -m \"$COMMIT_MSG\""
    dry "git tag -a $TAG -F <(notas do CHANGELOG)"
    dry "git push origin master"
    dry "git push origin $TAG"
    echo
    dry "Após o push da tag, .github/workflows/release.yml publica o gem (OIDC) e cria o GitHub Release."
  else
    info "Commitando: $COMMIT_MSG"
    git add "$VERSION_FILE" "$CHANGELOG_FILE"
    git commit -m "$COMMIT_MSG"
    ok "commit criado"

    info "Criando tag anotada $TAG"
    git tag -a "$TAG" -F "$TAG_FILE"
    ok "tag $TAG criada"

    info "Enviando commit e tag para origin"
    git push origin "$CURRENT_BRANCH"
    git push origin "$TAG"
    ok "push concluído"
    echo
    info "Tag '$TAG' enviada. O workflow release.yml vai verificar o CI e publicar o gem via OIDC."
  fi
fi

echo
if [[ $DRY_RUN -eq 1 ]]; then
  ok "${C_BOLD}Dry-run concluído.${C_RESET} Nenhum efeito colateral. Rode sem --dry-run para cortar o release."
else
  ok "${C_BOLD}Preparação de release concluída para $TAG.${C_RESET}"
fi
