import { describe, expect, it } from "vitest";
import { adminProcedure, collectorProcedure, roleAllows, router, shopProcedure } from "./_core/trpc";

const authorizationRouter = router({
  adminOnly: adminProcedure.query(({ ctx }) => ctx.user.role),
  shopOnly: shopProcedure.query(({ ctx }) => ctx.user.role),
  collectorOnly: collectorProcedure.query(({ ctx }) => ctx.user.role),
});

const callerFor = (role: string) => authorizationRouter.createCaller({ user: { role } } as any);

describe("role operation permissions", () => {
  it("allows only admin users to manage settings and rates", () => {
    expect(roleAllows("admin", ["admin"])).toBe(true);
    expect(roleAllows("shop", ["admin"])).toBe(false);
    expect(roleAllows("collector", ["admin"])).toBe(false);
  });

  it("allows shop users to bill and manage customer-facing store work", () => {
    expect(roleAllows("shop", ["admin", "shop"])).toBe(true);
    expect(roleAllows("collector", ["admin", "shop"])).toBe(false);
  });

  it("allows collectors to record milk collection but not retail billing", () => {
    expect(roleAllows("collector", ["admin", "collector"])).toBe(true);
    expect(roleAllows("collector", ["admin", "shop"])).toBe(false);
  });

  it("does not treat an unknown role as authorized", () => {
    expect(roleAllows("unknown", ["admin", "shop", "collector", "user"])).toBe(false);
  });

  it("enforces actual protected procedure outcomes", async () => {
    await expect(callerFor("admin").adminOnly()).resolves.toBe("admin");
    await expect(callerFor("shop").shopOnly()).resolves.toBe("shop");
    await expect(callerFor("collector").collectorOnly()).resolves.toBe("collector");
    await expect(callerFor("collector").shopOnly()).rejects.toMatchObject({ code: "FORBIDDEN" });
    await expect(callerFor("shop").collectorOnly()).rejects.toMatchObject({ code: "FORBIDDEN" });
  });
});
