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
    [string]
    $SchemaAdmin,

    [parameter(Mandatory = $true)]
    [string]
    $SchemaPassword
)

$securePassword = ConvertTo-SecureString $AdminPassword -AsPlainText -Force
$schemaCredential = New-Object System.Management.Automation.PSCredential ($AdminUsername, $securePassword)

Configuration Sample_LdfSchemaExtension
{
    Import-DscResource SchemaExtensionDsc
    
    Node TargetName
    {
        LdfSchemaExtension TestExtension
        {
            SchemaPath = $SchemaPath
            DistinguishedName = $DistinguishedName
            PsDscRunAsCredential = $schemaCredential
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
