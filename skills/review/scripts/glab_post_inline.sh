#!/usr/bin/env bash
set -euo pipefail

# glab_post_inline.sh - постинг inline-комментария в GitLab MR через discussions API.
#
# Использование:
#   glab_post_inline.sh <enc_project> <iid> <file> <line> <side> <body>
#     <enc_project> - URL-энкодед path проекта (например group%2Fproject)
#     <iid>         - internal id merge request
#     <file>        - путь к файлу
#     <line>        - номер строки
#     <side>        - new | old (new_* или old_* позиция)
#     <body>        - текст комментария
#
# Хост GitLab: env GITLAB_HOST, иначе хост из `git remote get-url origin` в cwd.
# Найденный хост передаётся в glab явно (--hostname / -R), поэтому скрипт не уходит
# молча на дефолтный gitlab.com, если cwd не указывает на нужный remote.
#
# Поведение: резолвит .diff_refs (base_sha/start_sha/head_sha) у MR, постит
# discussion с position[position_type]=text. Затем ПРОВЕРЯЕТ, что созданная
# заметка действительно инлайновая (type == DiffNote); если сервер позицию
# проигнорировал - удаляет заметку-сироту и фолбэчит на общую `glab mr note`.
# Если POST падает (ошибка позиции / строка вне diff) - тоже фолбэк.
#
# ВАЖНО: тело уходит как JSON с явным `Content-Type: application/json`.
# Форма `-f "position[new_line]=…"` НЕ работает: GitLab не разбирает
# bracket-поля из form-encoded, молча игнорирует позицию и создаёт обычную
# заметку, при этом отвечая 201 - то есть по коду возврата успех неотличим.
# Без заголовка Content-Type API отвечает 415.
#
# Зависимости: уже авторизованный glab, jq, git.

usage() {
  sed -n '3,31p' "$0" | sed 's/^# \{0,1\}//'
  exit "${1:-2}"
}

case "${1:-}" in -h|--help|help) usage 0 ;; esac
[ "$#" -eq 6 ] || usage

ENC="$1"; IID="$2"; FILE="$3"; LINE="$4"; SIDE="$5"; BODY="$6"

case "$SIDE" in
  new|old) ;;
  *) echo "error: <side> must be 'new' or 'old'" >&2; usage ;;
esac

case "$LINE" in
  ''|*[!0-9]*) echo "error: <line> must be a positive integer (got: ${LINE})" >&2; usage ;;
esac

# remote_host - хост из fetch URL origin (scp- или URL-форма), пусто если remote нет.
remote_host() {
  local url
  url="$(git remote get-url origin 2>/dev/null || true)"
  [ -n "$url" ] || return 0
  if [ "${url#*://}" != "$url" ]; then
    url="${url#*://}"
    url="${url#*@}"
    url="${url%%/*}"
    url="${url%%:*}"
  else
    url="${url#*@}"
    url="${url%%:*}"
  fi
  printf '%s' "$url"
}

HOST="${GITLAB_HOST:-$(remote_host)}"
HOST_ARGS=()
REPO_ARGS=()
if [ -n "$HOST" ]; then
  HOST_ARGS=(--hostname "$HOST")
  REPO_ARGS=(-R "${HOST}/${ENC//%2F//}")
else
  echo "warn: GitLab host unknown (no GITLAB_HOST, no origin remote); glab will use its default host" >&2
fi

gl_api() {
  glab api ${HOST_ARGS[@]+"${HOST_ARGS[@]}"} "$@"
}

fallback() {
  echo "fell back: posting general note via 'glab mr note'" >&2
  glab mr note "$IID" ${REPO_ARGS[@]+"${REPO_ARGS[@]}"} -m "${BODY} (${FILE}:${LINE})"
}

# Резолвим diff_refs.
refs_json="$(gl_api "projects/${ENC}/merge_requests/${IID}" 2>/dev/null || true)"
base_sha="$(printf '%s' "$refs_json"  | jq -r '.diff_refs.base_sha  // empty' 2>/dev/null || true)"
start_sha="$(printf '%s' "$refs_json" | jq -r '.diff_refs.start_sha // empty' 2>/dev/null || true)"
head_sha="$(printf '%s' "$refs_json"  | jq -r '.diff_refs.head_sha  // empty' 2>/dev/null || true)"

if [ -z "$base_sha" ] || [ -z "$head_sha" ]; then
  echo "warn: could not resolve diff_refs" >&2
  fallback
  exit 0
fi
# start_sha пустой у части MR - GitLab требует поле, base_sha тут безопасная замена.
[ -n "$start_sha" ] || start_sha="$base_sha"

# Собираем JSON-тело. old_path/new_path задаём оба: для добавленных файлов
# GitLab принимает одинаковые пути, а без old_path отвергает позицию.
payload="$(jq -n \
  --arg body "$BODY" \
  --arg base "$base_sha" \
  --arg start "$start_sha" \
  --arg head "$head_sha" \
  --arg path "$FILE" \
  --arg side "$SIDE" \
  --argjson line "$LINE" \
  '{
     body: $body,
     position: (
       {
         position_type: "text",
         base_sha:  $base,
         start_sha: $start,
         head_sha:  $head,
         old_path:  $path,
         new_path:  $path
       }
       + (if $side == "new" then {new_line: $line} else {old_line: $line} end)
     )
   }')"

resp="$(printf '%s' "$payload" \
  | gl_api "projects/${ENC}/merge_requests/${IID}/discussions" \
      -X POST -H "Content-Type: application/json" --input - 2>/dev/null || true)"

note_id="$(printf '%s' "$resp"   | jq -r '.notes[0].id   // empty' 2>/dev/null || true)"
note_type="$(printf '%s' "$resp" | jq -r '.notes[0].type // empty' 2>/dev/null || true)"

if [ "$note_type" = "DiffNote" ]; then
  echo "posted inline: ${FILE}:${LINE} (${SIDE}) note_id=${note_id}"
  exit 0
fi

# Заметка создалась, но не инлайновая - убираем сироту, чтобы фолбэк не задвоил коммент.
if [ -n "$note_id" ]; then
  echo "warn: server ignored position (created ${note_type:-unknown}); removing stray note ${note_id}" >&2
  gl_api "projects/${ENC}/merge_requests/${IID}/notes/${note_id}" -X DELETE >/dev/null 2>&1 || true
fi

fallback
