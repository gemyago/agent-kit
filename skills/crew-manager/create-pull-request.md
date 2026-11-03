# Use this instruction to create pull request

Resolve **module root** (directory containing `AGENTS.md` for this work). Read and analyze `<module-root>/docs/dev-flow.md` before creating a PR. If `dev-flow.md` is missing or marked as deprecated, use the Bitbucket tools available to you to resolve the repository's default branch and use it as the base branch. Prioritize users instruction if provided.

Follow this instruction to create Bitbucket pull request **automatically**. If you don't have access to Bitbucket or Jira tools, mention it to the user and ask them to fix it.

1. Gather branch details. You will need to run command like below
```bash
# fetch latest changes from remote
git fetch

# To figure-out repo name and owner. Will need it later.
git remote get-url origin

# to get current branch
git branch

# The base branch is not resolved by a git command here: use the Bitbucket tools
# available to you to resolve it (see the note at the top). Remember it as <base branch>.

# get list of changes between base and HEAD. Will need it later.
git log origin/<base branch>...HEAD --oneline | cat


# get list of files changed between base and HEAD. Will need it later.
git diff --name-only origin/<base branch>
```

2. **MAKE SURE** to push the branch to remote.

```bash
git push origin <branch name> --set-upstream
```

The `bitbucket_create_pr` will be failing without this step.

3. Review commit history and come up with a sensible PR title using approaches below:

If branch name has a Jira issue key (for example, PROJECT-123):
- Figure out jira cloud details by using `getAccessibleAtlassianResources` MCP tool
- read jira ticket details using jira cloud details and JIRA ticket number. Then use jira ticket title as pr title. Example:
```
PROJECT-123: <original jira ticket title>
```

Otherwise just come-up some sensible PR title based on the changes.

Remember the PR title, you will use it in step 6.

4. Prepare list of changes using below format:
```markdown
  * Short change description 1
  * Short change description 2
  * ...
```
Use the following instruction to format changes:
 - Use git log output you already have as an input
 - Exclude any noise. Keep just high level summaries
 - Keep the list small. It should have at most 3 items (usually 1-2)

Remember the list of changes, you will use it in step 5.

5. Prepare PR body

Please use the exact template below to prepare PR body. Remember the body, you will use it in step 6.

```markdown
# Summary #

> insert list of changes as per step 4
```

6. Use tool available to you to create **draft** bitbucket PR as follows:
 - PR Title - As per step 3
 - PR body - As per step 5
 - Source branch - current branch
 - Target branch - the base branch resolved above
 - Draft - true

## Once PR is created

- tell the user that the PR has been created and show PR link to the user. The link **should be clickable**.

**IMPORTANT**
Your job is to create the PR and nothing else. If unsure, ask user for clarification. If anything goes wrong, ask user for clarification.
