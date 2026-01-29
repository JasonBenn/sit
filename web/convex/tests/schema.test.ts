import { describe, it, expect } from "vitest";
import schema from "../schema";

describe("convex schema", () => {
  it("should define all required tables", () => {
    const tables = Object.keys(schema.tables);

    expect(tables).toContain("beliefs");
    expect(tables).toContain("timerPresets");
    expect(tables).toContain("promptSettings");
    expect(tables).toContain("meditationSessions");
    expect(tables).toContain("promptResponses");
  });

  it("should define beliefs table with correct fields", () => {
    const beliefs = schema.tables.beliefs;
    expect(beliefs).toBeDefined();
  });

  it("should define timerPresets table with correct fields", () => {
    const timerPresets = schema.tables.timerPresets;
    expect(timerPresets).toBeDefined();
  });

  it("should define promptSettings table", () => {
    const promptSettings = schema.tables.promptSettings;
    expect(promptSettings).toBeDefined();
  });

  it("should define meditationSessions table with index", () => {
    const meditationSessions = schema.tables.meditationSessions;
    expect(meditationSessions).toBeDefined();
  });

  it("should define promptResponses table with index", () => {
    const promptResponses = schema.tables.promptResponses;
    expect(promptResponses).toBeDefined();
  });
});
