-- This is for creating a metadata driven pipeline. In this scenario you will have 3 Azure SQL Databases with the sample db installed.
-- The scenario is for populating a "warehouse" from multiple databases where each database holds one tenant's data
-- This IS NOT an example of datawarehouse design/data modeling best practices.
-- Create this in either a dedicated config database or possibly the warehouse. The best practice would be to use a config database, especially if you need to do other things like storing position markers for each table.
-- I have chossen to go pretty bare-bones here, the idea is that I will use the tenant id to retrieve the servername and database name which are the bare minimum needed for connection assuming that I use either managed identity or a hardcoded username and password to connect

/*
DROP TABLE SchemaMetadata
DROP TABLE TenantMetadata
*/

CREATE TABLE TenantMetadata (
	[TenantPriority] int, --usefull if you want to process tenants in a specific order
    [TenantID] sysname,
	[ServerName] sysname,
	[DatabaseName] sysname
	)
CREATE CLUSTERED INDEX CIX_TenantMetadata_Priority ON dbo.TenantMetadata (TenantPriority)
-- If you have lots of tenants/databases to connect to and you might connect by TenantID you should add this index
CREATE INDEX NCIX_TenantMetadata_TenantID ON dbo.TenantMetadata (TenantID) INCLUDE (ServerName, DatabaseName)

-- This just populates for my multi-tenant example, you will very likely have different servernames at a minimum
INSERT INTO TenantMetadata
VALUES (1, N'tenant1', N'db-host.database.windows.net', N'db-tenant1');

INSERT INTO TenantMetadata
VALUES (2, N'tenant2', N'db-host.database.windows.net', N'db-tenant2');

INSERT INTO TenantMetadata
VALUES (3, N'tenant3', N'db-host.database.windows.net', N'db-tenant3');


/* Tables in this database, the schema is always SalesLT *
Address
Customer
CustomerAddress
Product
ProductCategory
ProductDescription
ProductModel
ProductModelProductDescription
SalesOrderDetail
SalesOrderHeader
*/

CREATE TABLE SchemaMetadata (
    [CopyPriority] int, -- Usefull for ordered copying of tables
	[SchemaName] sysname,
	[TableName] sysname,
	[CopyFlag] bit
	)
-- If you have hundreds of tables you might want to prioritize some, or copy only a range of them
CREATE CLUSTERED INDEX CIX_SchemaMetadata_Priority ON dbo.SchemaMetadata (CopyPriority)
-- If you have lots of tables to copy and you might copy by TableName you should add this index
CREATE INDEX NCIX_SchemaMetadata_TenantID ON dbo.SchemaMetadata (TableName) INCLUDE (SchemaName, CopyFlag)

-- Note that the order is based on the RI requirements of the source. This may be different on the destination or RI may not exist at all
INSERT INTO SchemaMetadata
VALUES (1, N'SalesLT', N'Address', 1);

INSERT INTO SchemaMetadata
VALUES (2, N'SalesLT', N'Customer', 1);

INSERT INTO SchemaMetadata
VALUES (3, N'SalesLT', N'CustomerAddress', 1);

INSERT INTO SchemaMetadata
VALUES (4, N'SalesLT', N'ProductCategory', 1);

INSERT INTO SchemaMetadata
VALUES (5, N'SalesLT', N'ProductModel', 1);

INSERT INTO SchemaMetadata
VALUES (6, N'SalesLT', N'ProductDescription', 1);

INSERT INTO SchemaMetadata
VALUES (7, N'SalesLT', N'ProductModelProductDescription', 1);

INSERT INTO SchemaMetadata
VALUES (8, N'SalesLT', N'Product', 1);

INSERT INTO SchemaMetadata
VALUES (9, N'SalesLT', N'SalesOrderHeader', 1);

INSERT INTO SchemaMetadata
VALUES (10, N'SalesLT', N'SalesOrderDetail', 1);

