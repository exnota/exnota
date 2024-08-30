<script lang="ts">
  import { base } from "$app/paths";
  import { alerts } from "$lib/components/Alerts.svelte";
  import type {
    BlockRecord,
    BlockResponse,
  } from "$lib/pocketbase/generated-types.js";
  import { client } from "$lib/pocketbase/index.js";

  const { data } = $props();
  $effect(() => {
    // you could set the metadata either here or in +page.ts
    data.metadata.title = "Home";
    data.metadata.headline = `Welcome to ${data.config.site?.name}`;
  });

  let userId = $state("");
  async function archiveAllBlocks(event: SubmitEvent) {
    event.preventDefault();
    alerts.success(`User ID: ${userId}`);
    try {
      const blocks = await client
        .collection("block")
        .getFullList<BlockResponse>({
          filter: `user = "${userId}"`,
        });
      alerts.success(`Found ${blocks.length} blocks to archive. Starting...`);
      blocks.forEach(async (block) => {
        await client
          .collection("block")
          .update(block.id, { archived: new Date() });
      });
      alerts.success("All blocks archived.");
    } catch (error) {
      alerts.error(String(error));
    }
    // Call your function here with the userId value
    // For example:
    // myFunction(userId);
  }
</script>

<h3>Archive all blocks for user</h3>
<form onsubmit={archiveAllBlocks}>
  <label for="userId">User ID:</label>
  <input type="text" id="userId" bind:value={userId} />
  <button type="submit">Submit</button>
</form>

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
