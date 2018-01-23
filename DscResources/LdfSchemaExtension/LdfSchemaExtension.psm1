Import-Module -Name (Join-Path -Path ( Split-Path $PSScriptRoot -Parent ) `
                               -ChildPath 'SchemaExtensionResourceHelper\LdfSchemaExtensionHelper.psm1') `
                               -Force

# Localized messages
data LocalizedData
{
    # culture="en-US"
    ConvertFrom-StringData -StringData @'
        ErrorPathNotFound = The requested path "{0}" cannot be found.
        ExtensionAttributeIdNotFound = Error obtaining Schema Extension Object with attribute id "{0}"
        ExtensionGovernsIdNotFound = Error obtaining Schema Extension Object with governs id "{0}"
        ExtensionObjectFound = Obtained "{0}" Schema Extension Object
        DistinguishedName = Configuration Distinguished Name "{0}" does not match current Domain Distinguished Name "{1}"
        MayContainfound = Obtained "{0}" in "{1}"
        MayContainNotFound = "{0}" was not found in specified Schema Object
        AsciiConversion = Converting Schema .ldf to ASCII format
        FileEncoding = Getting the Schema .ldf encoding
        ldifde = Setting schema extension.
'@
}

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
        $DistinguishedName
    )

    if (Test-Path $SchemaPath)
    {
        $schemaTemplate = Get-Content -Path $SchemaPath
        $schemaConfig = (Get-ADRootDSE).SchemaNamingContext
        $schemaObjects = Get-ADObject -Filter * -SearchBase $schemaConfig -Properties *
        $ObjectReturn = @{}

        # .ldf file is passed to PS as an aray of strings
        foreach ($line in $schemaTemplate)
        {
            if ($line -match "^attributeID")
            {
                $attributeId = $line -split ":"
                $attributeId = $attributeId[1].Trim()
                $attributeObject = $schemaObjects | where {$_.attributeId -eq $attributeId}

                if ($null -ne $attributeObject)
                {
                    $Message = $LocalizedData.ExtensionObjectFound -f $attributObject.adminDisplayName
                    Write-Verbose -Message $Message

                    $ObjectReturn += $attributeObject
                }
                else 
                {
                    $Message = $LocalizedData.ExtensionAttributeIdNotFound -f $attributeId
                    Write-Verbose -Message $Message
                }
            }
            elseif ($line -match "^governsID")
            {
                $governsId = $line -split ":"
                $governsId = $governsId[1].Trim()
                $governsObject = $schemaObjects | where {$_.governsID -eq $governsId}

                if($null -ne $governsObject)
                {
                    $Message = $LocalizedData.ExtensionObjectFound -f $governsObject.adminDisplayName
                    Write-Verbose -Message $Message

                    $ObjectReturn += $governsObject
                }
                else 
                {
                    $Message = $LocalizedData.ExtensionGovernsIdNotFound -f $governsId
                    Write-Verbose -Message $Message
                }
            }
        }
    }
    else
    {
        $Message = $LocalizedData.ErrorPathNotFound -f $SchemaPath
        Write-Verbose -Message $Message
    }

    $currentDomain = (Get-ADDomain).DistinguishedName

    if($DistinguishedName -ne $currentDomain)
    {
        $message = $LocalizedData.DistinguishedName -f $DistinguishedName, $currentDomain
        Write-Verbose -Message $Message
    }

    $ReturnValue = @{
        SchemaPath = $SchemaPath
        DistinguishedName = $DistinguishedName
        SchemaObjects = $ObjectReturn
    }

    return $ReturnValue
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
            $attributeId = $line -split ":"
            $attributeId = $attributeId[1].Trim()
            $attributeObject = $schemaObjects | where {$_.attributeId -eq $attributeId}
            if ($null -ne $attributeObject)
            {
                $Message = $LocalizedData.ExtensionObjectFound -f $attributeObject.adminDisplayName
                Write-Verbose -Message $Message
            }
            else
            {
                $Message = $LocalizedData.ExtensionAttributeIdNotFound -f $attributeId
                Write-Verbose -Message $Message

                $inDesiredState = $false
            }
        }
        elseif ($line -match "^governsID")
        {
            $governsId = $line -split ":"
            $governsId = $governsId[1].Trim()
            $governsObject = $schemaObjects | where {$_.governsID -eq $governsID}
            
            if ($null -ne $governsObject)
            {
                $Message = $LocalizedData.ExtensionObjectFound -f $governsObject.adminDisplayName
                Write-Verbose -Message $Message
            }
            else
            {
                $Message = $LocalizedData.ExtensionGovernsIdNotFound -f $governsId
                Write-Verbose -Message $Message
                
                $inDesiredState = $false
            }
        }
        elseif ($line -match "^mayContain")
        {
            $mayId = $line -split ":"
            $mayId = $mayId[1].Trim()
            
            if ($governsObject.mayContain -match $mayId)
            {
                $governsName = $governsObject.ldapDisplayName

                $Message = $LocalizedData.MayContainFound -f $mayId, $governsName
                Write-Verbose -Message $Message                         
            }
            else
            {
                $Message = $LocalizedData.MayContainNotFound -f $mayId
                Write-Verbose -Message $Message

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
        $DistinguishedName
    )

    if (Test-path $SchemaPath)
    {
        $Message = $LocalizedData.FileEncoding
        Write-Verbose -Message $Message

        $encoding = Get-FileEncoding -FilePath $SchemaPath

        if ($encoding -ne 'ASCII')
        {
            $Message = $LocalizedData.AsciiConversion
            Write-Verbose -Message $Message

            ConvertTo-ASCII -FilePath $SchemaPath
        }

        $Message = $LocalizedData.ldifde
        Write-Verbose -Message $Message

        ldifde -i -f $SchemaPath -s $env:COMPUTERNAME -c "{_UNIT_DN_}" "$($DistinguishedName)" -v -k 
    }
    else 
    {
        $Message = $LocalizedData.ErrorPathNotFound -f $SchemaPath
        Write-Verbose -Message $Message
    }
}
