import type { LayoutLoad } from "./$types";
import { client } from "$lib/pocketbase";
import { alerts } from "$lib/components/Alerts.svelte";
import {
  type UserResponse,
  type BlockResponse,
} from "$lib/pocketbase/generated-types";

// turn off SSR - we're JAMstack here
export const ssr = false;
// Prerendering turned off. Turn it on if you know what you're doing.
export const prerender = false;
// trailing slashes make relative paths much easier
export const trailingSlash = "always";

export const load: LayoutLoad = async ({ fetch }) => {
  type Metadata = {
    title: string;
    headline?: string;
  };
  const title = "Untitled";
  const metadata: Metadata = {
    title,
  };

  // users
  let users: UserResponse[] = [];
  try {
    users = await client.collection("user").getFullList<UserResponse>();
    if (users.length === 0) {
    }
  } catch (e: any) {
    alerts.error(e.toString());
  }

  return {
    metadata,
    users,
  };
};
