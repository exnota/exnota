# Workflow

## Bugs/issues: Creating inline in VS Code

1. Install Github extension
2. Add comment `// TODO: <description>`
3. Put cursor on command and select the 💡 to the left
4. Select 'Created GitHub issue'

## Code task

### Start

1. Open issue: <https://github.com/orgs/exnota/projects/1>

- You may need to select: `Convert to issue`

2. `Right sidebar > Development > Create a branch > Create branch`
3. Copy the commands and paste locally to check out

### Complete

1. In VSCode: `Branch view > Right click > Create Pull Request`
2. Select first option in popup
3. Add to body of pull request: `Resolves #<issue id>`

- Issue ID is usually pre-populated in the title, from the branch name.
- If closes more than one: `Resolves #<issue1>, Resolves #<issue2>`
