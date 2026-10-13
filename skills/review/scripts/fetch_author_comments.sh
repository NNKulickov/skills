#!/usr/bin/env bash
set -euo pipefail

# fetch_author_comments.sh - вытащить собственные комментарии автора ревью из MR/PR.
#
# Использование:
#   fetch_author_comments.sh <host> <iid_or_prnum> [user]
#     <host>          - хост (содержит 'gitlab' → GitLab ветка, 'github' → GitHub;
#                       для self-hosted GitLab без 'gitlab' в имени задай GITLAB_HOST=<host>)
#     <iid_or_prnum>  - iid MR (GitLab) или номер PR (GitHub)
#     [user]          - username; по умолчанию env REVIEW_USER, иначе текущий
#                       авторизованный пользователь glab/gh
#
# GitLab: нужен URL-энкодед path проекта - берётся из env GITLAB_PROJECT_ENC либо
#         выводится из `git remote get-url origin` (group/repo → group%2Frepo).
#         Хост передаётся в glab явно (--hostname <host>).
# GitHub: <owner>/<repo> выводится из remote.
#
# Печатает блоки «file:line + body».
# Зависимости: уже авторизованные glab/gh, jq, git.

usage() {
  sed -n '3,21p' "$0" | sed 's/^# \{0,1\}//'
  exit "${1:-2}"
}

case "${1:-}" in -h|--help|help) usage 0 ;; esac
[ "$#" -ge 2 ] || usage

HOST="$1"
NUM="$2"
USER_ARG="${3:-${REVIEW_USER:-}}"

# derive_owner_repo - из remote origin вытащить путь проекта "group/repo" (без .git).
# Сохраняет вложенные группы (group/subgroup/repo) - их требует GitLab API.
derive_owner_repo() {
  local url
  url="$(git remote get-url origin 2>/dev/null || true)"
  [ -n "$url" ] || return 1
  url="${url%.git}"

  if [ "${url#*://}" != "$url" ]; then
    # URL-форма: scheme://[user@]host[:port]/group/repo
    url="${url#*://}"
    url="${url#*@}"
    url="${url#*/}"     # отрезаем host[:port]
  else
    # scp-форма: [user@]host:group/repo
    url="${url#*@}"
    url="${url#*:}"     # отрезаем host
  fi

  printf '%s' "$url"
}

is_gitlab=0
if printf '%s' "$HOST" | grep -qi 'gitlab'; then
  is_gitlab=1
elif [ -n "${GITLAB_HOST:-}" ] && [ "$HOST" = "$GITLAB_HOST" ]; then
  is_gitlab=1
fi

if [ "$is_gitlab" -eq 1 ]; then
  # ---- GitLab ----
  user="$USER_ARG"
  if [ -z "$user" ]; then
    user="$(glab api --hostname "$HOST" user 2>/dev/null | jq -r '.username // empty' || true)"
  fi
  [ -n "$user" ] || { echo "error: cannot determine GitLab user; pass [user] or set REVIEW_USER" >&2; exit 1; }
  enc="${GITLAB_PROJECT_ENC:-}"
  if [ -z "$enc" ]; then
    path="$(derive_owner_repo || true)"
    [ -n "$path" ] || { echo "error: cannot derive project path; set GITLAB_PROJECT_ENC" >&2; exit 1; }
    # URL-энкодим слэши
    enc="${path//\//%2F}"
  fi
  glab api --hostname "$HOST" "projects/${enc}/merge_requests/${NUM}/discussions?per_page=100" \
    | jq -r '.[] | .notes[]
        | select(.author.username==$u)
        | select(.system==false)
        | "file: \(.position.new_path // "-"):\(.position.new_line // .position.old_line // "")\n\(.body)\n---"' \
        --arg u "$user"

elif printf '%s' "$HOST" | grep -qi 'github'; then
  # ---- GitHub ----
  user="$USER_ARG"
  if [ -z "$user" ]; then
    user="$(gh api user --jq '.login' 2>/dev/null || true)"
  fi
  [ -n "$user" ] || { echo "error: cannot determine GitHub user; pass [user] or set REVIEW_USER" >&2; exit 1; }
  slug="$(derive_owner_repo || true)"
  [ -n "$slug" ] || { echo "error: cannot derive owner/repo from remote" >&2; exit 1; }
  owner="${slug%%/*}"
  repo="${slug#*/}"

  echo "# inline review comments"
  gh api "repos/${owner}/${repo}/pulls/${NUM}/comments" --paginate \
    --jq ".[] | select(.user.login==\"${user}\") | \"file: \(.path):\(.line // .original_line // \"\")\n\(.body)\n---\""

  echo "# issue-level PR comments"
  gh api "repos/${owner}/${repo}/issues/${NUM}/comments" --paginate \
    --jq ".[] | select(.user.login==\"${user}\") | \"\(.body)\n---\""

else
  echo "error: <host> must contain 'gitlab' or 'github', or equal GITLAB_HOST (got: ${HOST})" >&2
  exit 2
fi
