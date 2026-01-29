import { mutation, query } from "./_generated/server";
import { v } from "convex/values";

export const logMeditationSession = mutation({
  args: {
    durationMinutes: v.number(),
    startedAt: v.number(),
    completedAt: v.number(),
    hasInnerTimers: v.optional(v.boolean()),
  },
  handler: async (ctx, args) => {
    return await ctx.db.insert("meditationSessions", {
      durationMinutes: args.durationMinutes,
      startedAt: args.startedAt,
      completedAt: args.completedAt,
      hasInnerTimers: args.hasInnerTimers,
    });
  },
});

export const listMeditationSessions = query({
  args: {
    limit: v.optional(v.number()),
  },
  handler: async (ctx, args) => {
    let q = ctx.db.query("meditationSessions").withIndex("by_completed_at").order("desc");

    if (args.limit) {
      return await q.take(args.limit);
    }

    return await q.collect();
  },
});
