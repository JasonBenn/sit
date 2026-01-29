import { convexTest } from "convex-test";
import { describe, test, expect } from "vitest";
import schema from "../schema";
import { api } from "../_generated/api";

describe("Belief Management Integration Tests", () => {
  test("should create a belief", async () => {
    const t = convexTest(schema);

    const beliefId = await t.mutation(api.beliefs.createBelief, {
      text: "I am not good enough",
    });

    expect(beliefId).toBeDefined();

    const beliefs = await t.query(api.beliefs.listBeliefs);
    expect(beliefs).toHaveLength(1);
    expect(beliefs[0].text).toBe("I am not good enough");
  });

  test("should update a belief", async () => {
    const t = convexTest(schema);

    const beliefId = await t.mutation(api.beliefs.createBelief, {
      text: "Original belief",
    });

    await t.mutation(api.beliefs.updateBelief, {
      id: beliefId,
      text: "Updated belief",
    });

    const beliefs = await t.query(api.beliefs.listBeliefs);
    expect(beliefs[0].text).toBe("Updated belief");
  });

  test("should delete a belief", async () => {
    const t = convexTest(schema);

    const beliefId = await t.mutation(api.beliefs.createBelief, {
      text: "Belief to delete",
    });

    let beliefs = await t.query(api.beliefs.listBeliefs);
    expect(beliefs).toHaveLength(1);

    await t.mutation(api.beliefs.deleteBelief, {
      id: beliefId,
    });

    beliefs = await t.query(api.beliefs.listBeliefs);
    expect(beliefs).toHaveLength(0);
  });

  test("should persist beliefs across queries", async () => {
    const t = convexTest(schema);

    await t.mutation(api.beliefs.createBelief, {
      text: "First belief",
    });
    await t.mutation(api.beliefs.createBelief, {
      text: "Second belief",
    });
    await t.mutation(api.beliefs.createBelief, {
      text: "Third belief",
    });

    const beliefs = await t.query(api.beliefs.listBeliefs);
    expect(beliefs).toHaveLength(3);

    // Query again to verify persistence
    const beliefsAgain = await t.query(api.beliefs.listBeliefs);
    expect(beliefsAgain).toHaveLength(3);
    expect(beliefsAgain.map(b => b.text)).toContain("First belief");
    expect(beliefsAgain.map(b => b.text)).toContain("Second belief");
    expect(beliefsAgain.map(b => b.text)).toContain("Third belief");
  });

  test("should handle empty belief list", async () => {
    const t = convexTest(schema);

    const beliefs = await t.query(api.beliefs.listBeliefs);
    expect(beliefs).toHaveLength(0);
  });

  test("should update timestamps correctly", async () => {
    const t = convexTest(schema);

    const beforeCreate = Date.now();
    const beliefId = await t.mutation(api.beliefs.createBelief, {
      text: "Test belief",
    });
    const afterCreate = Date.now();

    let beliefs = await t.query(api.beliefs.listBeliefs);
    expect(beliefs[0].createdAt).toBeGreaterThanOrEqual(beforeCreate);
    expect(beliefs[0].createdAt).toBeLessThanOrEqual(afterCreate);
    expect(beliefs[0].updatedAt).toBe(beliefs[0].createdAt);

    // Small delay to ensure different timestamp
    await new Promise(resolve => setTimeout(resolve, 10));

    const beforeUpdate = Date.now();
    await t.mutation(api.beliefs.updateBelief, {
      id: beliefId,
      text: "Updated text",
    });
    const afterUpdate = Date.now();

    beliefs = await t.query(api.beliefs.listBeliefs);
    expect(beliefs[0].updatedAt).toBeGreaterThanOrEqual(beforeUpdate);
    expect(beliefs[0].updatedAt).toBeLessThanOrEqual(afterUpdate);
    expect(beliefs[0].updatedAt).toBeGreaterThan(beliefs[0].createdAt);
  });
});
