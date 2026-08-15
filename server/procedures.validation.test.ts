import { describe, expect, it } from "vitest";
import { appRouter } from "./routers";
import type { TrpcContext } from "./_core/context";

type AuthenticatedUser = NonNullable<TrpcContext["user"]>;

function context(): TrpcContext {
  const now = new Date();
  const user: AuthenticatedUser = {
    id: 1,
    openId: "procedure-test-user",
    email: "test@example.com",
    name: "Procedure Test",
    loginMethod: "test",
    role: "admin",
    createdAt: now,
    updatedAt: now,
    lastSignedIn: now,
  };
  return {
    user,
    req: { protocol: "https", headers: {} } as TrpcContext["req"],
    res: { clearCookie: () => undefined } as TrpcContext["res"],
  };
}

describe("core dairy procedure validation", () => {
  it("rejects invoices without line items before database access", async () => {
    const caller = appRouter.createCaller(context());
    await expect(caller.invoices.create({ paymentMode: "cash", items: [] })).rejects.toMatchObject({ code: "BAD_REQUEST" });
  });

  it("rejects invalid customer ledger amounts", async () => {
    const caller = appRouter.createCaller(context());
    await expect(caller.customers.addEntry({ customerId: 1, type: "debit", amount: -1 })).rejects.toMatchObject({ code: "BAD_REQUEST" });
  });

  it("rejects non-positive milk collection quantities", async () => {
    const caller = appRouter.createCaller(context());
    await expect(caller.collections.create({ farmerId: 1, session: "morning", quantityLiters: 0, fat: 4, snf: 8.5 })).rejects.toMatchObject({ code: "BAD_REQUEST" });
  });
});
