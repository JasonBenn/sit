#!/usr/bin/env bun

const BASE_URL = "https://sit.jasonbenn.com";

const id = process.argv[2];

if (!id) {
  console.error("Usage: bun scripts/delete-prompt-response.ts <id>");
  process.exit(1);
}

const response = await fetch(`${BASE_URL}/api/prompt-responses/${id}`, {
  method: "DELETE",
});

if (!response.ok) {
  console.error(`Error: ${response.status} ${response.statusText}`);
  process.exit(1);
}

console.log("Deleted successfully");
