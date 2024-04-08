import PocketBase from "pocketbase";
import * as fs from "fs";

const COLLECTION_USER = "user";
const COLLECTION_BLOCK = "block";
const COLLECTION_BLOCK_JOB = "block_job";
const COLLECTION_WORKSPACE = "workspace";
const COLLECTION_DESTINATION = "destination";

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
    verified: true,
  });
  const user2 = await pb.collection(COLLECTION_USER).create({
    id: "user2-15char-id",
    email: "user2@example.com",
    password: "longpassword",
    passwordConfirm: "longpassword",
    verified: true,
  });
  await pb.collection(COLLECTION_USER).create({
    id: "user3-15char-id",
    email: "user3@example.com",
    password: "longpassword",
    passwordConfirm: "longpassword",
    verified: true,
  });

  // --------------------
  // Workspace and destination
  // --------------------
  const workspace1 = await pb.collection(COLLECTION_WORKSPACE).create({
    id: "wspace1--15char",
    name: "workspace 1",
    type: "database",
    user: user1.id,
  });
  const destination1 = await pb.collection(COLLECTION_DESTINATION).create({
    id: "dest1----15char",
    name: "destination 1",
    workspace: workspace1.id,
    user: user1.id,
  });

  const workspace2 = await pb.collection(COLLECTION_WORKSPACE).create({
    id: "wspace2--15char",
    name: "workspace 2",
    type: "database",
    user: user2.id,
  });
  const destination2 = await pb.collection(COLLECTION_DESTINATION).create({
    id: "dest2----15char",
    name: "destination 2",
    workspace: workspace2.id,
    user: user2.id,
  });

  // --------------------
  // Blocks
  // --------------------

  // User 1: Create 8 text blocks and 2 audio blocks
  const block1 = await pb.collection(COLLECTION_BLOCK).create({
    id: "block1--15chars",
    type: "text",
    title: "block 1",
    user: user1.id,
    destination: destination1.id,
    userCreated: new Date().toISOString(),
  });
  const block2 = await pb.collection(COLLECTION_BLOCK).create({
    id: "block2--15chars",
    type: "text",
    title: "block 2",
    user: user1.id,
    destination: destination1.id,
    userCreated: new Date().toISOString(),
  });
  await pb.collection(COLLECTION_BLOCK).create({
    id: "block3--15chars",
    type: "text",
    title: "block 3",
    user: user1.id,
    destination: destination1.id,
    userCreated: new Date().toISOString(),
  });
  await pb.collection(COLLECTION_BLOCK).create({
    id: "block4--15chars",
    type: "text",
    title: "block 4",
    user: user1.id,
    destination: destination1.id,
    userCreated: new Date().toISOString(),
  });
  await pb.collection(COLLECTION_BLOCK).create({
    id: "block5--15chars",
    type: "text",
    title: "block 5",
    user: user1.id,
    destination: destination1.id,
    userCreated: new Date().toISOString(),
  });
  await pb.collection(COLLECTION_BLOCK).create({
    id: "block6--15chars",
    type: "text",
    title: "block 6",
    user: user1.id,
    destination: destination1.id,
    userCreated: new Date().toISOString(),
  });
  await pb.collection(COLLECTION_BLOCK).create({
    id: "block7--15chars",
    type: "text",
    title: "block 7",
    user: user1.id,
    destination: destination1.id,
    userCreated: new Date().toISOString(),
  });
  await pb.collection(COLLECTION_BLOCK).create({
    id: "block8--15chars",
    type: "text",
    title: "block 8",
    user: user1.id,
    destination: destination1.id,
    userCreated: new Date().toISOString(),
  });
  const testFile = fs.readFileSync("./test.wav");
  await pb.collection(COLLECTION_BLOCK).create({
    id: "block9--15chars",
    type: "audio",
    title: "block 9",
    user: user1.id,
    destination: destination1.id,
    userCreated: new Date().toISOString(),
    file: new Blob([testFile], { type: "audio/wav" }),
  });
  await pb.collection(COLLECTION_BLOCK).create({
    id: "block10-15chars",
    type: "audio",
    title: "block 10",
    user: user1.id,
    destination: destination1.id,
    userCreated: new Date().toISOString(),
    file: new Blob([testFile], { type: "audio/wav" }),
    audio: {
      transcription: ["paragraph 1", "paragraph 2"],
    },
  });

  // User 2: Create 2 text blocks
  await pb.collection(COLLECTION_BLOCK).create({
    id: "block11-15chars",
    type: "text",
    title: "block 11",
    user: user2.id,
    destination: destination2.id,
    userCreated: new Date().toISOString(),
  });
  await pb.collection(COLLECTION_BLOCK).create({
    id: "block12-15chars",
    type: "text",
    title: "block 12",
    user: user2.id,
    destination: destination2.id,
    userCreated: new Date().toISOString(),
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
    next_run_at: new Date().toISOString(),
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
