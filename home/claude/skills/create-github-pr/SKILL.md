---
name: create-github-pr
description: Create GitHub Pull Requests with comprehensive workflow including change analysis, issue search, PR template application, and gh CLI web flow. Use when creating a PR from the current branch, when asked to "create a pull request", "make a PR", "open a PR", or similar requests.
---

# Create GitHub Pull Request

This skill provides a comprehensive workflow for creating GitHub Pull Requests using gh CLI.

## Bundled Scripts

- **analyze_branch_changes.sh** - Analyzes branch information, determines base branch using decoration-based method (or uses explicitly specified base branch), lists changed files with diff stats, and shows commit log
- **verify_remote_branch.sh** - Verifies remote branch status and provides human-readable status report

## Workflow

### 1. Analyze Changes

Run `analyze_branch_changes.sh` to collect branch information:

```bash
# Auto-detect base branch
<SKILL_DIR>/scripts/analyze_branch_changes.sh

# Explicitly specify base branch (skips auto-detection)
<SKILL_DIR>/scripts/analyze_branch_changes.sh --base <base-branch>
```

The `--base` (or `-b`) option skips automatic base branch detection and uses the specified branch directly. Use this when the auto-detected base branch is incorrect or when you know the target branch in advance.

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

### 3. Gather Context

- Read PR template from `.github/pull_request_template.md` (if exists)
- Follow template structure and requirements
- Use language specified in template or appropriate for project
- Only describe what was actually changed - do not mention unrelated items

### 4. Analyze Impact

Based on changed files compared with `origin/<base-branch>`, determine:

- What components/modules are affected
- Whether changes are breaking or non-breaking
- What type of change this represents (feature, fix, refactor, etc.)

### 5. Prepare PR Content

Prepare the PR title and body following the repository's PR template structure.

If a base branch PR was found during the stacked PR check in Step 1:

- Include a note that this PR is built on top of the base PR (e.g., "Built on top of #123" or "Depends on #123")
- Place this information prominently, typically near the top of the description
- Consider adding it as a separate section or as part of the introduction

### 6. Verify Remote Push

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

### 7. Open PR Creation in Browser

Run `gh pr create --web` with the prepared PR metadata and body. Do not create a draft file or a separate confirmation step.

```bash
gh pr create \
  --web \
  --base "<base-branch>" \
  --head "<head-branch>" \
  --title "<prepared PR title>" \
  --body "<prepared PR body>"
```

This opens GitHub's PR creation page prefilled with the prepared content, allowing the user to make any final adjustments in the browser before submitting.

If this fails because the generated URL is too long, retry without `--body` and copy the prepared PR body to the clipboard so the user can paste it into the browser:

```bash
printf '%s' "<prepared PR body>" | pbcopy

gh pr create \
  --web \
  --base "<base-branch>" \
  --head "<head-branch>" \
  --title "<prepared PR title>"
```

Only use this fallback for URL length errors. Do not drop the body silently; tell the user that the body is on the clipboard and needs to be pasted into the PR description field.

## Important Guidelines

- Follow project's PR template and conventions
- Be concise and accurate
- Only include information about actual changes made
- Use appropriate commit message conventions when referencing commits
- Ensure title is descriptive and follows project conventions
- **Do NOT remove unchecked checkboxes** from PR template - keep all checkboxes as they are
- **Do NOT modify or alter existing checklist items** from PR template - preserve all checklist content exactly as written
- **Do NOT remove HTML comments** from PR template - preserve all comments as they provide guidance
