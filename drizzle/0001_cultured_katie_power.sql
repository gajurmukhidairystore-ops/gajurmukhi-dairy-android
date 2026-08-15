CREATE TABLE `customers` (
	`id` int AUTO_INCREMENT NOT NULL,
	`name` varchar(160) NOT NULL,
	`phone` varchar(32),
	`openingBalance` decimal(12,2) NOT NULL DEFAULT '0',
	`createdAt` timestamp NOT NULL DEFAULT (now()),
	CONSTRAINT `customers_id` PRIMARY KEY(`id`)
);
--> statement-breakpoint
CREATE TABLE `farmers` (
	`id` int AUTO_INCREMENT NOT NULL,
	`name` varchar(160) NOT NULL,
	`phone` varchar(32),
	`village` varchar(120),
	`active` int NOT NULL DEFAULT 1,
	`createdAt` timestamp NOT NULL DEFAULT (now()),
	CONSTRAINT `farmers_id` PRIMARY KEY(`id`)
);
--> statement-breakpoint
CREATE TABLE `invoice_items` (
	`id` int AUTO_INCREMENT NOT NULL,
	`invoiceId` int NOT NULL,
	`productId` int NOT NULL,
	`productName` varchar(160) NOT NULL,
	`quantity` decimal(12,3) NOT NULL,
	`unitPrice` decimal(12,2) NOT NULL,
	`lineTotal` decimal(12,2) NOT NULL,
	CONSTRAINT `invoice_items_id` PRIMARY KEY(`id`)
);
--> statement-breakpoint
CREATE TABLE `invoices` (
	`id` int AUTO_INCREMENT NOT NULL,
	`invoiceNumber` varchar(48) NOT NULL,
	`customerId` int,
	`subtotal` decimal(12,2) NOT NULL,
	`discount` decimal(12,2) NOT NULL DEFAULT '0',
	`total` decimal(12,2) NOT NULL,
	`paymentMode` enum('cash','credit','upi') NOT NULL DEFAULT 'cash',
	`status` enum('paid','pending') NOT NULL DEFAULT 'paid',
	`createdAt` timestamp NOT NULL DEFAULT (now()),
	CONSTRAINT `invoices_id` PRIMARY KEY(`id`),
	CONSTRAINT `invoices_invoiceNumber_unique` UNIQUE(`invoiceNumber`)
);
--> statement-breakpoint
CREATE TABLE `ledger_entries` (
	`id` int AUTO_INCREMENT NOT NULL,
	`customerId` int NOT NULL,
	`type` enum('debit','credit') NOT NULL,
	`amount` decimal(12,2) NOT NULL,
	`reference` varchar(160),
	`note` text,
	`createdAt` timestamp NOT NULL DEFAULT (now()),
	CONSTRAINT `ledger_entries_id` PRIMARY KEY(`id`)
);
--> statement-breakpoint
CREATE TABLE `milk_collections` (
	`id` int AUTO_INCREMENT NOT NULL,
	`farmerId` int NOT NULL,
	`session` enum('morning','evening') NOT NULL,
	`quantityLiters` decimal(12,3) NOT NULL,
	`fat` decimal(5,2) NOT NULL,
	`snf` decimal(5,2) NOT NULL,
	`ratePerLiter` decimal(10,2) NOT NULL,
	`amount` decimal(12,2) NOT NULL,
	`collectedAt` timestamp NOT NULL DEFAULT (now()),
	CONSTRAINT `milk_collections_id` PRIMARY KEY(`id`)
);
--> statement-breakpoint
CREATE TABLE `products` (
	`id` int AUTO_INCREMENT NOT NULL,
	`name` varchar(160) NOT NULL,
	`unit` varchar(32) NOT NULL,
	`price` decimal(12,2) NOT NULL,
	`stockQuantity` decimal(12,3) NOT NULL DEFAULT '0',
	`lowStockThreshold` decimal(12,3) NOT NULL DEFAULT '5',
	`active` int NOT NULL DEFAULT 1,
	`createdAt` timestamp NOT NULL DEFAULT (now()),
	`updatedAt` timestamp NOT NULL DEFAULT (now()) ON UPDATE CURRENT_TIMESTAMP,
	CONSTRAINT `products_id` PRIMARY KEY(`id`)
);
--> statement-breakpoint
CREATE TABLE `rate_slabs` (
	`id` int AUTO_INCREMENT NOT NULL,
	`name` varchar(120) NOT NULL,
	`minFat` decimal(5,2) NOT NULL,
	`maxFat` decimal(5,2) NOT NULL,
	`minSnf` decimal(5,2) NOT NULL,
	`maxSnf` decimal(5,2) NOT NULL,
	`ratePerLiter` decimal(10,2) NOT NULL,
	`active` int NOT NULL DEFAULT 1,
	`createdAt` timestamp NOT NULL DEFAULT (now()),
	CONSTRAINT `rate_slabs_id` PRIMARY KEY(`id`)
);
