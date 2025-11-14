# Branch Protection Setup Guide

This guide explains how to protect the `main` branch to enforce pull request workflow.

## Why Branch Protection?

Branch protection prevents:
- ❌ Direct pushes to main
- ❌ Merging failing code
- ❌ Merging without review
- ❌ Accidental force pushes

## Step-by-Step Setup

### 1. Navigate to Repository Settings

1. Go to your repository: https://github.com/Partridje/aws-eks-production
2. Click **Settings** tab
3. In left sidebar, click **Branches**

### 2. Add Branch Protection Rule

1. Click **Add branch protection rule** (or **Add rule**)
2. In "Branch name pattern", enter: `main`

### 3. Configure Protection Rules

Enable the following settings:

#### A. Require Pull Request

☑ **Require a pull request before merging**
- ☑ **Require approvals**: Set to `1`
  - For solo projects: You can approve your own PRs or set to 0
  - For teams: Set to 1 or more
- ☑ **Dismiss stale pull request approvals when new commits are pushed**
  - Ensures reviews are re-done after changes
- ☑ **Require review from Code Owners** (optional)
  - Only if you create a CODEOWNERS file

#### B. Require Status Checks

☑ **Require status checks to pass before merging**
- ☑ **Require branches to be up to date before merging**

**Search and add these status checks:**
- `Validate` (from Terraform CI/CD workflow)
- `Lint & Best Practices` (TFLint)
- `Security & Cost Analysis` (tfsec/Checkov)

*Note: Status checks will appear in the list after they run at least once. You may need to create a PR first, then add them to protection.*

#### C. Additional Settings

☑ **Require linear history**
- Enforces squash merging or rebase
- Keeps git history clean

☑ **Require deployments to succeed before merging** (optional)
- Only if you have deployment environments

☑ **Lock branch** (optional)
- Makes branch read-only
- Too restrictive for most cases

☑ **Do not allow bypassing the above settings**
- Applies rules to admins too
- Recommended for production

#### D. Rules Applied to Everyone

☑ **Include administrators**
- Ensures even repo admins follow the rules
- Recommended

### 4. Optional: Restrict Who Can Push

**Restrict who can push to matching branches:**
- Add specific users or teams
- Useful for larger teams
- For solo projects, leave unchecked

### 5. Save Changes

Click **Create** or **Save changes** at the bottom

## Verification

### Test That Direct Push is Blocked

```bash
# Try to push directly to main (should fail)
git checkout main
echo "test" >> README.md
git add README.md
git commit -m "test: direct push"
git push origin main

# Expected result:
# ! [remote rejected] main -> main (protected branch hook declined)
```

### Test Pull Request Flow

```bash
# Create feature branch
git checkout -b test/branch-protection

# Make changes
echo "test" >> README.md
git add README.md
git commit -m "test: verify branch protection"

# Push feature branch (should succeed)
git push -u origin test/branch-protection

# Create PR
gh pr create --title "Test: Branch Protection" --body "Testing branch protection"

# Try to merge without approval (should fail if approvals required)
gh pr merge

# Merge after approval
gh pr merge --squash
```

## Current Workflow After Setup

### 1. Create Feature Branch

```bash
git checkout -b feature/my-feature
```

### 2. Make Changes

```bash
# Edit files
git add .
git commit -m "feat: add new feature"
```

### 3. Push to Remote

```bash
git push -u origin feature/my-feature
```

### 4. Create Pull Request

```bash
# Using GitHub CLI
gh pr create

# Or push and use GitHub web UI
```

### 5. Wait for CI Checks

GitHub Actions will automatically run:
- ✅ Terraform Format
- ✅ Terraform Validate
- ✅ TFLint
- ✅ tfsec
- ✅ Checkov
- ✅ Terraform Plan

### 6. Request Review (if required)

If your protection rules require approval:
```bash
# Request review from specific user
gh pr review --request @username

# Or assign reviewers in GitHub UI
```

### 7. Merge After Approval

```bash
# Squash and merge (recommended)
gh pr merge --squash

# Delete branch after merge
git checkout main
git pull
git branch -d feature/my-feature
```

## Solo Developer Workflow

If you're working solo, you can:

### Option 1: Self-Approve (Recommended for Learning)

1. Set required approvals to `1`
2. Create PR
3. Approve your own PR:
   ```bash
   gh pr review --approve
   gh pr merge --squash
   ```

### Option 2: No Approval Required (Easier)

1. Set required approvals to `0`
2. Still require status checks
3. Merge when checks pass:
   ```bash
   gh pr merge --squash
   ```

### Option 3: Admin Override (Not Recommended)

1. Uncheck "Include administrators"
2. You can merge without approval
3. Not recommended - defeats the purpose

## Troubleshooting

### "Cannot merge - status checks failed"

Wait for CI checks to pass. If they fail:
```bash
# View check details
gh pr checks

# Fix issues and push
git add .
git commit -m "fix: address CI issues"
git push
```

### "Cannot merge - branch not up to date"

```bash
# Update your branch with main
git fetch origin
git rebase origin/main
git push --force-with-lease
```

### "Cannot merge - requires approval"

Either:
- Get someone to review
- Self-approve (if allowed): `gh pr review --approve`
- Adjust protection rules to require 0 approvals

### "Status check 'X' not found"

Status checks must run at least once before they appear:
1. Create a test PR
2. Let CI run
3. Go back to Settings → Branches
4. Edit protection rule
5. The status checks should now appear in the list

## Advanced: CODEOWNERS

Create `.github/CODEOWNERS` to automatically request reviews:

```
# Global owners
* @Partridje

# Terraform infrastructure
/terraform/ @Partridje @infrastructure-team

# Documentation
/docs/ @Partridje @doc-writers

# GitHub workflows
/.github/workflows/ @Partridje @devops-team
```

## Security Benefits

With branch protection enabled:

✅ All code is reviewed before merging
✅ All tests must pass
✅ Security scans must complete
✅ No accidental deletions
✅ Clean, linear git history
✅ Audit trail of who approved what

## Disable Branch Protection (If Needed)

To temporarily disable:
1. Settings → Branches
2. Click **Edit** on the rule
3. Uncheck settings or **Delete** the rule

⚠️ **Warning:** Only disable if absolutely necessary. Re-enable immediately after.

## References

- [GitHub Branch Protection Docs](https://docs.github.com/en/repositories/configuring-branches-and-merges-in-your-repository/managing-protected-branches/about-protected-branches)
- [Required Status Checks](https://docs.github.com/en/repositories/configuring-branches-and-merges-in-your-repository/managing-protected-branches/about-protected-branches#require-status-checks-before-merging)
- [CODEOWNERS Documentation](https://docs.github.com/en/repositories/managing-your-repositorys-settings-and-features/customizing-your-repository/about-code-owners)
