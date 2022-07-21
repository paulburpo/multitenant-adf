IF OBJECT_ID ( 'dbo.CleanupStagingSchema', 'P' ) IS NOT NULL
    DROP PROCEDURE dbo.CleanupStagingSchema;
GO	
CREATE PROCEDURE dbo.CleanupStagingSchema AS
SET NOCOUNT ON;

DECLARE @SQL        NVARCHAR(2000)
DECLARE @SchemaName NVARCHAR(100)
DECLARE @Counter    INT
DECLARE @TotalRows  INT

SET @SchemaName = 'Staging'
SET @Counter = 1

SET @SQL='
SELECT ''DROP TABLE '' + S.[Name] + ''.'' + O.[Name] AS DropTableStatement
FROM SYS.OBJECTS AS O INNER JOIN SYS.SCHEMAS AS S ON O.[schema_id] = S.[schema_id]
WHERE O.TYPE = ''U'' AND S.[Name] = ''' + @SchemaName + ''''

DROP TABLE IF EXISTS #DropStatements

CREATE TABLE #DropStatements
(
    ID                  INT IDENTITY (1, 1),
    DropTableStatement  VARCHAR(2000)
)

INSERT INTO #DropStatements
EXEC (@SQL)

SELECT @TotalRows = COUNT(ID) FROM #DropStatements

WHILE @Counter <= @TotalRows
BEGIN
    SELECT @SQL = DropTableStatement FROM #DropStatements WHERE ID = @Counter

    EXEC (@SQL)

    SET @Counter = @Counter + 1
END

SET @SQL = N'DROP SCHEMA IF EXISTS ' + @SchemaName
EXEC (@SQL)