# QA

## Settings > Connect to Notion

### Scenario: Initial Setup

Preparing:

1. If the account isn't new, then:
   - Archive existing destinations, workspaces, integrations. In that order.
   - In the all, pull to refresh on the Voice Notes list screen. This will update its copies of the workspaces and destinations so it knows they are archived.

2. Create 1 or more recordings before beginning. Confirm:
   - They are not exported to Notion.
   - A 'Connect to Notion' card is shown on the notes list screen.

a. Success steps:

- User authorizes Notion access
- User selects a listed destination
- OR User searches for and selects an unlisted destination
- When finished
  - Existing recordings are exported to the selected destination.
  - New recordings are exported to the selected destination.

b. Error cases to test:

- User goes offline (before starting, before pressing Go Notion, or before searching)
- User closes Notion prematurely
- User leaves Notion open more than 5 minutes
- User doesn't grant access to any pages
- User doesn't grant access to desired page/database: They can go back and grant access.

### Scenario 2: Partial Setup: Already has an integration

Preparing:

- If the account isn't new, archive existing destinations and workspaces. In that order.

Make sure the success steps above work.

### Scenario 3: Partial Setup: Already has an integration and workspace

Preparing:

- If the account isn't new, archive existing destinations.

Make sure the success steps above work.

### Scenario 4: Setup already completed

User has all components (integration, workspace, and destination).

Should show the destination name and allow user to close the screen.

### Scenario: Update destination

1. Go to Settings
2. Under account it should say `Change notes destination` and `Saving to '[current destination]' in Notion`
3. Press that button.
4. All major flows should work:
   - Choose a suggested destination.
   - Search for a destination.
   - "I can't find it"
