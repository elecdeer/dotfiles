---
name: create-github-pr
description: Create GitHub Pull Requests with comprehensive workflow including change analysis, issue search, PR template application, user confirmation, and gh CLI integration. Use when creating a PR from the current branch, when asked to "create a pull request", "make a PR", "open a PR", or similar requests.
---

# Create GitHub Pull Request

This skill provides a comprehensive workflow for creating GitHub Pull Requests using gh CLI.

## Bundled Scripts

This skill includes helper scripts in `scripts/` subdirectory alongside this SKILL.md file.

When this skill is loaded, the path of this SKILL.md file is known. Derive the scripts directory from it:

- SKILL.md path example: `/path/to/.claude/skills/create-github-pr/SKILL.md`
- Scripts directory: `/path/to/.claude/skills/create-github-pr/scripts/`

In the steps below, `<SKILL_DIR>` refers to the directory containing this SKILL.md file.

- **analyze_branch_changes.sh** - Analyzes branch information, determines base branch using decoration-based method, lists changed files with diff stats, and shows commit log
- **verify_remote_branch.sh** - Verifies remote branch status and provides human-readable status report
- **create_pr_draft.sh** - Creates empty temporary file for PR content
- **create_pr_from_draft.sh** - Creates PR using gh CLI from draft file with YAML frontmatter

## Workflow

### 1. Analyze Changes

Run `analyze_branch_changes.sh` to collect branch information:

```bash
<SKILL_DIR>/scripts/analyze_branch_changes.sh
```

This outputs:

- Branch information (current, base, default)
- Remote status (exists, commits ahead)
- Stacked PR check (if base branch is not default branch)
  - Lists any existing PRs for the base branch
  - Indicates if this will be a stacked PR
- Changed files with line additions/deletions
- Commit log

After collecting this information:

- Read content of changed files to understand modifications
- Identify scope and impact of changes

### 2. Search for Related Issues

Use gh CLI to find issues related to this change:

- Use keywords from branch name, commit messages, or changed file names (from Step 1 output)
- Search with `gh issue list --search "<keywords>"` or `gh search issues "<keywords>"`
- Look for open issues this PR might resolve or close
- Note issue numbers to reference in PR description
- Check for existing discussions or context around this change

### 4. Gather Context

- Read PR template from `.github/pull_request_template.md` (if exists)
- Follow template structure and requirements
- Use language specified in template or appropriate for project
- Only describe what was actually changed - do not mention unrelated items

### 5. Analyze Impact

Based on changed files compared with `origin/<base-branch>`, determine:

- What components/modules are affected
- Whether changes are breaking or non-breaking
- What type of change this represents (feature, fix, refactor, etc.)

### 6. Draft PR Content

Create PR description following template structure.

If a base branch PR was found in Step 3 (stacked PR scenario):

- Include a note that this PR is built on top of the base PR (e.g., "Built on top of #123" or "Depends on #123")
- Place this information prominently, typically near the top of the description
- Consider adding it as a separate section or as part of the introduction

### 7. User Confirmation

Allow user to review and edit PR content before creation:

1. Use `create_pr_draft.sh` to create empty temporary file:

   ```bash
   <SKILL_DIR>/scripts/create_pr_draft.sh
   ```

   Script outputs the temporary file path.

2. Write PR content to the file with YAML frontmatter format using builtin tool:

   ```markdown
   ---
   title: <proposed PR title>
   base: <base branch>
   head: <head branch>
   ---

   <proposed PR body content>
   ```

3. Present the temporary file path to the user
4. Use the `ask_questions` tool to prompt user confirmation:
   - Ask: "PR draft has been created at `<file-path>`. Please review and edit the file as needed. Have you finished editing?"
   - Provide options like "Finished editing", "Cancel PR creation"
   - Wait for user response
5. If user selects "Cancel PR creation", stop the PR creation process
6. If user confirms they finished editing, read the edited content from temporary file
7. Parse frontmatter to extract title, base, and head branch
8. Verify the file still contains content (non-empty PR description)
9. If valid, proceed with PR creation using parsed metadata and body
10. Do NOT delete temporary file - leave it for user reference

### 8. Verify Remote Push

Before creating PR, verify head branch is pushed to remote using `verify_remote_branch.sh`:

```bash
<SKILL_DIR>/scripts/verify_remote_branch.sh <head-branch>
```

Script outputs human-readable status report including:

- Whether remote branch exists
- Synchronization status (up to date, ahead, behind, diverged, or not pushed)
- Number of commits ahead/behind
- Recommended actions

Based on the script output:

1. If status is "Not pushed":
   - Inform user that branch needs to be pushed
   - Ask if they want to push branch now
   - If yes, execute `git push -u origin <head-branch>`
   - If no, stop PR creation process

2. If status is "Ahead of remote":
   - Inform user that local is ahead of remote
   - Offer to push latest changes: `git push origin <head-branch>`

3. If status is "Up to date":
   - Proceed to PR creation

4. If status is "Behind remote" or "Diverged":
   - Inform user of the situation
   - Suggest appropriate action (pull, rebase, or force push)

### 9. Create PR with gh CLI

Use `create_pr_from_draft.sh` to create PR from the user-confirmed draft file:

```bash
<SKILL_DIR>/scripts/create_pr_from_draft.sh <draft-file-path>
```

The script will:

1. Parse YAML frontmatter to extract `title`, `base`, and `head` fields
2. Extract body content (everything after frontmatter)
3. Validate required fields are present
4. Create PR using `gh pr create` with parsed metadata and body
5. Display PR creation status and URL

## Important Guidelines

- Follow project's PR template and conventions
- Be concise and accurate
- Only include information about actual changes made
- Use appropriate commit message conventions when referencing commits
- Ensure title is descriptive and follows project conventions
- **Do NOT remove unchecked checkboxes** from PR template - keep all checkboxes as they are
- **Do NOT modify or alter existing checklist items** from PR template - preserve all checklist content exactly as written
- **Do NOT remove HTML comments** from PR template - preserve all comments as they provide guidance
