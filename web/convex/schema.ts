import { defineSchema, defineTable } from "convex/server";
import { v } from "convex/values";

export default defineSchema({
  beliefs: defineTable({
    text: v.string(),
    createdAt: v.number(),
    updatedAt: v.number(),
  }),

  timerPresets: defineTable({
    durationMinutes: v.number(),
    label: v.optional(v.string()),
    order: v.number(),
    createdAt: v.number(),
  }).index("by_order", ["order"]),

  promptSettings: defineTable({
    promptsPerDay: v.number(),
    wakingHourStart: v.number(), // 0-23
    wakingHourEnd: v.number(), // 0-23
    updatedAt: v.number(),
  }),

  meditationSessions: defineTable({
    durationMinutes: v.number(),
    startedAt: v.number(),
    completedAt: v.number(),
    hasInnerTimers: v.optional(v.boolean()),
  }).index("by_completed_at", ["completedAt"]),

  promptResponses: defineTable({
    inTheView: v.boolean(),
    respondedAt: v.number(),
  }).index("by_responded_at", ["respondedAt"]),
});
