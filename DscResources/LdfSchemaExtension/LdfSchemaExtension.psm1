Import-Module -Name (Join-Path -Path ( Split-Path $PSScriptRoot -Parent ) `
                               -ChildPath 'SchemaExtensionResourceHelper\LdfSchemaExtensionHelper.psm1') `
                               -Force

Function Get-TargetResource
{
    [CmdletBinding()]
    [OutputType([Hashtable])]
    param
    (
        [parameter(Mandatory = $true)]
        [string]
        $ServerName,

        [parameter(Mandatory = $true)]
        [string]
        $SchemaAdmin,

        [parameter(Mandatory = $true)]
        [string]
        $AdminPassword,

        [parameter(Mandatory = $true)]
        [string]
        $DomainName,

        [parameter(Mandatory = $true)]
        [string]
        $SchemaPath
    )

    $schemaTemplate = Get-Content -Path $SchemaPath
    $schemaConfig = (Get-ADRootDSE).SchemaNamingContext
    $schemaObjects = Get-ADObject -Filter * -SearchBase $schemaConfig -Properties *
    $getReturn = @{}

    foreach ($line in $schemaTemplate)
    {
        if ($line -match "^attributeID")
        {
            $attributeID = $line -split ":"
            $attributeID = $attributeID[1].Trim()
            $attributeObject = $using:schemaObjects | where {$_.attributeid -eq $attributeID}

            $getReturn += $attributeObject
        }
        if ($line -match "^governsID")
        {
            $governsId = $line -split ":"
            $governsId = $governsId[1].Trim()
            $governsObject = $using:schemaObjects | where {$_.governsID -eq $governsID}
            
            $getReturn += $governsObject
        }
    }

    return $getReturn
}

Function Test-TargetResource
{
    [CmdletBinding()]
    [OutputType([System.Boolean])]
    param
    (
        [parameter(Mandatory = $true)]
        [string]
        $ServerName,

        [parameter(Mandatory = $true)]
        [string]
        $SchemaAdmin,

        [parameter(Mandatory = $true)]
        [string]
        $AdminPassword,

        [parameter(Mandatory = $true)]
        [string]
        $DomainName,

        [parameter(Mandatory = $true)]
        [string]
        $SchemaPath
    )

    $inDesiredState = Test-SchemaExtension -SchemaPath $SchemaPath

    return $inDesiredState
}

Function Set-TargetResource
{
    [CmdletBinding()]
    param
    (
        [parameter(Mandatory = $true)]
        [string]
        $ServerName,

        [parameter(Mandatory = $true)]
        [string]
        $SchemaAdmin,

        [parameter(Mandatory = $true)]
        [string]
        $AdminPassword,

        [parameter(Mandatory = $true)]
        [string]
        $DomainName,

        [parameter(Mandatory = $true)]
        [string]
        $SchemaPath
    )

    if (Test-path $SchemaPath)
    {
        $encoding = Get-FileEncoding -FilePath $SchemaPath

        if ($encoding -ne 'ASCII')
        {
            ConvertTo-ASCII -FilePath $SchemaPath
        }
            $splitName = $DomainName -split '.'

            ldifde -i -f $SchemaPath -s $ServerName -c "{_UNIT_DN_}" "dc=$splitName[0],dc=$splitName[1]" -v -k -b $SchemaAdmin $DomainName $AdminPassword
    }
    else 
    {
        Write-Verbose -Message "Schema extension not found. Please Verify Path and .ldf existence"
    }
}