param
(
    [parameter(Mandatory = $true)]
    [string]
    $TargetName,

    [parameter(Mandatory = $true)]
    [string]
    $OutputPath,

    [parameter(Mandatory = $true)]
    [string]
    $SchemaPath,

    [parameter(Mandatory = $true)]
    [string]
    $DistinguishedName,

    [parameter(Mandatory = $true)]
    [pscredential]
    $SchemaCredential
)


Configuration Sample_LdfSchemaExtension
{
    Import-DscResource SchemaExtensionDsc
    
    Node $TargetName
    {
        LdfSchemaExtension TestExtension
        {
            SchemaPath = $SchemaPath
            DistinguishedName = $DistinguishedName
            PsDscRunAsCredential = $SchemaCredential
        }
    }
}

$ConfigData = @{
    AllNodes = @(
        @{
            NodeName = '*'
            PSDscAllowDomainUser = $true
        }
    )
}

$null = Sample_LdfSchemaExtension -OutputPath $OutputPath -ConfigurationData $configData
