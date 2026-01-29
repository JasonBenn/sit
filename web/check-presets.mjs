import { ConvexHttpClient } from "convex/browser";
import { api } from "./.convex/_generated/api.js";

const client = new ConvexHttpClient("http://127.0.0.1:3210");

const presets = await client.query(api.timerPresets.list);
console.log("Timer presets:", JSON.stringify(presets, null, 2));
