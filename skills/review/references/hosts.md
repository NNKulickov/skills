# Рецепты по хостам (glab / gh)

Практический cookbook: получить diff, посмотреть MR/PR, запостить inline-комментарий и
вытащить собственные комментарии автора ревью. Используется в шагах 0, 2, 4.

## GitLab (glab)

Path проекта для API нужно URL-энкодить: `group/project` → `group%2Fproject` (ниже `<enc>`).
`<gitlab-host>` - хост GitLab из `git remote get-url origin` (для gitlab.com - `gitlab.com`, для
self-hosted - свой хост).

**Diff / view:**
```
glab mr list --source-branch <branch>
glab mr view <iid>
glab mr diff <iid>
```

**POST inline-комментария (discussion).** Используем скрипт:
```
scripts/glab_post_inline.sh <enc> <iid> <file> <line> <side> <body>   # side = new|old
```
Резолвит `diff_refs`, выбирает new/old-позицию, проверяет что заметка вышла инлайновой
(`type == DiffNote`) и фолбэчит на `glab mr note` при отклонённой позиции. Хост берёт из env
`GITLAB_HOST`, иначе из `origin` в cwd, и передаёт в `glab` явно.

⚠️ **Self-hosted GitLab: следи, чтобы хост определился.** Если сессия запущена не из worktree
целевого репо (у cwd нет `origin`) и `GITLAB_HOST` не задан, `glab` уходит на дефолтный
`gitlab.com`: `diff_refs` не резолвятся, скрипт фолбэчит на `glab mr note`, а тот падает с
«No git remotes found» - итог exit 1 и **ничего не запощено**. Лечится префиксом:
`GITLAB_HOST=<gitlab-host> ~/.claude/skills/review/scripts/glab_post_inline.sh …`
(тот же префикс или `--hostname` нужен и `glab api` для чтения; `glab mr view/diff
-R <gitlab-host>/<path>` работает без него). Форма с префиксом не матчится с allow-rule на скрипт -
один запрос прав за прогон, это дешевле молчаливого промаха.

⚠️ Не переписывать постинг на `glab api -f "position[new_line]=…"`: GitLab не разбирает
bracket-поля из form-encoded - молча игнорирует позицию, создаёт обычную заметку и всё
равно отвечает 201, так что по коду возврата успех неотличим от промаха. Позицию слать
только JSON-телом: `-H "Content-Type: application/json" --input <file>` (без заголовка
API отдаёт 415).

**REPLY в существующую дискуссию** (ответ на замечание ревьюера, в т.ч. на `suggestion`):
```
glab api --hostname <gitlab-host> -X POST \
  "projects/<enc>/merge_requests/<iid>/discussions/<discussion_id>/notes" -f body='<текст>'
```
`discussion_id` берём из `GET …/discussions?per_page=100`. Ответ наследует позицию родителя,
так что для reply на inline-замечание `position` передавать не нужно.

⚠️ `glab api` **с записью - обязательно с `--hostname <gitlab-host>`** для self-hosted: если
дефолтный хост в конфиге glab - `gitlab.com`, токена там нет, и POST падает `401 Unauthorized`
(GET при этом может пройти - успех GET не доказывает, что хост определился верно). Тело - в
**одинарных** кавычках: в двойных shell выполнит бэктики из markdown как команду.

**Лог/трейс CI job** (используется судьёй, `judge.md`, для проверки утверждений про упавший
pipeline):
```
glab ci get --hostname <gitlab-host> --repo <owner/repo> --pipeline-id <id>
glab api --hostname <gitlab-host> "projects/<enc>/jobs/<job_id>/trace"
```
Тот же риск, что и с POST выше, но острее: судья запускается в свежем субагенте без гарантии, что
его cwd указывает на нужный git-remote (в отличие от генерирующей подсессии, у которой cwd =
`--worktree` целевого репо, review-engine.md §1). Без `--hostname` GET **тоже может «успешно»
пройти** - но по дефолтному `gitlab.com`, вернув пустой список job'ов или чужой pipeline с тем же
номером, а не ошибку. Успешный ответ без явного хоста ничего не доказывает - не читать вывод, пока
хост не указан явно.

**FETCH собственных комментариев автора (шаг 4).** Используем скрипт:
```
scripts/fetch_author_comments.sh <host> <iid> [user]
```
`user` по умолчанию - env `REVIEW_USER`, иначе текущий авторизованный пользователь `glab`.

## GitHub (gh)

`<owner>/<repo>` - из remote.

**Diff / view:**
```
gh pr list --head <branch>
gh pr view <n> --json ...
gh pr diff <n>
```

**POST inline review-комментария** (для gh скрипта нет - прозой). Предпочтительно
`mcp__github_inline_comment__create_inline_comment`, если MCP доступен. Иначе через API:
```
gh pr view <n> --json headRefOid          # head sha
gh api repos/<owner>/<repo>/pulls/<n>/comments -X POST \
  -f body="<текст>" \
  -f commit_id=<sha> \
  -f path=<file> \
  -F line=<line> \
  -f side=RIGHT
```

**Fallback** - общий комментарий:
```
gh pr comment <n> --body "<текст>"
```

**FETCH собственных комментариев автора (шаг 4).** Используем скрипт (сам определяет
GitHub по `<host>`, тянет и inline-, и issue-комментарии):
```
scripts/fetch_author_comments.sh <host> <n> [user]
```
`user` по умолчанию - env `REVIEW_USER`, иначе текущий авторизованный пользователь `gh`.

## Общее

- Постинг идёт от авторизованного пользователя → комментарии появляются под его именем.
  При сомнении - проверить: `glab auth status` / `gh auth status`.
- Batch-постинг: постим все одобренные (`[x]`) пункты, собирая возвращённые id/url в
  `posted.md`.
