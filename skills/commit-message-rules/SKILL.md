---
name: commit-message-rules
description: >
  Commit message and commit history rules. Use this skill whenever creating a git commit,
  drafting a commit message, deciding whether to amend/rebase instead of adding a commit,
  or reviewing commit history before push. It applies even when the user only says
  "commit", "コミットして", "commit message", "amend", or "rebase".
---

# Commit Message Rules

Use this skill before creating a commit or proposing a commit message.

## Workflow

### 1. Check project-specific rules first

Before deciding a commit message, inspect the repository for project-specific conventions:

- `AGENTS.md`, `CLAUDE.md`, `CONTRIBUTING.md`, `README.md`
- `.gitmessage`, `.commitlintrc*`, `commitlint.config.*`
- recent commit history with `git log --oneline`

Project-specific instructions override this skill. If the project does not define its own commit format, use Conventional Commits.

### 2. Match the language of existing commits

Write the commit message in the same language as the existing commit history.

- If recent commits are mostly English, write English.
- If recent commits are mostly Japanese, write Japanese.
- If the history is mixed, follow the dominant style for the touched area or the latest related commits.

### 3. Use Conventional Commits by default

When the project has no stricter rule, use this shape:

```text
<type>(<scope>): <summary>
```

Common types:

- `feat`: user-facing feature
- `fix`: bug fix
- `docs`: documentation only
- `style`: formatting only, no behavior change
- `refactor`: code restructuring without behavior change
- `test`: tests only
- `build`: build system or dependencies
- `ci`: CI configuration
- `chore`: maintenance that does not fit the above

Use a scope only when it helps identify the changed area. Keep the summary concise and imperative where that matches the repository style.

### 4. Avoid BREAKING CHANGE for non-libraries

Do not add `!` or a `BREAKING CHANGE:` footer unless the target is a library, public API, SDK, package, CLI, or another artifact where downstream users depend on compatibility.

For applications, dotfiles, internal tools, and one-off automation, describe the change normally unless the repository's own rules require breaking-change notation.

### 5. Keep the message to one line when enough

Use only the first line when the reason is obvious from the diff or the change is small.

Add a body only when it provides useful context that is not clear from the diff, such as:

- why the approach was chosen
- migration or operational notes
- constraints, tradeoffs, or follow-up risks

Avoid bodies that restate the summary or describe every changed file mechanically.

### 6. Prefer amending/rebasing for continuation work before push

Before creating a new commit, check whether the staged change looks like a continuation of the immediately previous commit.

Continuation signals include:

- fixes a mistake introduced by the previous commit
- adds missing tests or documentation for the previous commit
- applies reviewer or lint feedback for the same logical change
- touches the same small area with the same intent

If it is continuation work and the previous commit has not been pushed, absorb it with `git commit --amend` or an interactive rebase instead of creating a new commit.

Only rewrite local, unpushed commits. Do not amend, rebase, or otherwise rewrite pushed commits unless the user explicitly asks for that and accepts the implications.

### 7. Do not bypass 1Password SSH commit signing

This environment may use 1Password SSH commit signing. A commit can be rejected if signing fails or requires user interaction.

If commit signing rejects the commit, ask the user how to proceed. Do not bypass signing with options such as `--no-gpg-sign`, config changes, environment overrides, or alternate commit commands.

## Examples

```text
feat(auth): add passkey login
fix(parser): handle empty input
docs: update setup instructions
chore: refresh generated config
```

For a dotfiles or application change that removes an old option:

```text
refactor(shell): remove legacy prompt setup
```

Do not write this unless the repository is a library or public API where consumers need breaking-change signaling:

```text
refactor(shell)!: remove legacy prompt setup
```
