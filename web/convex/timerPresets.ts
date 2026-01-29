import { mutation, query } from "./_generated/server";
import { v } from "convex/values";

export const createTimerPreset = mutation({
  args: {
    durationMinutes: v.number(),
    label: v.optional(v.string()),
  },
  handler: async (ctx, args) => {
    // Get the current max order to append to the end
    const presets = await ctx.db.query("timerPresets").collect();
    const maxOrder = presets.reduce((max, p) => Math.max(max, p.order), -1);

    return await ctx.db.insert("timerPresets", {
      durationMinutes: args.durationMinutes,
      label: args.label,
      order: maxOrder + 1,
      createdAt: Date.now(),
    });
  },
});

export const deleteTimerPreset = mutation({
  args: {
    id: v.id("timerPresets"),
  },
  handler: async (ctx, args) => {
    await ctx.db.delete(args.id);
  },
});

export const updateTimerPresetOrder = mutation({
  args: {
    presetOrders: v.array(v.object({
      id: v.id("timerPresets"),
      order: v.number(),
    })),
  },
  handler: async (ctx, args) => {
    // Update each preset's order
    for (const { id, order } of args.presetOrders) {
      await ctx.db.patch(id, { order });
    }
  },
});

export const listTimerPresets = query({
  handler: async (ctx) => {
    return await ctx.db
      .query("timerPresets")
      .withIndex("by_order")
      .order("asc")
      .collect();
  },
});
