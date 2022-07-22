# Multi-tenant Data Factory Demo 

This demo is provided as-is and is not supported in any way by me or Microsoft. It has been tested on serval different types of subscriptions but there may be deployment issues in some regions or some subscription types. Feel free to provide feedback but I can not guarantee that it will be addressed.

Success in implementing this demo is reliant on you having some basic knowledge around Azure, Azure SQL Database and Azure Data Factory. If you need training, you should take training. 

The demo is designed to highlight one way in one scenario to build multi-tenant, reusable pipelines. It is not intended to be best practice for every possible feature or scenario and it is especially NOT following best practice for security. READ: Do not implement production security like this demo.

## Demo Guide

### Deploy Azure resources
Please read and understand the entire step before trying to execute. All resources should be deployed to the same Azure region. Since this is a demo only, I would also recommend deploying to the same resource group. __I highly recommend that you deploy using the supplied arm template located in this repository at ___./arm_template/resources-arm.json.___ Alternatively you can follow the steps and guidance below. The provided arm template deploys everything as described below.__

1. Deploy source databases. For this demo I deployed three Azure SQL Databases with the sample database. These are all hosted from the same Logical SQL Server. I use the S2 tier during the demo but scale down to S1 when I am not actively using it. I also enable SQL Authentication. The pipeline will use SQL Authentication so for ease of use I would use the same admin account for all of your databases. The best practice security wise would be to use a Managed Identity in Data Factory and grant access to SQL databases. Also make sure that your databases are using a public endpoint for this demo.

2. Deploy the destination data warehouse. For this I deployed one Azure SQL Database. It is hosted on the same Logical SQL Server as the source databases. I use the S3 tier during the demo but scale down to S1 when I am not actively using it. I also enable SQL Authentication. I created the same admin account as the source databases, again, not best practice, it is just so I do'nt have to memorize a bunch of user names and passwords. Also make sure that your databases are using a public endpoint for this demo.

3. Deploy Azure Data Factory. Nothing to really point out here. If you cannot figure out how to do this, maybe this whole computer thing isn't for you.

### Deploy the ARM pipeline ARM template

> __Note__: This step is required. This step is not covered in the previous arm template deployment. The previous section is for deploying Azure resources while this step deploys your Data Factory Pipeline.

1. Open Azure Data Factory in the Azure Portal and click on __Open Azure Data Factory Studio__. 

2. Select the __Manage__ icon on the left, choose __ARM template__, and select __Import ARM template__. This should launch the __Custom deployment__ page in the Azure portal.

3. Select __Build your own template in the editor__ and leave it open for now.

4. Open the __arm_template\arm_template.json__ file in this repository. Select all of the text and then paste it into the __Edit template__ page and click __Save__.

5. Now choose the __resource group__ and __region__ that you are deploying into, update the __Factory Name__ to reflect your data factory name. There are two connection strings you will need to populate. Below are examples of what these should look like (without the quotes). The highlighted values below will need to be updated to reflect your logins and server names.

    __Tenant Databases_connectionString =__ integrated security=False;encrypt=True;connection timeout=30;data source=@{linkedService().ServerName};initial catalog=@{linkedService().DatabaseName};user id=`dblogin`

    __Warehouse_connectionString =__ integrated security=False;encrypt=True;connection timeout=30;data source=`db-host`.database.windows.net;initial catalog=`warehouse-multi-tenant`;user id=`warehouselogin`

    > __Note__: The tenant database connection string is parameterized for the data source and initial catalog values. The pipeline will automatically fill in these values at run time.

6. Select __Review + create__, then choose the __Create__ button. Give the template a few minutes to deploy. Close and reopen your Azure Data Factory Studio and verify that you ARM template has successfully deployed by navigating to the __Author__ page. Here you should now have two pipelines and three datasets.

### Configure your metadata tables
This solution leverage the use of metadata tables in the destination database to store the server names, database names and tenant ids for the source databases. It also stores a list of table names that we would like to copy in our pipeline.

1. From the Azure portal, navigate to your warehouse database. Select __Query editor__ from the menu on the left and login to the database.

2. Open the __SQL Queries\meta-driven-pipeline.sql__ file in a text editor. You WILL need to update the insert statements for the TenantMetadata table with the correct ServerNames and DatabaseNames for your environment. The parts you must changed are highlighted below.


    INSERT INTO TenantMetadata
    VALUES (1, N'tenant1', N'`db-host`.database.windows.net', N'`db-tenant1`');

    INSERT INTO TenantMetadata
    VALUES (2, N'tenant2', N'`db-host`.database.windows.net', N'`db-tenant2`');

    INSERT INTO TenantMetadata
VALUES (3, N'tenant3', N'`db-host`.database.windows.net', N'`db-tenant3`');


3. The rest of the script may remain as-is. I have added a couple of tips on getting started with indexing for these tables. Keep in mind, if you have a small number of rows, indexing will not matter. So, the indexing is basically academic for the purposes of the demo but might be helpful in some cases where you have larger numbers of rows (see the comments in the script).

4. Generate the cleanup script by copying the contents of the __SQL Queries\CleanupSchema.sql__ file into the query editor and running it. No customizations are necessary.

    >__Note__: For the purposes of the demo we do the cleanup of the staging tables at the beginning of the pipeline. However, for real world usage you would usually cleanup the staging tables after the production table load completes.

### Configure your pipeline

1. To run the pipeline you will need to supply passwords for the linked services. Linked services hold the connection information for your sources and destinations. From the Azure Data Factory Studio, navigate to __Manage__->__Linked Services__->__TenantDatabases__. Update the __User name__ and __Password__ to match your source databases. 

    >__Note__: At this point the __Test connection__ will not work for this linked service without you manually updating the values for the __Fully qualified domain name ***@{linkedService().ServerName}***__ and the __DatabaseName ***@{linkedService().DatabaseName}***__ parameters. If you scroll down on the__Edit linked service__ blade, you should see a parameters section with the parameterized values we are using. So if you want to test the connect, there will be a popout allowing you to provide those parameters manually (you may leave tenant-id set to the default for connection testing. When we run the pipeline, these parameterized values will be automatically populated from the tables we created earlier.

2. Select __Apply__ to accept the changes.

3. Open the __warehouse__ linked service. Here you will need to update the __Fully qualified domain name__, the __DatabaseName__, the __User name__ and the __Password__ to match your destination database (aka your data warehouse). Click __Test connection__ to validate your configuration then select __Apply__ to accept the changes.

4. If you have changes to publish, click the __Publish all__ button.

### Understanding the pipelines, activities, datasets and linked services

This solution contains two pipelines and three datasets. Each will be described in detail below. 

The first pipeline is the __TenantPipeline__. This is the master pipeline. When running the demo, it is only necessary to trigger this pipeline, all other components of the demo are automated.

The __TenantPipeline__ consists of four activities described below.

1. The __CleanupStagingTables__ stored procedure activity. This activity simply connects to the warehouse database and cleans up the staging tables and schema by calling the dbo.CleanupStagingSchema stored procedure. Everything here is hardcoded. If you are implementing your own stored procedure here, the only thing to be aware of, is that you typically want this activity to be idempotent. So if it runs, and there is nothing to cleanup, it still completes with success. Likewise, if it runs and does have to cleanup tables and schemas, it also completes with success.

2. The __TenantLookup__ lookup activity. This activity is responsible for pulling the list of tenants by running the ___SELECT * FROM TenantMetadata ORDER BY TenantPriority___ query in the warehouse database. There is no parameterization in this activity but the output which will be passed on to the next activity is JSON formatted with the results of the query that will look something like this:  
    ```json
    {
    "count": 3,
    "value": [
        {
            "TenantPriority": 1,
            "TenantID": "tenant1",
            "ServerName": "db-host.database.windows.net",
            "DatabaseName": "db-tenant1"
        },
        {
            "TenantPriority": 2,
            "TenantID": "tenant2",
            "ServerName": "db-host.database.windows.net",
            "DatabaseName": "db-tenant2"
        },
        {
            "TenantPriority": 3,
            "TenantID": "tenant3",
            "ServerName": "db-host.database.windows.net",
            "DatabaseName": "db-tenant3"
        }
    ]
    }
    ```

    >__Note__: In many production workloads, these metadata tables would be in a dedicated config database, especially if you have lots of rows, or lots of pipelines leveraging the tables, or if the source and or destination databases are in another region.

3. The next activity is the __ForEachTenant__ ForEach activity. If you select this activity, then choose the __Settings__ tab, you will see that under __Items__ we have added dynamic content representing the output of the previous lookup activity. The value is ___@activity('TenantLookup').output.value___. If you delete this item, click in the empty field and choose the __Add dynamic content__ link you will get a popup showing you all of the accessible options for dynamic content. Choose __TenantLookup value array__, which will give you the entire array of results from your lookup. The ForEach activity will then iterate through each element of the array. Note that ForEach loops are not recursive so nested arrays will not processed by the loop.

    On the __Settings__ tab of your __ForEachTenant__ activity, notice there is a __Sequential__ checkbox. Enabling this allows your loop to process only one iteration at a time. In this condition, the loop will wait for the iteration to complete until the next one begins. The default behavior is is for the iterations to all run as soon as possible. Since we would like to process all tenants in parallel, we have left this option disabled.

4. Within your __ForEachTenant__ activity you have the __ExecCopyDatabasePipeline__ activity. This is an an Execute Pipeline activity. We are using it to execute the DatabaseCopyPipeline for each tenant. If you open the __ExecCopyDatabasePipeline__ activity and click on the __Settings__ tab, you will see the name of the invoked pipeline. You will also notice that we have defined three parameters here; __ServerName__, __DatabaseName__ and __TenantID__. These parameters will be passed into the invoked pipeline. If you delete one of these items and then click the __Add dynamic content__ link, you will be taken to the add dynamic content popup. Choose __ForEachTenant__ under the __ForEach iterator__ section. This will show __@item()__ in the editing box. But the item that we are iterating on is actually an array with one element for each column. So to properly assign the value from the array to the parameter type ___.column-name___ replacing column-name with the name of the parameter you deleted, your line should look something like this ___@item().ServerName___. Click __OK__, then publish any changes.

5. Open the __DatabaseCopyPipeline__ under the Factory Resources menu. This pipeline is responsible for collecting the list of tables that we want to copy from each source and then copying each of those tables to the warehouse staging tables. Notice that on the __Parameters__ tab, we have the same parameters that we had in our Execute Pipeline activity. These parameters will be populated by the calling pipeline.

6. The __LookupTables__ lookup activity. This activity is responsible for pulling the list of tables we would like to copy from the source databases by running the ___SELECT * FROM SchemaMetadata WHERE CopyFlag = 1 ORDER BY CopyPriority___ query in the warehouse database. The ORDER BY on the __CopyPriority__ column allows us to copy tables in a certain order if necessary by changing the values in the table. The __SchemaName__ and __TableName__ columns should be self-explanitory. The __CopyFlag__ is not used in the demo but it could be used to allow the exclusion of certain tables from the copy process by filtering on this column. There is no parameterization in this activity but the output which will be passed on to the next activity is JSON formatted with the results of the query that will look something like this:
    ```json
    {
    "count": 10,
    "value": [
        {
            "CopyPriority": 1,
            "SchemaName": "SalesLT",
            "TableName": "Address",
            "CopyFlag": true
        },
        {
            "CopyPriority": 2,
            "SchemaName": "SalesLT",
            "TableName": "Customer",
            "CopyFlag": true
        },
        {
            "CopyPriority": 3,
            "SchemaName": "SalesLT",
            "TableName": "CustomerAddress",
            "CopyFlag": true
        },
        {
            "CopyPriority": 4,
            "SchemaName": "SalesLT",
            "TableName": "ProductCategory",
            "CopyFlag": true
        },
        {
            "CopyPriority": 5,
            "SchemaName": "SalesLT",
            "TableName": "ProductModel",
            "CopyFlag": true
        },
        {
            "CopyPriority": 6,
            "SchemaName": "SalesLT",
            "TableName": "ProductDescription",
            "CopyFlag": true
        },
        {
            "CopyPriority": 7,
            "SchemaName": "SalesLT",
            "TableName": "ProductModelProductDescription",
            "CopyFlag": true
        },
        {
            "CopyPriority": 8,
            "SchemaName": "SalesLT",
            "TableName": "Product",
            "CopyFlag": true
        },
        {
            "CopyPriority": 9,
            "SchemaName": "SalesLT",
            "TableName": "SalesOrderHeader",
            "CopyFlag": true
        },
        {
            "CopyPriority": 10,
            "SchemaName": "SalesLT",
            "TableName": "SalesOrderDetail",
            "CopyFlag": true
        }
    ]
    }
    ```

7. The next activity is the __ForEachTable__ ForEach activity. If you select this activity, then choose the __Settings__ tab, you will see that under __Items__ we have added dynamic content representing the output of the previous lookup activity. The value is ___@activity('LookupTables').output.value___. Notice that on this ForEach loop we have chosen to make the loop sequential so that we only copy one table at a time. This is not strictly necessary as we have no referential integrity being enforced on the destination tables but in cases where you do this can be used to load tables in the correct order. 

8. Finally we have the __CopyTable__ activity. This copy data activity is what actually moves data from the source to the destination. 

    Open the __CopyTable__ activity and select the __Source__ tab. Here we define the source dataset __TenantData__ that we will copy data from. __TenantData__ is a parameterized dataset that in turn uses the __TenantDatabases__ parameterized Linked Service. You can see the list of dataset properties that we are using here. The __SchemaName__ and __TableName__ properties are being populated by values from our lookup and __DatabaseName__, __ServerName__ and __TenantID__ are pipeline parameters that were passed in via the execute pipeline activity in the __TenantPipeline__.

    If you scroll to the bottom of the __Source__ tab you will notice a section called __Additional columns__. This adds a new column to every table and populates it with the __TenantID__ pipeline parameter. This allows us to differentiate similar rows in the warehouse that belong to different tenants. For example, if two tenants have an order with the same orderID, you would need a way to differentiate one from the other. 

    Now move to the __Sink__ tab. Here we are copying data into the __StagingData__ dataset. It takes one parameter, __StagingTable__, which is populated with the __TableName__ value passed in during the lookup. If you open the dataset you will see that we are using the __warehouse__ linked service. For the table, we have hard coded the schema to __staging__ and are using the dataset property __StagingTable__ for the table name. 

### Running the pipeline

1. If you have any unpublished changes, publish them now.

2. Navigate to the __TenantPipeline__. Remember this is our master pipeline and as such we kick off our copy process from here. This pipeline takes no input from the user, it will collect all the information it needs to complete the copy from our metadata tables.

3. Click the __Add trigger__ button and choose __Trigger now__ from the dropdown and click __OK__ on the popup. 

You can monitor the progress of the pipelines by selecting the __Monitor__ tab on the left menu. The time it takes to complete will depend on the scale of your databases (especially the destination). If you pipeline is not making progress, click the refresh button near the top of the page.