#!/usr/bin/env bun

const BASE_URL = "https://sit.jasonbenn.com";

const limit = process.argv[2] ? parseInt(process.argv[2]) : 10;

const response = await fetch(`${BASE_URL}/api/prompt-responses?limit=${limit}`);
const data = await response.json();

console.log(JSON.stringify(data, null, 2));
