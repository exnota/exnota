import dotenv from "dotenv";
import PocketBase from "pocketbase";

dotenv.config();

const COLLECTION_BLOCK = "block";
const BLOCK_FIELD_TYPE = "type";

const pb = new PocketBase("http://127.0.0.1:8080");
await auth();

(async () => {
  try {
    // List blocks
    const blocks = await pb.collection("block").getList(1, 20, {
      filter: 'created > "2022-08-01 10:00:00"',
    });
    console.log(blocks);

    // Change block type
    const updateResult = await pb
      .collection(COLLECTION_BLOCK)
      .update("ty1agl723e2j3yn", {
        [BLOCK_FIELD_TYPE]: "audio",
      });
    console.log(updateResult);
  } catch (e) {
    console.log(e);
  }
})();

async function auth() {
  // Admin auth
  await pb.admins.authWithPassword(
    process.env.POCKETBASE_ADMIN_USER ?? "",
    process.env.POCKETBASE_ADMIN_PASSWORD ?? ""
  );

  // User auth
  // await pb
  //   .collection("users")
  //   .authWithPassword(
  //     process.env.POCKETBASE_USER_USER ?? "",
  //     process.env.POCKETBASE_USER_PASSWORD ?? ""
  //   );
}
