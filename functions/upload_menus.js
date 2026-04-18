#!/usr/bin/env node

// Upload cleaned menu data to Firestore.
// Run from the functions/ directory:
//   node upload_menus.js
//
// Creates a "menus" collection with one document per restaurant.
// Each doc has: name, cuisine, city, dishes (array of {name, desc, price}).
//
// Firestore batch limit is 500 writes per batch, so we chunk accordingly.

const admin = require("firebase-admin");
const fs = require("fs");
const path = require("path");

admin.initializeApp({ projectId: "forkbook-fe65b" });
const db = admin.firestore();

const COLLECTION = "menus";

async function upload() {
  // Load cleaned JSON (sibling to functions/ dir)
  const jsonPath = path.join(__dirname, "..", "ForkBook", "forkbook_menu_data.json");
  if (!fs.existsSync(jsonPath)) {
    console.error(`❌ File not found: ${jsonPath}`);
    console.error("Make sure forkbook_menu_data.json is in ForkBook/");
    process.exit(1);
  }

  const raw = fs.readFileSync(jsonPath, "utf-8");
  const restaurants = JSON.parse(raw);
  console.log(`📖 Loaded ${restaurants.length} restaurants from JSON`);

  // Delete existing menus collection first
  console.log("🗑  Clearing existing menus collection...");
  const existing = await db.collection(COLLECTION).listDocuments();
  if (existing.length > 0) {
    const delBatches = chunkArray(existing, 500);
    for (const chunk of delBatches) {
      const batch = db.batch();
      chunk.forEach((doc) => batch.delete(doc));
      await batch.commit();
    }
    console.log(`   Deleted ${existing.length} existing docs`);
  }

  // Upload in batches of 500
  let uploaded = 0;
  const chunks = chunkArray(restaurants, 400); // leave room for safety

  for (const chunk of chunks) {
    const batch = db.batch();

    for (const r of chunk) {
      // Doc ID: slugified restaurant name
      const docId = r.name
        .toLowerCase()
        .replace(/[^a-z0-9]+/g, "-")
        .replace(/^-|-$/g, "")
        .slice(0, 60);

      const ref = db.collection(COLLECTION).doc(docId);

      // Flatten dish format from compact {n, d, p} to readable {name, desc, price}
      const dishes = r.dishes.map((d) => ({
        name: d.n,
        desc: d.d || null,
        price: d.p,
      }));

      batch.set(ref, {
        name: r.name,
        nameLower: r.name.toLowerCase(), // for case-insensitive search
        cuisine: r.cuisine || "",
        city: r.city || "",
        dishes: dishes,
        dishCount: dishes.length,
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      });
    }

    await batch.commit();
    uploaded += chunk.length;
    console.log(`   ✅ Uploaded ${uploaded}/${restaurants.length}`);
  }

  console.log(`\n🎉 Done! ${uploaded} restaurants in "${COLLECTION}" collection`);
  process.exit(0);
}

function chunkArray(arr, size) {
  const chunks = [];
  for (let i = 0; i < arr.length; i += size) {
    chunks.push(arr.slice(i, i + size));
  }
  return chunks;
}

upload().catch((err) => {
  console.error("❌ Upload failed:", err);
  process.exit(1);
});
