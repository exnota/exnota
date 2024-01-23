import dotenv from "dotenv";
import PocketBase from "pocketbase";

dotenv.config();

const pb = new PocketBase("http://127.0.0.1:8080");

// Admin auth
// await pb.admins.authWithPassword(
//   process.env.POCKETBASE_ADMIN_USER ?? "",
//   process.env.POCKETBASE_ADMIN_PASSWORD ?? ""
// );

// User auth
// authenticate as auth collection record
await pb
  .collection("users")
  .authWithPassword(
    process.env.POCKETBASE_USER_USER ?? "",
    process.env.POCKETBASE_USER_PASSWORD ?? ""
  );

// Google auth
// This method initializes a one-off realtime subscription and will
// open a popup window with the OAuth2 vendor page to authenticate.
//
// Once the external OAuth2 sign-in/sign-up flow is completed, the popup
// window will be automatically closed and the OAuth2 data sent back
// to the user through the previously established realtime connection.
//
// If the popup is being blocked on Safari, you can try the suggestion from:
// https://github.com/pocketbase/pocketbase/discussions/2429#discussioncomment-5943061.
// const authData = await pb
//   .collection("users")
//   .authWithOAuth2({ provider: "google" });

// // after the above you can also access the auth data from the authStore
// console.log(pb.authStore.isValid);
// console.log(pb.authStore.token);
// console.log(pb.authStore.model?.id);

(async () => {
  try {
    const result = await pb.collection("block").getList(1, 20, {
      filter: 'created > "2022-08-01 10:00:00"',
    });
  } catch (e) {
    console.log(e);
  }
})();
