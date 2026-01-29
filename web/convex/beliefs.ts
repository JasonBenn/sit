import { mutation, query } from "./_generated/server";
import { v } from "convex/values";

export const createBelief = mutation({
  args: {
    text: v.string(),
  },
  handler: async (ctx, args) => {
    const now = Date.now();
    return await ctx.db.insert("beliefs", {
      text: args.text,
      createdAt: now,
      updatedAt: now,
    });
  },
});

export const updateBelief = mutation({
  args: {
    id: v.id("beliefs"),
    text: v.string(),
  },
  handler: async (ctx, args) => {
    await ctx.db.patch(args.id, {
      text: args.text,
      updatedAt: Date.now(),
    });
  },
});

export const deleteBelief = mutation({
  args: {
    id: v.id("beliefs"),
  },
  handler: async (ctx, args) => {
    await ctx.db.delete(args.id);
  },
});

export const listBeliefs = query({
  handler: async (ctx) => {
    return await ctx.db.query("beliefs").order("desc").collect();
  },
});
