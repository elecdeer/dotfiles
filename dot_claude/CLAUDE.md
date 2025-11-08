# CLAUDE.md

This is global guidance for Claude Code.

## Conversation Guidelines

- YOU MUST reply in Japanese.
- YOU MUST ask for clarification before executing if there are any unclear points.

## Work Completion Guidelines

- Perform git commits when work reaches a milestone.
  - No permission is required to perform git commits.
  - However, git commit commands require execution confirmation through the agent framework.
  - Determine the commit message in advance and present it when executing the commit.
  - If the user rejects the commit execution, ask what should be done next.

## TypeScript Guidelines

### Package Manager

- Use pnpm > npm > yarn (in order of preference).
- **YOU MUST always explicitly use the `run` command when executing scripts; do not omit it.**
  - Correct: `pnpm run build:app`
  - Incorrect: `pnpm build:app`

### Type Safety

- IMPORTANT: Enable `strict: true` in tsconfig.json.
- Use optional chaining `?.` and nullish coalescing `??` for null handling.
- Use ES modules for imports; avoid `require()`.
- Follow project conventions when choosing between `type` and `interface`.
- **YOU MUST strictly avoid using `any` type and type assertions via `as unknown`; only use when explicitly permitted by the user.**
  - When necessary, add linter disable comments with explanations.
- Minimize type assertions; only use when absolutely necessary.
  - When used, clearly document the reason in comments.
- **YOU MUST NOT use `// @ts-ignore` or `// @ts-expect-error` to bypass type checking.**
- Actively utilize utility types such as `Partial<T>` and `Record<K,V>`.
  - If type-fest is available in the project, also utilize its utility types.
- Do not omit type annotations unless they are obvious.
- Avoid using `enum`; use union types or literal types instead.

### Documentation

- YOU MUST add JSDoc comments to all functions unless the explanation is clearly unnecessary.

  Example:

  ```typescript
  /**
   * Gets the user's full name.
   */
  export function getFullName(user: User): string {
    return `${user.firstName} ${user.lastName}`;
  }
  ```

## General Development Guidelines

### Version Control

- Use git to revert changes; avoid manual modifications whenever possible.
- **Important: Follow project conventions when writing comments, documentation, and commit messages (English or Japanese).**

### Testing

- **YOU MUST always add unit tests for new code.**
- **Important: When tests fail, identify the cause and clarify whether it's an implementation issue or a test code issue. Ask the user which to fix.**

### Library Management

- When introducing libraries, use commands like `pnpm view` to check the latest stable version and maintenance status.
- When researching how to use libraries, prioritize using context7 MCP.

### Code Quality

- Check linter and formatter configurations and avoid writing code that violates them from the start.
- When modifying implementations, also update related test code and documentation.

### Changesets

- YOU MUST always add a changeset before pushing for repositories using changesets.
