# Claude Command: Commit

This command helps you create well-formatted commits with conventional commit messages and emoji.

## Usage

To create a commit, just type:

```
/commit
```

Or with options:

```
/commit --no-verify
```

## Basic Format

You must create appropriate commit messages following the Conventional Commits specification.

```
<type>[optional scope]: <description>

[optional body]

[optional footer(s)]
```

### Type (Required)

Use one of the following types:

- **feat**: A new feature
- **fix**: A bug fix
- **docs**: Documentation only changes
- **style**: Changes that do not affect the meaning of the code (white-space, formatting, missing semi-colons, etc)
- **refactor**: A code change that neither fixes a bug nor adds a feature
- **perf**: A code change that improves performance
- **test**: Adding missing tests or correcting existing tests
- **chore**: Changes to the build process or auxiliary tools and libraries (does not affect production code)
- **ci**: Changes to CI configuration files and scripts
- **build**: Changes that affect the build system or external dependencies
- **revert**: Reverts a previous commit

### Scope (Optional)

Indicates the scope of the change (e.g., auth, user, api, ui)

### Description (Required)

- Write in imperative present tense ("add" not "added" or "adds")
- Start with lowercase letter
- Do not end with a period (.)
- Recommended to keep under 50 characters

### Body (Optional)

- Explain the reason for the change or detailed description
- Each line should be under 72 characters
- Separate from description with a blank line

### Footer (Optional)

- Breaking changes: `BREAKING CHANGE: <description>`
- Issue references: `Closes #123`, `Fixes #456`

### Examples

```
feat(auth): add OAuth2 authentication

Implement OAuth2 flow with Google and GitHub providers.
This allows users to sign in with their existing accounts.

Closes #123
```

```
fix: prevent memory leak in user session

The session cleanup was not properly disposing of event listeners,
causing memory to accumulate over time.

Fixes #456
```

```
docs: update installation guide

Add steps for macOS installation and troubleshooting section.
```

```
BREAKING CHANGE: remove deprecated API endpoints

The v1 API endpoints have been removed. Please migrate to v2 API.
```

## Guidelines

- **Accurate representation**: Accurately represent the changes made
- **Breaking changes**: Always specify breaking changes in the footer when applicable
- **Atomic commits**: Each commit should contain related changes that serve a single purpose
- **Split large changes**: If changes touch multiple concerns, split them into separate commits
- **Staged files**: If specific files are already staged, the command will only commit those files
- **Auto-staging**: If no files are staged, it will automatically stage all modified and new files
- **Message construction**: The commit message will be constructed based on the changes detected
- **Diff review**: Before committing, the command will review the diff to identify if multiple commits would be more appropriate
- **Multiple commits**: If suggesting multiple commits, it will help you stage and commit the changes separately
- **Message validation**: Always reviews the commit diff to ensure the message matches the changes

## Guidelines for Splitting Commits

When analyzing the diff, consider splitting commits based on these criteria:

1. **Different concerns**: Changes to unrelated parts of the codebase
2. **Different types of changes**: Mixing features, fixes, refactoring, etc.
3. **File patterns**: Changes to different types of files (e.g., source code vs documentation)
4. **Logical grouping**: Changes that would be easier to understand or review separately
5. **Size**: Very large changes that would be clearer if broken down
