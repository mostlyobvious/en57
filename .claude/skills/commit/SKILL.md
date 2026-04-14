---
name: commit
description: Create a git commit following project conventions. Use this skill when asked to commit changes, group changes into commits, or prepare commits.
---

# Commit

## Format

```
:<gitmoji>: <Capitalized imperative subject ≤50 chars>

<Body wrapped at 72 cols, explaining why.>
```

- Subject: gitmoji + space + capitalized imperative ("Fix bug", not "Fixed"). No trailing period.
- Blank line between subject and body. Body wrapped at 72 cols.
- Prefer `-` bullet points in the body over prose paragraphs. Hanging indent for wrapped lines.
- Body explains **why** (and, when non-obvious, **how** and **what effects** — benchmarks, side effects, follow-ups). Skip questions that don't apply. Never restate the diff.

## Gitmoji

Match intent, not file type. One per commit.

| Code | When |
| --- | --- |
| `:tada:` | Initial commit |
| `:sparkles:` | New user-facing feature |
| `:bug:` | Bug fix |
| `:memo:` | Docs, changelog |
| `:wrench:` | Config / tooling (Gemfile.lock, `.mutant.yml`, `.standard.yml`, CI) |
| `:recycle:` | Refactor, no behavior change |
| `:white_check_mark:` | Tests |
| `:zap:` | Performance |
| `:fire:` | Remove code / files |
| `:lock:` | Security fix |
| `:arrow_up:` / `:arrow_down:` | Upgrade / downgrade dependency |
| `:rocket:` | Release / deployment |

Else: <https://gitmoji.dev/>.

## Scope

- One logical change per commit; split unrelated concerns.
- User-facing changes update `CHANGELOG.md` (user-perspective only: no internal refactors).

## Procedure

1. `git status` + `git diff --staged` (and `git diff` if unstaged) to confirm scope.
2. Draft subject + body.
3. Present the staged files and message for approval
4. Wait for user confirmation before committing
5. No `--no-verify`. No amending published commits. No force-push without explicit request.
