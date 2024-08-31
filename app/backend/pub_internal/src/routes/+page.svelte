<script lang="ts">
  import { base } from "$app/paths";
  import { alerts } from "$lib/components/Alerts.svelte";
  import type {
    BlockRecord,
    BlockResponse,
    DestinationRecord,
    DestinationResponse,
  } from "$lib/pocketbase/generated-types.js";
  import { client } from "$lib/pocketbase/index.js";

  const { data } = $props();
  $effect(() => {
    // you could set the metadata either here or in +page.ts
    data.metadata.title = "Home";
    data.metadata.headline = `Exnota Internal`;
  });

  let userId = $state("");
  let shouldArchiveUserBlocks = $state(false);
  let shouldArchiveUserIntegration = $state<
    "none" | "full" | "workspace-and-destination" | "destination-only"
  >("none");
  let archiveUserDataInProgress = $state(false);

  async function archiveUserData(event: SubmitEvent) {
    event.preventDefault();
    archiveUserDataInProgress = true;

    let success = true;
    if (shouldArchiveUserBlocks) {
      success = await archiveUserBlocks();
      if (!success) {
        archiveUserDataInProgress = false;
        return;
      }
    }

    switch (shouldArchiveUserIntegration) {
      case "full":
        let success = await archiveUserDestinations();
        if (!success) {
          archiveUserDataInProgress = false;
          return;
        }

        success = await archiveUserWorkspaces();
        if (!success) {
          archiveUserDataInProgress = false;
          return;
        }

        success = await archiveUserIntegrations();
        if (!success) {
          archiveUserDataInProgress = false;
          return;
        }
        break;
      case "workspace-and-destination":
        success = await archiveUserDestinations();
        if (!success) {
          archiveUserDataInProgress = false;
          return;
        }

        success = await archiveUserWorkspaces();
        if (!success) {
          archiveUserDataInProgress = false;
          return;
        }
        break;
      case "destination-only":
        success = await archiveUserDestinations();
        if (!success) {
          archiveUserDataInProgress = false;
          return;
        }
        break;
    }

    shouldArchiveUserBlocks = false;
  }

  async function archiveUserBlocks(): Promise<boolean> {
    try {
      const blocks = await client
        .collection("block")
        .getFullList<BlockResponse>({
          filter: `user = "${userId}"`,
        });
      alerts.success(`Archiving ${blocks.length} blocks...`);
      blocks.forEach(async (block) => {
        await client
          .collection("block")
          .update(block.id, { archived: new Date() });
      });
      alerts.success("All blocks archived.");
      return true;
    } catch (error) {
      alerts.error(String(error));
      return false;
    }
  }

  async function archiveUserDestinations(): Promise<boolean> {
    try {
      const destinations = await client
        .collection("destination")
        .getFullList<DestinationResponse>({
          filter: `user = "${userId}"`,
        });

      alerts.success(`Archiving ${destinations.length} destinations...`);
      destinations.forEach(async (destination) => {
        await client
          .collection("destination")
          .update(destination.id, { archived: new Date() });
      });
      alerts.success("All destinations archived.");
      return true;
    } catch (error) {
      alerts.error(String(error));
      return false;
    }
  }

  async function archiveUserWorkspaces(): Promise<boolean> {
    try {
      const workspaces = await client.collection("workspace").getFullList({
        filter: `user = "${userId}"`,
      });

      alerts.success(`Archiving ${workspaces.length} workspaces...`);
      workspaces.forEach(async (workspace) => {
        await client
          .collection("workspace")
          .update(workspace.id, { archived: new Date() });
      });
      alerts.success("All workspaces archived.");

      return true;
    } catch (error) {
      alerts.error(String(error));
      return false;
    }
  }

  async function archiveUserIntegrations(): Promise<boolean> {
    try {
      const integrations = await client.collection("integration").getFullList({
        filter: `user = "${userId}"`,
      });

      alerts.success(`Archiving ${integrations.length} integrations...`);
      integrations.forEach(async (integration) => {
        await client
          .collection("integration")
          .update(integration.id, { archived: new Date() });
      });
      alerts.success("All integrations archived.");
      return true;
    } catch (error) {
      alerts.error(String(error));
      return false;
    }
  }
</script>

<h3>Clean up user</h3>
<form onsubmit={archiveUserData}>
  <select bind:value={userId} disabled={archiveUserDataInProgress}>
    <option value="">Select a user</option>
    {#each data.users as user}
      <option value={user.id}>
        {user.email} ({user.id})
      </option>
    {/each}
  </select>

  <br />

  <div class="columns">
    <label for="archiveUserIntegration">Archive integration?</label>
    <select
      id="archiveUserIntegration"
      bind:value={shouldArchiveUserIntegration}
      disabled={archiveUserDataInProgress}
    >
      <option value="none">None</option>
      <option value="full">Full</option>
      <option value="workspace-and-destination"
        >Workspace and Destination</option
      >
      <option value="destination-only">Destination Only</option>
    </select>
  </div>

  <br />
  <br />

  <label>
    <input
      type="checkbox"
      bind:checked={shouldArchiveUserBlocks}
      disabled={archiveUserDataInProgress}
    />
    Archive user blocks
  </label>

  <br /><br />

  <button type="submit" disabled={userId === ""}>Archive!</button>
</form>
<br />
<hr />

<p>
  Visit
  <a
    href="https://github.com/spinspire/pocketbase-sveltekit-starter"
    target="_blank"
    rel="noopener noreferrer"
  >
    https://github.com/spinspire/pocketbase-sveltekit-starter
  </a>
  on <i class="bx bxl-github bx-sm"></i>GitHub to read the documentation.
</p>

<h2>Features</h2>
<ul>
  <li>Svelte 5: runes, $props, snippets, etc.</li>
  <li>
    SvelteKit: routing, PageData loading, CSR with <code>adapter-static</code>
  </li>
  <li>PocketBase: CRUD, typegen, realtime data updates</li>
  <li>PocketBase: JSVM hook, routes, etc.</li>
</ul>

<p>Now <a href="{base}/posts">browse/edit/create some posts</a>.</p>

<style>
  .columns {
    display: inline-flex;
    justify-content: space-between;
    align-items: center;

    label {
      margin-right: 1rem;
    }
  }
</style>
