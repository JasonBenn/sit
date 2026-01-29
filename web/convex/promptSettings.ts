import { mutation, query } from "./_generated/server";
import { v } from "convex/values";

export const updatePromptSettings = mutation({
  args: {
    promptsPerDay: v.number(),
    wakingHourStart: v.number(),
    wakingHourEnd: v.number(),
  },
  handler: async (ctx, args) => {
    // Single-user MVP: always update or create the first settings record
    const existing = await ctx.db.query("promptSettings").first();

    if (existing) {
      await ctx.db.patch(existing._id, {
        promptsPerDay: args.promptsPerDay,
        wakingHourStart: args.wakingHourStart,
        wakingHourEnd: args.wakingHourEnd,
        updatedAt: Date.now(),
      });
      return existing._id;
    } else {
      return await ctx.db.insert("promptSettings", {
        promptsPerDay: args.promptsPerDay,
        wakingHourStart: args.wakingHourStart,
        wakingHourEnd: args.wakingHourEnd,
        updatedAt: Date.now(),
      });
    }
  },
});

export const getPromptSettings = query({
  handler: async (ctx) => {
    return await ctx.db.query("promptSettings").first();
  },
});
