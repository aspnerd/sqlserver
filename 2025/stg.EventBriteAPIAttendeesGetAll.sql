CREATE PROCEDURE stg.EventBriteAPIAttendeesGetAll
    (
        @EventID NVARCHAR(50) = N'',-- Replace with your Eventbrite Event ID
        @Token NVARCHAR(100) = N'', -- Replace with your EventBrike API token
        @Debug BIT = 0
    )
AS
    BEGIN
        SET NOCOUNT ON;

        --Don't forget to execute this first before executing the stored procedure.

        --EXEC sp_configure 'show advanced options', 1;
        --RECONFIGURE;

        --EXEC sp_configure 'external rest endpoint enabled', 1;
        --RECONFIGURE;

        IF OBJECT_ID('stg.EventBriteAPIImport', 'U') IS NULL
            BEGIN
                CREATE TABLE stg.EventBriteAPIImport
                    (
                        ContinuationToken VARCHAR(20) NULL,
                        HasMoreItems BIT NOT NULL,
                        APIResponse NVARCHAR(MAX) NULL,
                        JSONAttendees NVARCHAR(MAX) NULL,
                        RetrievedAt DATETIME2(0) NOT NULL CONSTRAINT [DF_EventBriteAPIImport_RetrievedAt] DEFAULT (GETDATE()),
                        StartDatetime DATETIME2(0) NOT NULL
                    );
            END;

        DECLARE
            @Url NVARCHAR(1000),
            @ContinuationToken VARCHAR(20) = NULL,
            @StartDatetime DATETIME2(0) = GETDATE();

        WHILE 1 = 1
            BEGIN
                SET @Url = N'https://www.eventbriteapi.com/v3/events/' + @EventID + N'/attendees/?token=' + @Token;
                IF @ContinuationToken IS NOT NULL
                    SET @Url += N'&continuation=' + @ContinuationToken;

                IF (@Debug = 1)
                    BEGIN
                        PRINT 'Calling URL: ' + @Url;
                    END;

                DECLARE
                    @APIResponse NVARCHAR(MAX),
                    @ResultAttendees AS NVARCHAR(MAX),
                    @HasMoreItems BIT;

                EXEC msdb.dbo.sp_invoke_external_rest_endpoint
                    @url = @Url,
                    @method = N'GET',
                    @headers = N'{"Content-Type":"application/json"}',
                    @response = @APIResponse OUTPUT;

                SELECT
                    @ContinuationToken = JSON_VALUE(@APIResponse, '$.result.pagination.continuation'),
                    @HasMoreItems = CAST(JSON_VALUE(@APIResponse, '$.result.pagination.has_more_items') AS BIT);

                SELECT
                    @ResultAttendees = Value
                FROM
                    OPENJSON(@APIResponse, '$.result')
                WHERE
                    [Key] = 'attendees';

                INSERT INTO
                    stg.EventBriteAPIImport
                    (ContinuationToken, HasMoreItems, APIResponse, JSONAttendees, StartDatetime)
                SELECT
                    @ContinuationToken,
                    @HasMoreItems,
                    @APIResponse,
                    @ResultAttendees,
                    @StartDatetime;

                IF (@Debug = 1)
                    BEGIN
                        SELECT
                            JSON_VALUE(@APIResponse, '$.result') AS ResultValue,
                            JSON_VALUE(@APIResponse, '$.result.pagination.has_more_items') AS HasMoreItems,
                            JSON_VALUE(@APIResponse, '$.result.pagination.continuation') AS ContinuationVar,
                            JSON_VALUE(@APIResponse, '$.result.pagination.object_count') AS object_count,
                            JSON_VALUE(@APIResponse, '$.result.pagination.page_number') AS page_number,
                            JSON_VALUE(@APIResponse, '$.result.pagination.page_size') AS page_size,
                            JSON_VALUE(@APIResponse, '$.result.pagination.page_count') AS page_count,
                            @HasMoreItems AS HasMoreItemsVariable,
                            @ContinuationToken AS ContinuationVarVariable,
                            @ResultAttendees AS ResultAttendees;
                    END;

                IF (@HasMoreItems = 0)
                    BEGIN
                        IF (@Debug = 1)
                            BEGIN
                                PRINT 'No more items found. Ending loop.';
                            END;
                        BREAK;
                    END;
                ELSE
                    BEGIN
                        IF (@Debug = 1)
                            BEGIN
                                PRINT 'Next continuation token: ' + @ContinuationToken;
                            END;
                    END;
            END;
    END;
