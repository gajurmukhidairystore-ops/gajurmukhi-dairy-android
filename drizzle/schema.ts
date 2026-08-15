import { int, decimal, mysqlEnum, mysqlTable, text, timestamp, varchar } from "drizzle-orm/mysql-core";

export const users = mysqlTable("users", {
  id: int("id").autoincrement().primaryKey(),
  openId: varchar("openId", { length: 64 }).notNull().unique(),
  name: text("name"),
  email: varchar("email", { length: 320 }),
  loginMethod: varchar("loginMethod", { length: 64 }),
  role: mysqlEnum("role", ["user", "admin", "shop", "collector"]).default("user").notNull(),
  createdAt: timestamp("createdAt").defaultNow().notNull(),
  updatedAt: timestamp("updatedAt").defaultNow().onUpdateNow().notNull(),
  lastSignedIn: timestamp("lastSignedIn").defaultNow().notNull(),
});

export const products = mysqlTable("products", {
  id: int("id").autoincrement().primaryKey(),
  name: varchar("name", { length: 160 }).notNull(),
  unit: varchar("unit", { length: 32 }).notNull(),
  price: decimal("price", { precision: 12, scale: 2 }).notNull(),
  stockQuantity: decimal("stockQuantity", { precision: 12, scale: 3 }).default("0").notNull(),
  lowStockThreshold: decimal("lowStockThreshold", { precision: 12, scale: 3 }).default("5").notNull(),
  active: int("active").default(1).notNull(),
  createdAt: timestamp("createdAt").defaultNow().notNull(),
  updatedAt: timestamp("updatedAt").defaultNow().onUpdateNow().notNull(),
});

export const customers = mysqlTable("customers", {
  id: int("id").autoincrement().primaryKey(),
  name: varchar("name", { length: 160 }).notNull(),
  phone: varchar("phone", { length: 32 }),
  openingBalance: decimal("openingBalance", { precision: 12, scale: 2 }).default("0").notNull(),
  createdAt: timestamp("createdAt").defaultNow().notNull(),
});

export const farmers = mysqlTable("farmers", {
  id: int("id").autoincrement().primaryKey(),
  name: varchar("name", { length: 160 }).notNull(),
  phone: varchar("phone", { length: 32 }),
  village: varchar("village", { length: 120 }),
  active: int("active").default(1).notNull(),
  createdAt: timestamp("createdAt").defaultNow().notNull(),
});

export const rateSlabs = mysqlTable("rate_slabs", {
  id: int("id").autoincrement().primaryKey(),
  name: varchar("name", { length: 120 }).notNull(),
  minFat: decimal("minFat", { precision: 5, scale: 2 }).notNull(),
  maxFat: decimal("maxFat", { precision: 5, scale: 2 }).notNull(),
  minSnf: decimal("minSnf", { precision: 5, scale: 2 }).notNull(),
  maxSnf: decimal("maxSnf", { precision: 5, scale: 2 }).notNull(),
  ratePerLiter: decimal("ratePerLiter", { precision: 10, scale: 2 }).notNull(),
  active: int("active").default(1).notNull(),
  createdAt: timestamp("createdAt").defaultNow().notNull(),
});

export const invoices = mysqlTable("invoices", {
  id: int("id").autoincrement().primaryKey(),
  invoiceNumber: varchar("invoiceNumber", { length: 48 }).notNull().unique(),
  customerId: int("customerId"),
  subtotal: decimal("subtotal", { precision: 12, scale: 2 }).notNull(),
  discount: decimal("discount", { precision: 12, scale: 2 }).default("0").notNull(),
  total: decimal("total", { precision: 12, scale: 2 }).notNull(),
  paid: decimal("paid", { precision: 12, scale: 2 }).default("0").notNull(),
  due: decimal("due", { precision: 12, scale: 2 }).default("0").notNull(),
  paymentMode: mysqlEnum("paymentMode", ["cash", "qr", "bank", "credit"]).default("cash").notNull(),
  status: mysqlEnum("status", ["paid", "pending"]).default("paid").notNull(),
  qrStatus: mysqlEnum("qrStatus", ["not_applicable", "pending", "received"]).default("not_applicable").notNull(),
  createdAt: timestamp("createdAt").defaultNow().notNull(),
});

export const invoiceItems = mysqlTable("invoice_items", {
  id: int("id").autoincrement().primaryKey(),
  invoiceId: int("invoiceId").notNull(),
  productId: int("productId").notNull(),
  productName: varchar("productName", { length: 160 }).notNull(),
  quantity: decimal("quantity", { precision: 12, scale: 3 }).notNull(),
  unitPrice: decimal("unitPrice", { precision: 12, scale: 2 }).notNull(),
  lineTotal: decimal("lineTotal", { precision: 12, scale: 2 }).notNull(),
});

export const ledgerEntries = mysqlTable("ledger_entries", {
  id: int("id").autoincrement().primaryKey(),
  customerId: int("customerId").notNull(),
  type: mysqlEnum("type", ["debit", "credit"]).notNull(),
  amount: decimal("amount", { precision: 12, scale: 2 }).notNull(),
  reference: varchar("reference", { length: 160 }),
  note: text("note"),
  createdAt: timestamp("createdAt").defaultNow().notNull(),
});

export const settings = mysqlTable("settings", {
  id: int("id").autoincrement().primaryKey(),
  settingKey: varchar("settingKey", { length: 80 }).notNull().unique(),
  settingValue: text("settingValue").notNull(),
  updatedAt: timestamp("updatedAt").defaultNow().onUpdateNow().notNull(),
});

export const payments = mysqlTable("payments", {
  id: int("id").autoincrement().primaryKey(),
  invoiceId: int("invoiceId"),
  customerId: int("customerId"),
  amount: decimal("amount", { precision: 12, scale: 2 }).notNull(),
  mode: mysqlEnum("mode", ["cash", "qr", "bank", "credit"]).notNull(),
  reference: varchar("reference", { length: 160 }),
  createdAt: timestamp("createdAt").defaultNow().notNull(),
});

export const milkCollections = mysqlTable("milk_collections", {
  id: int("id").autoincrement().primaryKey(),
  farmerId: int("farmerId").notNull(),
  session: mysqlEnum("session", ["morning", "evening"]).notNull(),
  quantityLiters: decimal("quantityLiters", { precision: 12, scale: 3 }).notNull(),
  fat: decimal("fat", { precision: 5, scale: 2 }).notNull(),
  snf: decimal("snf", { precision: 5, scale: 2 }).notNull(),
  ratePerLiter: decimal("ratePerLiter", { precision: 10, scale: 2 }).notNull(),
  amount: decimal("amount", { precision: 12, scale: 2 }).notNull(),
  collectedAt: timestamp("collectedAt").defaultNow().notNull(),
});

export type User = typeof users.$inferSelect;
export type InsertUser = typeof users.$inferInsert;
export type Product = typeof products.$inferSelect;
export type Customer = typeof customers.$inferSelect;
export type Farmer = typeof farmers.$inferSelect;
export type RateSlab = typeof rateSlabs.$inferSelect;
export type Invoice = typeof invoices.$inferSelect;
export type MilkCollection = typeof milkCollections.$inferSelect;
export type Setting = typeof settings.$inferSelect;
export type Payment = typeof payments.$inferSelect;
