import PocketBase from "pocketbase";

const COLLECTION_USER = "users";
const COLLECTION_BLOCK = "block";
const COLLECTION_BLOCK_JOB = "block_job";

const pb = new PocketBase("http://127.0.0.1:8080");

try {
  await authAsAdmin();

  // --------------------
  // Users
  // --------------------

  const user1 = await pb.collection(COLLECTION_USER).create({
    id: "user1-15char-id",
    email: "user1@example.com",
    password: "longpassword",
    passwordConfirm: "longpassword",
  });
  const user2 = await pb.collection(COLLECTION_USER).create({
    id: "user2-15char-id",
    email: "user2@example.com",
    password: "longpassword",
    passwordConfirm: "longpassword",
  });
  await pb.collection(COLLECTION_USER).create({
    id: "user3-15char-id",
    email: "user3@example.com",
    password: "longpassword",
    passwordConfirm: "longpassword",
  });

  // --------------------
  // Blocks
  // --------------------

  // User 1: Create 5 text blocks and 5 audio blocks
  const block1 = await pb.collection(COLLECTION_BLOCK).create({
    id: "block1--15chars",
    type: "text",
    title: "block 1",
    user: user1.id,
  });
  const block2 = await pb.collection(COLLECTION_BLOCK).create({
    id: "block2--15chars",
    type: "text",
    title: "block 2",
    user: user1.id,
  });
  await pb.collection(COLLECTION_BLOCK).create({
    id: "block3--15chars",
    type: "text",
    title: "block 3",
    user: user1.id,
  });
  await pb.collection(COLLECTION_BLOCK).create({
    id: "block4--15chars",
    type: "text",
    title: "block 4",
    user: user1.id,
  });
  await pb.collection(COLLECTION_BLOCK).create({
    id: "block5--15chars",
    type: "text",
    title: "block 5",
    user: user1.id,
  });
  await pb.collection(COLLECTION_BLOCK).create({
    id: "block6--15chars",
    type: "audio",
    title: "block 6",
    user: user1.id,
  });
  await pb.collection(COLLECTION_BLOCK).create({
    id: "block7--15chars",
    type: "audio",
    title: "block 7",
    user: user1.id,
  });
  await pb.collection(COLLECTION_BLOCK).create({
    id: "block8--15chars",
    type: "audio",
    title: "block 8",
    user: user1.id,
  });
  await pb.collection(COLLECTION_BLOCK).create({
    id: "block9--15chars",
    type: "audio",
    title: "block 9",
    user: user1.id,
  });
  await pb.collection(COLLECTION_BLOCK).create({
    id: "block10-15chars",
    type: "audio",
    title: "block 10",
    user: user1.id,
  });

  // User 2: Create 2 text blocks
  await pb.collection(COLLECTION_BLOCK).create({
    id: "block11-15chars",
    type: "text",
    title: "block 11",
    user: user2.id,
  });
  await pb.collection(COLLECTION_BLOCK).create({
    id: "block12-15chars",
    type: "text",
    title: "block 12",
    user: user2.id,
  });

  // --------------------
  // Block Jobs
  // --------------------
  await pb.collection(COLLECTION_BLOCK_JOB).create({
    id: "block01-job---1",
    type: "transcription",
    status: "waiting",
    summary: [],
    block: block1.id,
    user: user1.id,
  });
  console.log("Test seed data created successfully");
} catch (e) {
  console.error("Test seed data creation failed");
  console.error(e);
}

async function authAsAdmin() {
  await pb.admins.create({
    id: "admin-15char-id",
    email: "admin@example.com",
    password: "longpassword",
    passwordConfirm: "longpassword",
  });
  await pb.admins.authWithPassword("admin@example.com", "longpassword");
}
