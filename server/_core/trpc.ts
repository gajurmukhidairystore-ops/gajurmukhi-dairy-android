import { NOT_ADMIN_ERR_MSG, UNAUTHED_ERR_MSG } from '@shared/const';
import { initTRPC, TRPCError } from "@trpc/server";
import superjson from "superjson";
import type { TrpcContext } from "./context";

type AppRole = "user" | "admin" | "shop" | "collector";

const t = initTRPC.context<TrpcContext>().create({
  transformer: superjson,
});

export const router = t.router;
export const publicProcedure = t.procedure;

const requireUser = t.middleware(async opts => {
  const { ctx, next } = opts;
  if (!ctx.user) throw new TRPCError({ code: "UNAUTHORIZED", message: UNAUTHED_ERR_MSG });
  return next({ ctx: { ...ctx, user: ctx.user } });
});

export const protectedProcedure = t.procedure.use(requireUser);

export function roleAllows(role: string, roles: AppRole[]) {
  return roles.includes(role as AppRole);
}

export function roleProcedure(...roles: AppRole[]) {
  return t.procedure.use(t.middleware(async opts => {
    const { ctx, next } = opts;
    if (!ctx.user) throw new TRPCError({ code: "UNAUTHORIZED", message: UNAUTHED_ERR_MSG });
    if (!roleAllows(ctx.user.role, roles)) {
      throw new TRPCError({ code: "FORBIDDEN", message: NOT_ADMIN_ERR_MSG });
    }
    return next({ ctx: { ...ctx, user: ctx.user } });
  }));
}

export const adminProcedure = roleProcedure("admin");
export const shopProcedure = roleProcedure("admin", "shop");
export const collectorProcedure = roleProcedure("admin", "collector");
export const businessProcedure = roleProcedure("admin", "shop", "collector", "user");
