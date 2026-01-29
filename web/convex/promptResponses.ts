import { mutation, query } from "./_generated/server";
import { v } from "convex/values";

export const logPromptResponse = mutation({
  args: {
    inTheView: v.boolean(),
    respondedAt: v.number(),
  },
  handler: async (ctx, args) => {
    return await ctx.db.insert("promptResponses", {
      inTheView: args.inTheView,
      respondedAt: args.respondedAt,
    });
  },
});

export const listPromptResponses = query({
  args: {
    limit: v.optional(v.number()),
  },
  handler: async (ctx, args) => {
    let q = ctx.db.query("promptResponses").withIndex("by_responded_at").order("desc");

    if (args.limit) {
      return await q.take(args.limit);
    }

    return await q.collect();
  },
});
