### The two connection strings should look something like the following but without the quotes...

__TenantDatabases_connectionString =__ "integrated security=False;encrypt=True;connection timeout=30;data source=@{linkedService().ServerName};initial catalog=@{linkedService().DatabaseName};user id=dblogin"

__warehouse_connectionString =__ "integrated security=False;encrypt=True;connection timeout=30;data source=db-host.database.windows.net;initial catalog=warehouse-multi-tenant;user id=warehouselogin"
