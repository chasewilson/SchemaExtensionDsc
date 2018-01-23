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
        $SchemaPath,

        [parameter(Mandatory = $true)]
        [string]
        $ServerName,

        [parameter(Mandatory = $true)]
        [string]
        $DistinguishedName
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
            $attributeObject = $schemaObjects | where {$_.attributeid -eq $attributeID}

            $getReturn += $attributeObject
        }
        if ($line -match "^governsID")
        {
            $governsId = $line -split ":"
            $governsId = $governsId[1].Trim()
            $governsObject = $schemaObjects | where {$_.governsID -eq $governsID}
            
            $getReturn += $governsObject
        }
    }

    $ReturnValue = @{
        SchemaPath = $Force
        ServerName = $inputPath
        DistinguishedName = $CimAccessControlList
        SchemaObjects = $schemaObjects
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
        $SchemaPath,

        [parameter(Mandatory = $true)]
        [string]
        $ServerName,

        [parameter(Mandatory = $true)]
        [string]
        $DistinguishedName
    )

    $inDesiredState = $true
    $schemaTemplate = Get-Content -Path $SchemaPath
    $schemaConfig = (Get-ADRootDSE).SchemaNamingContext
    $schemaObjects = Get-ADObject -Filter * -SearchBase $schemaConfig -Properties *

    foreach ($line in $schemaTemplate)
    {
        if ($line -match "^attributeID")
        {
            $attributeID = $line -split ":"
            $attributeID = $attributeID[1].Trim()
            $attributeObject = $schemaObjects | where {$_.attributeid -eq $attributeID}
            if ($null -eq $attributeObject)
            {
                Write-Verbose "$($attributeObject.adminDisplayname) does not exist in the AD Schema"
                $inDesiredState = $false
            }
            else
            {
                Write-Verbose "$($attributeObject.adminDisplayname) exists in the AD Schema"
            }
        }
        if ($line -match "^governsID")
        {
            $governsId = $line -split ":"
            $governsId = $governsId[1].Trim()
            $governsObject = $schemaObjects | where {$_.governsID -eq $governsID}
            
            if ($null -eq $governsObject)
            {
                Write-Verbose "$($governsObject.adminDisplayname) does not exist in the AD Schema"
                
                $inDesiredState = $false
            }
            else
            {
                Write-Verbose "$($governsObject.adminDisplayname) exists in the AD Schema"
            }
        }
        if ($line -match "^mayContain")
        {
            $mayId = $line -split ":"
            $mayId = $mayId[1].Trim()
            
            if ($governsObject.mayContain -match $mayId)
            {                            
                Write-Verbose "$mayId exists in $($governsObject.ldapDisplayName)"
            }
            else
            {
                Write-Verbose "$mayId does not exist in $($governsObject.ldapDisplayName)"
                $inDesiredState = $false
            }
        }
    }
    return $inDesiredState
}

Function Set-TargetResource
{
    [CmdletBinding()]
    param
    (
        [parameter(Mandatory = $true)]
        [string]
        $SchemaPath,

        [parameter(Mandatory = $true)]
        [string]
        $ServerName,

        [parameter(Mandatory = $true)]
        [string]
        $DistinguishedName
    )

    if (Test-path $SchemaPath)
    {
        $encoding = Get-FileEncoding -FilePath $SchemaPath

        if ($encoding -ne 'ASCII')
        {
            ConvertTo-ASCII -FilePath $SchemaPath
        }

        ldifde -i -f $SchemaPath -s $ServerName -c "{_UNIT_DN_}" "$($DistinguishedName)" -v -k 
    }
    else 
    {
        Write-Verbose -Message "Schema extension not found. Please Verify Path and .ldf existence"
    }
}