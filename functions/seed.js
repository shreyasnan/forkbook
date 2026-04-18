#!/usr/bin/env node

// Seed Shreyas's circle with real restaurant entries.
// Run from the functions/ directory:
//   node seed.js
//
// This populates Firestore so invitees see your picks on their Home feed.

const admin = require("firebase-admin");

// Initialize with your project
admin.initializeApp({ projectId: "forkbook-fe65b" });
const db = admin.firestore();

const SHREYAS_UID = "bYOrZrZARaREQHhD8u6QNi7tl2l1";
const CIRCLE_ID = "taZAbyASPNsWsNWTNJjh";

const restaurants = [
  {
    name: "Rasa",
    address: "209 Park Rd, Burlingame, CA",
    cuisine: "Indian",
    rating: 5,
    notes: "Best South Indian in the Bay. The dosa is unreal.",
    dishes: [
      { name: "Dosa", liked: true },
      { name: "Chicken 65", liked: true },
      { name: "Mysore Bonda", liked: true },
    ],
    visitCount: 4,
    daysAgo: 3,
  },
  {
    name: "Mensho Tokyo",
    address: "672 Geary St, San Francisco, CA",
    cuisine: "Japanese",
    rating: 5,
    notes: "The tori paitan ramen changed how I think about ramen.",
    dishes: [
      { name: "Tori Paitan Ramen", liked: true },
      { name: "Chashu Rice", liked: true },
    ],
    visitCount: 3,
    daysAgo: 5,
  },
  {
    name: "Ettan",
    address: "518 Bryant St, Palo Alto, CA",
    cuisine: "Indian",
    rating: 5,
    notes: "Modern Indian done right. Ambiance is 10/10.",
    dishes: [
      { name: "Butter Chicken", liked: true },
      { name: "Lamb Keema", liked: true },
    ],
    visitCount: 2,
    daysAgo: 8,
  },
  {
    name: "Delarosa",
    address: "37 Yerba Buena Ln, San Francisco, CA",
    cuisine: "Italian",
    rating: 5,
    notes: "Perfect date night spot. Burrata is a must-order.",
    dishes: [
      { name: "Burrata", liked: true },
      { name: "Margherita Pizza", liked: true },
      { name: "Tiramisu", liked: true },
    ],
    visitCount: 3,
    daysAgo: 10,
  },
  {
    name: "Sushi Sam's",
    address: "218 E 3rd Ave, San Mateo, CA",
    cuisine: "Japanese",
    rating: 5,
    notes: "Hidden gem in San Mateo. Omakase is worth every penny.",
    dishes: [
      { name: "Omakase", liked: true },
      { name: "Salmon Belly", liked: true },
    ],
    visitCount: 2,
    daysAgo: 14,
  },
  {
    name: "Copas",
    address: "254 Main St, Redwood City, CA",
    cuisine: "Mexican",
    rating: 4,
    notes: "Go-to taco spot. Al pastor is the move.",
    dishes: [
      { name: "Al Pastor Tacos", liked: true },
      { name: "Guacamole", liked: true },
    ],
    visitCount: 5,
    daysAgo: 2,
  },
  {
    name: "Farmhouse Kitchen",
    address: "710 Florida St, San Francisco, CA",
    cuisine: "Thai",
    rating: 5,
    notes: "Best Thai in SF. Crispy rice salad is addictive.",
    dishes: [
      { name: "Crispy Rice Salad", liked: true },
      { name: "Pad See Ew", liked: true },
      { name: "Mango Sticky Rice", liked: true },
    ],
    visitCount: 2,
    daysAgo: 18,
  },
  {
    name: "Oren's Hummus",
    address: "261 University Ave, Palo Alto, CA",
    cuisine: "Mediterranean",
    rating: 4,
    notes: "Reliable lunch spot. Hummus masabacha is the best version I've had.",
    dishes: [
      { name: "Hummus Masabacha", liked: true },
      { name: "Laffa Bread", liked: true },
    ],
    visitCount: 6,
    daysAgo: 1,
  },
  {
    name: "Nobu",
    address: "180 Hamilton Ave, Palo Alto, CA",
    cuisine: "Japanese",
    rating: 5,
    notes: "Black cod miso is legendary. Splurge-worthy.",
    dishes: [
      { name: "Black Cod Miso", liked: true },
      { name: "Yellowtail Jalapeño", liked: true },
    ],
    visitCount: 2,
    daysAgo: 22,
  },
  {
    name: "Tamarine",
    address: "546 University Ave, Palo Alto, CA",
    cuisine: "Vietnamese",
    rating: 4,
    notes: "Upscale Vietnamese. Shaking beef is the standout.",
    dishes: [
      { name: "Shaking Beef", liked: true },
      { name: "Spring Rolls", liked: true },
    ],
    visitCount: 3,
    daysAgo: 12,
  },
  {
    name: "Mazra",
    address: "4008 24th St, San Francisco, CA",
    cuisine: "Mediterranean",
    rating: 5,
    notes: "Incredible hummus, chill vibes. Great for groups.",
    dishes: [
      { name: "Hummus", liked: true },
      { name: "Lamb Shawarma", liked: true },
    ],
    visitCount: 2,
    daysAgo: 25,
  },
  {
    name: "Manresa",
    address: "320 Village Ln, Los Gatos, CA",
    cuisine: "French",
    rating: 5,
    notes: "One of the best meals of my life. Into the Vegetable Garden course is art.",
    dishes: [
      { name: "Into the Vegetable Garden", liked: true },
      { name: "Night Bread", liked: true },
    ],
    visitCount: 1,
    daysAgo: 45,
  },
];

async function seed() {
  const batch = db.batch();
  const now = Date.now();

  for (const r of restaurants) {
    const dateVisited = new Date(now - r.daysAgo * 24 * 60 * 60 * 1000);
    const docId = r.name.toLowerCase().replace(/[^a-z0-9]/g, "-");
    const ref = db
      .collection("circles")
      .doc(CIRCLE_ID)
      .collection("restaurants")
      .doc(docId);

    batch.set(ref, {
      userId: SHREYAS_UID,
      name: r.name,
      address: r.address,
      cuisine: r.cuisine,
      category: "Visited",
      rating: r.rating,
      notes: r.notes,
      dishes: r.dishes,
      dateVisited: admin.firestore.Timestamp.fromDate(dateVisited),
      visitCount: r.visitCount,
      updatedAt: admin.firestore.Timestamp.fromDate(dateVisited),
    });
  }

  await batch.commit();
  console.log(`✅ Seeded ${restaurants.length} restaurants into circle ${CIRCLE_ID}`);
  process.exit(0);
}

seed().catch((err) => {
  console.error("Error seeding:", err);
  process.exit(1);
});
