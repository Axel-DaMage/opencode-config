# Script Domains Reference

Detailed parameters, options, and examples for all github-ops domain scripts.

Each script follows a consistent pattern:

```bash
bash scripts/<domain>.sh <action> [options]
```

## repos.sh - Repository Operations

```bash
# View repository info
bash scripts/repos.sh view --owner OWNER --repo REPO

# Get file contents
bash scripts/repos.sh contents --owner OWNER --repo REPO --path PATH

# List directory
bash scripts/repos.sh contents --owner OWNER --repo REPO --path PATH --type dir

# Clone repository
bash scripts/repos.sh clone --owner OWNER --repo REPO [--dir TARGET]

# Fork repository
bash scripts/repos.sh fork --owner OWNER --repo REPO

# List user's repos
bash scripts/repos.sh list [--type owner|member|all] [--limit N]

# Create repository (requires confirmation)
bash scripts/repos.sh create --name NAME [--description DESC] [--private]

# List commits
bash scripts/repos.sh commits --owner OWNER --repo REPO [--limit N]

# List branches
bash scripts/repos.sh branches --owner OWNER --repo REPO

# List tags
bash scripts/repos.sh tags --owner OWNER --repo REPO

# Get default branch
bash scripts/repos.sh default-branch --owner OWNER --repo REPO
```

## issues.sh - Issue Operations

```bash
# List issues
bash scripts/issues.sh list --owner OWNER --repo REPO [--state open|closed|all] [--label LABEL] [--limit N]

# View issue
bash scripts/issues.sh view --owner OWNER --repo REPO --number NUMBER [--comments]

# Create issue (requires confirmation)
bash scripts/issues.sh create --owner OWNER --repo REPO --title TITLE [--body BODY] [--labels L1,L2]

# Close issue (requires confirmation)
bash scripts/issues.sh close --owner OWNER --repo REPO --number NUMBER

# Reopen issue
bash scripts/issues.sh reopen --owner OWNER --repo REPO --number NUMBER

# Add comment
bash scripts/issues.sh comment --owner OWNER --repo REPO --number NUMBER --body BODY

# Update issue
bash scripts/issues.sh update --owner OWNER --repo REPO --number NUMBER [--title T] [--body B]

# List issue comments
bash scripts/issues.sh comments --owner OWNER --repo REPO --number NUMBER

# Add labels
bash scripts/issues.sh add-labels --owner OWNER --repo REPO --number NUMBER --labels L1,L2

# Remove labels
bash scripts/issues.sh remove-labels --owner OWNER --repo REPO --number NUMBER --labels L1,L2
```

## prs.sh - Pull Request Operations

```bash
# List PRs
bash scripts/prs.sh list --owner OWNER --repo REPO [--state open|closed|merged|all] [--limit N]

# View PR
bash scripts/prs.sh view --owner OWNER --repo REPO --number NUMBER [--comments]

# View PR diff
bash scripts/prs.sh diff --owner OWNER --repo REPO --number NUMBER

# View PR files
bash scripts/prs.sh files --owner OWNER --repo REPO --number NUMBER

# Check PR status
bash scripts/prs.sh checks --owner OWNER --repo REPO --number NUMBER

# Create PR (requires confirmation)
bash scripts/prs.sh create --owner OWNER --repo REPO --title TITLE --head BRANCH [--base main] [--body BODY]

# Merge PR (requires confirmation)
bash scripts/prs.sh merge --owner OWNER --repo REPO --number NUMBER [--method merge|squash|rebase]

# Close PR
bash scripts/prs.sh close --owner OWNER --repo REPO --number NUMBER

# Add review
bash scripts/prs.sh review --owner OWNER --repo REPO --number NUMBER --event approve|comment|request_changes [--body BODY]

# List reviews
bash scripts/prs.sh reviews --owner OWNER --repo REPO --number NUMBER

# Get merge status
bash scripts/prs.sh merge-status --owner OWNER --repo REPO --number NUMBER
```

## actions.sh - GitHub Actions

```bash
# List workflow runs
bash scripts/actions.sh runs --owner OWNER --repo REPO [--workflow FILE] [--status STATUS] [--limit N]

# View run details
bash scripts/actions.sh run --owner OWNER --repo REPO --run-id ID

# List jobs in a run
bash scripts/actions.sh jobs --owner OWNER --repo REPO --run-id ID

# Get job logs
bash scripts/actions.sh logs --owner OWNER --repo REPO --run-id ID [--job-id JOB_ID] [--failed-only]

# List artifacts
bash scripts/actions.sh artifacts --owner OWNER --repo REPO --run-id ID

# Download artifact
bash scripts/actions.sh download-artifact --owner OWNER --repo REPO --artifact-id ID

# List workflows
bash scripts/actions.sh workflows --owner OWNER --repo REPO

# Rerun workflow (requires confirmation)
bash scripts/actions.sh rerun --owner OWNER --repo REPO --run-id ID

# Rerun failed jobs (requires confirmation)
bash scripts/actions.sh rerun-failed --owner OWNER --repo REPO --run-id ID

# Cancel run (requires confirmation)
bash scripts/actions.sh cancel --owner OWNER --repo REPO --run-id ID

# Trigger workflow (requires confirmation)
bash scripts/actions.sh dispatch --owner OWNER --repo REPO --workflow FILE [--ref BRANCH] [--inputs JSON]
```

## releases.sh - Release Operations

```bash
# List releases
bash scripts/releases.sh list --owner OWNER --repo REPO [--limit N]

# View release
bash scripts/releases.sh view --owner OWNER --repo REPO [--tag TAG]

# View latest release
bash scripts/releases.sh latest --owner OWNER --repo REPO

# Download release assets
bash scripts/releases.sh download --owner OWNER --repo REPO --tag TAG [--pattern GLOB]

# Create release (requires confirmation)
bash scripts/releases.sh create --owner OWNER --repo REPO --tag TAG [--title TITLE] [--notes NOTES] [--draft] [--prerelease]

# Delete release (requires confirmation)
bash scripts/releases.sh delete --owner OWNER --repo REPO --tag TAG

# Upload asset (requires confirmation)
bash scripts/releases.sh upload --owner OWNER --repo REPO --tag TAG --file FILE
```

## code-security.sh - Code Security

```bash
# List code scanning alerts
bash scripts/code-security.sh code-alerts --owner OWNER --repo REPO [--state open|closed|all] [--severity LEVEL]

# View code scanning alert
bash scripts/code-security.sh code-alert --owner OWNER --repo REPO --number NUMBER

# List Dependabot alerts
bash scripts/code-security.sh dependabot-alerts --owner OWNER --repo REPO [--state open|closed|all] [--severity LEVEL]

# View Dependabot alert
bash scripts/code-security.sh dependabot-alert --owner OWNER --repo REPO --number NUMBER

# List secret scanning alerts
bash scripts/code-security.sh secret-alerts --owner OWNER --repo REPO [--state open|resolved]

# View secret scanning alert
bash scripts/code-security.sh secret-alert --owner OWNER --repo REPO --number NUMBER
```

## discussions.sh - Discussions

```bash
# List discussions
bash scripts/discussions.sh list --owner OWNER --repo REPO [--category CATEGORY] [--limit N]

# View discussion
bash scripts/discussions.sh view --owner OWNER --repo REPO --number NUMBER

# List discussion comments
bash scripts/discussions.sh comments --owner OWNER --repo REPO --number NUMBER

# List discussion categories
bash scripts/discussions.sh categories --owner OWNER --repo REPO

# Create discussion (requires confirmation)
bash scripts/discussions.sh create --owner OWNER --repo REPO --title TITLE --body BODY --category SLUG
```

## notifications.sh - Notifications

```bash
# List notifications
bash scripts/notifications.sh list [--all] [--participating] [--limit N]

# Mark as read
bash scripts/notifications.sh mark-read [--thread-id ID]

# Get thread
bash scripts/notifications.sh thread --id ID

# Subscribe/unsubscribe
bash scripts/notifications.sh subscribe --owner OWNER --repo REPO
bash scripts/notifications.sh unsubscribe --owner OWNER --repo REPO
```

## search.sh - Search Operations

```bash
# Search repositories
bash scripts/search.sh repos --query QUERY [--limit N] [--sort stars|forks|updated]

# Search code
bash scripts/search.sh code --query QUERY [--limit N]

# Search issues
bash scripts/search.sh issues --query QUERY [--limit N]

# Search PRs
bash scripts/search.sh prs --query QUERY [--limit N]

# Search users
bash scripts/search.sh users --query QUERY [--limit N]

# Search commits
bash scripts/search.sh commits --query QUERY [--limit N]
```

## users.sh - User Operations

```bash
# Get current user
bash scripts/users.sh me

# Get user profile
bash scripts/users.sh profile --username USERNAME

# List followers
bash scripts/users.sh followers [--username USERNAME] [--limit N]

# List following
bash scripts/users.sh following [--username USERNAME] [--limit N]

# List user's repos
bash scripts/users.sh repos --username USERNAME [--limit N]

# List user's gists
bash scripts/users.sh gists --username USERNAME [--limit N]

# Get user emails (authenticated user only)
bash scripts/users.sh emails
```

## orgs.sh - Organization Operations

```bash
# View organization
bash scripts/orgs.sh view --org ORG

# List members
bash scripts/orgs.sh members --org ORG [--role admin|member|all] [--limit N]

# List teams
bash scripts/orgs.sh teams --org ORG [--limit N]

# View team
bash scripts/orgs.sh team --org ORG --team TEAM_SLUG

# List team members
bash scripts/orgs.sh team-members --org ORG --team TEAM_SLUG [--limit N]

# List org repos
bash scripts/orgs.sh repos --org ORG [--type all|public|private] [--limit N]
```

## gists.sh - Gist Operations

```bash
# List gists
bash scripts/gists.sh list [--public] [--secret] [--limit N]

# View gist
bash scripts/gists.sh view --id ID

# Create gist (requires confirmation)
bash scripts/gists.sh create --filename FILE --content CONTENT [--description DESC] [--public]

# Edit gist (requires confirmation)
bash scripts/gists.sh edit --id ID --filename FILE --content CONTENT

# Delete gist (requires confirmation)
bash scripts/gists.sh delete --id ID

# Fork gist
bash scripts/gists.sh fork --id ID
```

## projects.sh - Projects v2

```bash
# List projects
bash scripts/projects.sh list --owner OWNER [--limit N]

# View project
bash scripts/projects.sh view --owner OWNER --number NUMBER

# List project items
bash scripts/projects.sh items --owner OWNER --number NUMBER [--limit N]

# List project fields
bash scripts/projects.sh fields --owner OWNER --number NUMBER
```
