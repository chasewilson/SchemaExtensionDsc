Configuration LdfSchemaExtension_Example
{
    Import-DscResource PSDesiredStateConfiguration
    Import-DscResource SchemaExtensionDsc
    Node localhost
    {
        File AdSchemaTemplate
        {
        DestinationPath = 'C:\TestSchema.ldf'
        Ensure = 'Present'
        Contents = $SchemaContent
        Type = 'File'
        }

        LdfSchemaExtension TestExtension
        {
            ServerName    = localhost
            SchemaAdmin   = 'Administrator'
            AdminPassword = System.Security.SecureString
            DomainName    = 'Contoso.com'
            SchemaPath    = 'C:\TestSchema.ldf'
        }
    }
}