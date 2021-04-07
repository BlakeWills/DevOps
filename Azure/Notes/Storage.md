# Azure Storage Options

There are four different types of storage available within Azure:

- Blob (**B**inary **l**arge **ob**ject)
- File Storage
- Azure SQL
- Cosmos DB

## Blob Storage

Used to store unstructured data, E.G. documents, video or image files. They can also be used to store virtual machine image files.

There are three types of blob:

1. Block
2. Append Block
3. Page

### Block & Append Block

Block storage optimises for file upload by chunking files up into "blocks". This makes it easier to upload really large files, you can even split a file into blocks, upload them in parallel, then "put the file back together again" by resequencing the blocks once they have all been uploaded.

The difference between a block and an append block is that when you upload a new block to an append block, it is always appended to the end of the block. This is useful for things such as log files.

### Page

Page blobs are a collection of 512 byte pages that are optimised for random read and writes. When you initialize a new page blob you specify the maximum size of the blob. You can add or update (replace) pages in the blob. This is used for storing things like virtual machine images and database files.

### Tiers

There are three service tiers for blob storage: hot, cool and archive.

**Hot:**

Used for frequently accessed data.
Highest storge cost, lowest transaction cost.

**Cool:**

Used for infrequently accessed data.
Lower storage cost, higher transaction cost.

**Archive:**

Used for rarely accessed data. Can take hours to "rehydrate" the data.
Lowest storage cost, highest transaction cost.

## File Storage

File storage is basically a file share that can be mounted to a VM or accessed via a REST interface.

## Azure SQL

Azure has many IaaS, PaaS and SaaS SQL offerings for many different database engines.

You can build a VM and install SQL on it, or you could use a managed offering such as Azure SQL Database. Benefits of using Azure SQL Database include auto scaling, data replication and automated patching.

There are managed offerings for MSSQL, MySql and Postgres.

## Cosmos DB

Cosmos DB is a NoSql database for storing semi-structured data. It has configurable consistency guarentees.

## Redundany Options

### Locally Redundant Storage (LRS)

Data gets replicated three times within the primary data center.

### Zone Redundant Storage (ZRS)

Data gets replicated across availability zones within the same region.

### Geo Redundant Storage (GRS)

Data gets replicated within the primary region (LRS) and also gets replicated across to another region.

### Geo Zone Redundant Storage (GZRS)

A combination of ZRS and GRS, where data is replicated across availability zones within a region and also replicated across to another region for DR.

### Read Access Geo Zone Redundant Storage (RA-GZRS)

This is the same as GZRS but with read access to the replicas.

## Storage Accounts

To utilise storage offerings in Azure you first need a storage account. This is a namespace that groups storage and is the level at which configuration options such as redundancy and performance tiers are configured. It is also the level at which you are billed.
