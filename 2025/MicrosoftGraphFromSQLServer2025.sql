--EXEC sp_configure 'show advanced options', 1;
--RECONFIGURE;

--EXEC sp_configure 'external rest endpoint enabled', 1;
--RECONFIGURE;

SET NOCOUNT ON;

DECLARE
    @ClientId VARCHAR(36) = '', -- Replace with your Application ClientId
    @ClientSecret VARCHAR(40) = '', -- Replace with your Application Client Secret Value
    @TenantId VARCHAR(36) = '', -- Replace with your Tenant Id
    @TokenURL VARCHAR(200),
    @TokenAPIResponse NVARCHAR(MAX),
    @Token NVARCHAR(MAX),
    @APIResponse NVARCHAR(MAX);

SET @TokenURL = 'https://login.microsoftonline.com/' + @TenantId + '/oauth2/v2.0/token';
DECLARE @TokenPayload NVARCHAR(MAX) = N'client_id=' + @ClientId + N'&scope=https%3A%2F%2Fgraph.microsoft.com%2F.default&client_secret=' + @ClientSecret + N'&grant_type=client_credentials';

--Get Token
EXEC msdb.dbo.sp_invoke_external_rest_endpoint
    @url = @TokenURL,
    @method = N'GET',
    @headers = N'{"Content-Type":"application/x-www-form-urlencoded"}',
    @payload = @TokenPayload,
    @response = @TokenAPIResponse OUTPUT;

SELECT
    @Token = JSON_VALUE(@TokenAPIResponse, '$.result.access_token');
SELECT
    @Token AS Token;

DECLARE
    @Url NVARCHAR(1000),
    @HeaderValues NVARCHAR(MAX),
    @APIResult NVARCHAR(MAX);

SET @Url = N'https://graph.microsoft.com/v1.0/users';
SET @HeaderValues = N'{"Content-Type": "application/x-www-form-urlencoded", "Authorization": "Bearer ' + @Token + N'" }';

--Call Microsoft Graph API
EXEC msdb.dbo.sp_invoke_external_rest_endpoint
    @url = @Url,
    @method = N'GET',
    @headers = @HeaderValues,
    @response = @APIResponse OUTPUT;

SELECT
    @APIResponse AS APIResponse;

SELECT
    @APIResult = Value
FROM
    OPENJSON(@APIResponse, '$.result')
WHERE
    [Key] = 'value';

SELECT
    @APIResult AS APIResult;
