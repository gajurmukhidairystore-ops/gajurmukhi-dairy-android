ALTER TABLE `invoices` MODIFY COLUMN `paymentMode` enum('cash','qr','bank','credit') NOT NULL DEFAULT 'cash';--> statement-breakpoint
ALTER TABLE `payments` MODIFY COLUMN `mode` enum('cash','qr','bank','credit') NOT NULL;--> statement-breakpoint
ALTER TABLE `invoices` ADD `paid` decimal(12,2) DEFAULT '0' NOT NULL;--> statement-breakpoint
ALTER TABLE `invoices` ADD `due` decimal(12,2) DEFAULT '0' NOT NULL;