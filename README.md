# multitenant-adf demo 

This demo is designed to highlight one way to build multi-tenant, reusable pipelines. It is not intended to be best practice for every possible feature and it is especially NOT following best practice for security. 

## Demo setup guidance

### Deploy Azure resources
Please read and understand the entire step before trying to execute. All resources should be deployed to the same Azure region. Since this is a demo only, I would also recommend deploying to the same resource group.

1. Deploy source databases. For this demo I deployed three Azure SQL Databases with the sample database. These are all hosted from the same Logical SQL Server. I use the S2 tier during the demo but scale down to S1 when I am not actively using it. I also enable both SQL Authentication and Azure AD Authentication. The pipeline will use SQL Authentication so for ease of use I would use the same admin account for all of your databases. The best practice security wise would be to use a Managed Identity in Data Factory and grant access to SQL databases. Also make sure that your databsases are using a public endpoint for this demo.

2. Deploy the destination data warehouse. For this I deployed one Azure SQL Database. It is hosted on the same Logical SQL Server as the source databases. I use the S3 tier during the demo but scale down to S1 when I am not actively using it. I also enable both SQL Authentication and Azure AD Authentication. I created the same admin account as the source databases, again, not best practice, it is just so I dont have to memorize a bunch of user names and passwords. Also make sure that your databsases are using a public endpoint for this demo.

3. Deploy Azure Data Factory. Nothing to really point out here. If you cannot figure out how to do this, maybe this whole computer thing isn't for you.

### Deploy the ARM pipeline ARM template

1. Open Azure Data Factory in the Azure Portal and click on __Open Azure Data Factory Studio__. 

2. Select the __Manage__ icon on the left, choose __ARM template__, and select __Import ARM tempate__. This should launch the __Custom deployment__ page in the Azure portal.

3. Select __Build your own template in the editor__ and leave it open for now.

4. Open the __arm_template\arm_template.json__ file in this repository. Select all of the text and then paste it into the __Edit template__ page and click __Save__.

5. Now choose the __resource group__ and __region__ that you are deploying into, update the __Factory Name__ to reflect your data factory name. There are two connection strings you will need to populate. Below are examples of what these should look like (without the quotes). The highlighted values below will need to be updated to reflect your logins and server names.

    __Tenant Databases_connectionString =__ "integrated security=False;encrypt=True;connection timeout=30;data source=@{linkedService().ServerName};initial catalog=@{linkedService().DatabaseName};user id=<span style="background-color: #FFFF00">dblogin</span>"

    __Warehouse_connectionString =__ "integrated security=False;encrypt=True;connection timeout=30;data source=<span style="background-color: #FFFF00">db-host</span>.database.windows.net;initial catalog=<span style="background-color: #FFFF00">warehouse-multi-tenant</span>;user id=<span style="background-color: #FFFF00">warehouselogin</span>"

    > __Note__: The tenant database connection string is parameterized for the data source and initial catalog values. The pipeline will automatically fill in these values at run time.

6. Select __Review + create__, then choose the __Create__ button. Give the template a few minutes to deploy. Close and reopen your Azure Data Factory Studio and verify that you ARM template has successfully deployed by navigating to the __Author__ page. Here you should now have two pipelines and three datasets.

### Configure your metadata tables
This solution leverage the use of metadata tables in the destination database to store the server names, database names and tenant ids for the source databases. It also stores a list of table names that we would like to copy in our pipeline.

1. From the Azure portal, navigate to your warehouse database. Select __Query editor__ from the menu on the left and login to the database.

2. Open the __SQL Queries\meta-driven-pipeline.sql__ file in a text editor. You WILL need to update the insert statements for the TenantMetadata table with the correct ServerNames and DatabaseNames for your environment. The parts you must changed are highlighted below.

    INSERT INTO TenantMetadata
VALUES (1, N'tenant1', N'<span style="background-color: #FFFF00">db-host</span>.database.windows.net', N'<span style="background-color: #FFFF00">db-tenant1</span>');

    INSERT INTO TenantMetadata
VALUES (2, N'tenant2', N'<span style="background-color: #FFFF00">db-host</span>.database.windows.net', N'<span style="background-color: #FFFF00">db-tenant2</span>');

    INSERT INTO TenantMetadata
VALUES (3, N'tenant3', N'<span style="background-color: #FFFF00">db-host</span>.database.windows.net', N'<span style="background-color: #FFFF00">db-tenant3</span>');

3. The rest of the script may remain as-is. I have added a couple of tips on getting started with indexing for these tables. Keep in mind, if you have a small number of rows, indexing will not matter. So, the indexing is basically academic for the purposes of the demo but might be helpfull in some cases where you have larger numbers of rows (see the comments in the script).

4. Generate the cleanup script by copying the contents of the __SQL Queries\CleanupSchema.sql__ file into the query editor and running it. No customizations are necessary.

    >__Note__: For the purposes of the demo we do the cleanup of the staging tables at the beginning of the pipeline. However, for real world usage you would usually cleanup the staging tables after the production table load completes.

### Configure your pipeline

1. To run the pipeline you will need to suppy passwords for the linked services. Linked services hold the connection information for your sources and destinations. From the Azure Data Factory Studio, navigate to __Manage__->__Linked Services__->__TenantDatabases__. Update the __User name__ and __Password__ to match your source databases. 

    >__Note__: At this point the __Test connection__ will not work for this linked service without you manually updating the values for the __Fully qualified domain name ***@{linkedService().ServerName}***__ and the __DatabaseName ***@{linkedService().DatabaseName}***__ parameters. If you scroll down on the__Edit linked service__ blade, you should see a parameters section with the parameterized values we are using. So if you want to test the connect, there will be a popout allowing you to provide those parameters manually (you may leave tenant-id set to the default for connection testing. When we run the pipeline, these parameterized values will be automatically populated from the tables we created earlier.

2. Select __Apply__ to accept the changes.

3. Open the __warehouse__ linked service. Here you will need to update the __Fully qualified domain name__, the __DatabaseName__, the __User name__ and the __Password__ to match your destination database (aka your data warehouse). Click __Test connection__ to validate your configuration then select __Apply__ to accept the changes.

4. If you have changes to publish, click the __Publish all__ button.

### Understanding and running the pipelines

This solution contains two pipelines and three datasets. Each will be described in detail below. The pipeline

The first pipeline is the __TenantPipeline__. This is the master pipeline. When running the demo, it is only necessary to trigger this pipeline, all other components of the demo are automatted.

The __TenantPipeline__ consists of four activities described below.

1. The __CleanupStagingTables__ stored procedure activity. This activity simply connects to the warehouse database and cleans up the staging tables and schema by calling the dbo.CleanupStagingSchema stored procedure. Everything here is hardcoded. If you are implementing your own stored procedure here, there only thing to really be aware of is that you typically want this activity to be idempotent. So if it runs, and there is nothing to cleanup, it still completes with success. Likewise, if it runs and does have to cleanup tables and schemas, it also completes with success.

2. The __TenantLookup__ lookup activity. This activity is responsible for pulling the list of tenants by running the ___SELECT * FROM TenantMetadata ORDER BY TenantPriority___ query in the warehouse databse. There is no parameterization in this activity but the output which will be passed on to the next activity is JSON formatted with the results of the query that will look something like this:  
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

3. The next activity is the __ForEachTenant__ ForEach activity. If you select this activity, then choose the __Settings__ tab, you will see that under __Items__ we have added dynamic content representing the output of the previous lookup activity. The value is ___@activity('TenantLookup').ouput.value___. If you delete this item, click in the empty field and choose the __Add dynamic content__ link you will get a popup showing you all of the accessible options for dynamic content. Choose the __TenantLookup value array__, which will give you the entire array of the results of the lookup. The ForEach activity will iterate through each element of the array.