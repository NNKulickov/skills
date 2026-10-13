#!/usr/bin/env bash
set -euo pipefail

# run_dir.sh - управление персистентной директорией запуска для skill review.
#
# База: $REVIEW_RUNS_DIR, по умолчанию $HOME/.claude/review-runs
# (НЕ внутри skill-директории, НЕ /tmp: переустановка скилла не должна сносить прогоны).
#
# ВАЖНО про пермишены: run-директория лежит вне рабочего проекта, поэтому прямые
# Write/redirect в неё дёргают запрос прав. Правило: ВСЕ мутации run-дир идут только
# через этот скрипт (он один в allow-list). Промежуточные файлы пишем в scratchpad
# сессии (авто-разрешён), а сюда переносим ГОТОВЫЙ артефакт командой `stage`.
#
# Использование:
#   run_dir.sh create <host> <repo> <mr>
#       Создаёт <host>-<repo>-<mr>-<YYYYMMDDThhmmss> под базой, засевает state.json
#       (host/repo/mr/created_at/updated_at/step_completed=0) и печатает путь к дир.
#   run_dir.sh resolve <host> <repo> <mr>
#       Ищет существующую <host>-<repo>-<mr>-* со state.json, где step_completed < 4.
#       Печатает путь новейшей или ничего + exit 1.
#   run_dir.sh meta <dir> <key> <value> [<key> <value> ...]
#       Проставляет строковые top-level поля в state.json (ticket/base/mode/…) +
#       обновляет updated_at. Заменяет ручной python/jq на стороне вызывающего.
#   run_dir.sh stage <dir> <step_completed> <localfile> [<localfile> ...]
#       Копирует готовые артефакты из scratchpad в <dir> (по basename) и делает
#       checkpoint <step_completed>. Это единственный способ положить файл в run-дир.
#   run_dir.sh checkpoint <dir> <step_completed>
#       Ставит step_completed + updated_at в state.json, сохраняя прочие поля.
#
# Зависимости: coreutils, опционально jq (без него - деградация до плоского state.json).

BASE_DIR="${REVIEW_RUNS_DIR:-$HOME/.claude/review-runs}"

usage() {
  sed -n '4,40p' "$0" | sed 's/^# \{0,1\}//'
  exit "${1:-2}"
}

now_ts() { date +%Y%m%dT%H%M%S; }

# sanitize - слэши и прочие небезопасные для имени символы → дефисы.
sanitize() {
  printf '%s' "$1" | sed -E 's#[^A-Za-z0-9._-]+#-#g; s#-+#-#g; s#^-##; s#-$##'
}

# json_set <file> <key> <value> - атомарно проставить строковое поле.
json_set() {
  local file="$1" key="$2" val="$3" tmp
  [ -f "$file" ] || printf '{}' > "$file"
  if command -v jq >/dev/null 2>&1; then
    tmp="$(mktemp)"
    jq --arg k "$key" --arg v "$val" '.[$k] = $v' "$file" > "$tmp"
    mv "$tmp" "$file"
  else
    # Фолбэк без jq: грубо, но переживает отсутствие jq.
    if grep -q "\"$key\"" "$file" 2>/dev/null; then
      tmp="$(mktemp)"
      sed -E "s#\"$key\"[[:space:]]*:[[:space:]]*\"[^\"]*\"#\"$key\": \"$val\"#" "$file" > "$tmp"
      mv "$tmp" "$file"
    else
      tmp="$(mktemp)"
      sed -E "s#^\{#{\"$key\": \"$val\", #" "$file" > "$tmp"
      mv "$tmp" "$file"
    fi
  fi
}

# json_set_num <file> <key> <intval>
json_set_num() {
  local file="$1" key="$2" val="$3" tmp
  [ -f "$file" ] || printf '{}' > "$file"
  if command -v jq >/dev/null 2>&1; then
    tmp="$(mktemp)"
    jq --arg k "$key" --argjson v "$val" '.[$k] = $v' "$file" > "$tmp"
    mv "$tmp" "$file"
  else
    if grep -q "\"$key\"" "$file" 2>/dev/null; then
      tmp="$(mktemp)"
      sed -E "s#\"$key\"[[:space:]]*:[[:space:]]*[0-9]+#\"$key\": $val#" "$file" > "$tmp"
      mv "$tmp" "$file"
    else
      tmp="$(mktemp)"
      sed -E "s#^\{#{\"$key\": $val, #" "$file" > "$tmp"
      mv "$tmp" "$file"
    fi
  fi
}

cmd_create() {
  [ "$#" -eq 3 ] || usage
  local host_raw="$1" repo_raw="$2" mr_raw="$3" ts name dir file
  ts="$(now_ts)"
  name="$(sanitize "$host_raw")-$(sanitize "$repo_raw")-$(sanitize "$mr_raw")-${ts}"
  dir="${BASE_DIR}/${name}"
  mkdir -p "$dir"
  file="${dir}/state.json"
  printf '{}' > "$file"
  json_set     "$file" host       "$host_raw"
  json_set     "$file" repo       "$repo_raw"
  json_set     "$file" mr         "$mr_raw"
  json_set     "$file" created_at "$ts"
  json_set     "$file" updated_at "$ts"
  json_set_num "$file" step_completed 0
  printf '%s\n' "$dir"
}

cmd_resolve() {
  [ "$#" -eq 3 ] || usage
  local host repo mr prefix best="" d step
  host="$(sanitize "$1")"; repo="$(sanitize "$2")"; mr="$(sanitize "$3")"
  prefix="${host}-${repo}-${mr}-"
  [ -d "$BASE_DIR" ] || return 1
  while IFS= read -r d; do
    [ -n "$d" ] || continue
    [ -f "${d}/state.json" ] || continue
    if command -v jq >/dev/null 2>&1; then
      step="$(jq -r '.step_completed // 0' "${d}/state.json" 2>/dev/null || echo 0)"
    else
      step="$(grep -oE '"step_completed"[[:space:]]*:[[:space:]]*[0-9]+' "${d}/state.json" 2>/dev/null | grep -oE '[0-9]+$' | head -n1)"
      step="${step:-0}"
    fi
    if [ "$step" -lt 4 ] 2>/dev/null; then best="$d"; break; fi
  done < <(find "$BASE_DIR" -maxdepth 1 -type d -name "${prefix}*" 2>/dev/null | sort -r)
  [ -n "$best" ] && { printf '%s\n' "$best"; return 0; }
  return 1
}

cmd_checkpoint() {
  [ "$#" -eq 2 ] || usage
  local dir="$1" step="$2" file
  mkdir -p "$dir"
  file="${dir}/state.json"
  json_set_num "$file" step_completed "$step"
  json_set     "$file" updated_at "$(now_ts)"
  printf '%s\n' "$file"
}

cmd_meta() {
  [ "$#" -ge 3 ] || usage
  local dir="$1"; shift
  local file="${dir}/state.json"
  mkdir -p "$dir"
  [ -f "$file" ] || printf '{}' > "$file"
  while [ "$#" -ge 2 ]; do
    json_set "$file" "$1" "$2"
    shift 2
  done
  json_set "$file" updated_at "$(now_ts)"
  printf '%s\n' "$file"
}

cmd_stage() {
  [ "$#" -ge 3 ] || usage
  local dir="$1" step="$2"; shift 2
  mkdir -p "$dir"
  local src
  for src in "$@"; do
    [ -f "$src" ] || { printf 'stage: нет файла: %s\n' "$src" >&2; exit 1; }
    cp -f "$src" "${dir}/$(basename "$src")"
  done
  cmd_checkpoint "$dir" "$step" >/dev/null
  printf '%s\n' "$dir"
}

main() {
  [ "$#" -ge 1 ] || usage
  case "$1" in
    -h|--help|help) usage 0 ;;
    create)     shift; cmd_create "$@" ;;
    resolve)    shift; cmd_resolve "$@" ;;
    meta)       shift; cmd_meta "$@" ;;
    stage)      shift; cmd_stage "$@" ;;
    checkpoint) shift; cmd_checkpoint "$@" ;;
    *) usage ;;
  esac
}

main "$@"
