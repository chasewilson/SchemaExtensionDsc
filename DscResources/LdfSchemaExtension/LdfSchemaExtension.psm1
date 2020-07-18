Import-Module -Name (Join-Path -Path ( Split-Path $PSScriptRoot -Parent ) `
        -ChildPath 'SchemaExtensionResourceHelper\LdfSchemaExtensionHelper.psm1') `
    -Force

# Localized messages for Write-Verbose statements in this resource
$script:localizedData = Get-LocalizedData -ResourceName 'LdfSchemaExtension'

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
        $DistinguishedName,
        [parameter(Mandatory = $false)]
        [string]
        $LdfPlaceholder = "{_UNIT_DN_}"
    )

    if (Test-Path $SchemaPath)
    {
        $schemaTemplate = Get-Content -Path $SchemaPath
        $schemaConfig = (Get-ADRootDSE).SchemaNamingContext
        $schemaObjects = Get-ADObject -Filter * -SearchBase $schemaConfig -Properties 'adminDisplayName', 'attributeID', 'governsId', 'mayContain'

        $namespace = "root/Microsoft/Windows/DesiredStateConfiguration"
        $cimSchemaObjects = New-Object -TypeName 'System.Collections.ObjectModel.Collection`1[Microsoft.Management.Infrastructure.CimInstance]'


        # .ldf file is passed to PS as an aray of strings
        foreach ($line in $schemaTemplate)
        {
            if ($line -match "^attributeID")
            {
                $attributeId = $line -split ":"
                $attributeId = $attributeId[1].Trim()
                $currentSchemaObject = $schemaObjects | Where-Object { $_.attributeId -eq $attributeId }

                if ($null -ne $currentSchemaObject)
                {
                    Write-Verbose -Message ($localizedData.ExtensionObjectFound -f $currentSchemaObject.adminDisplayName)

                    $currentId = $currentSchemaObject.attributeId
                }
                else
                {
                    Write-Verbose -Message ($localizedData.ExtensionAttributeIdNotFound -f $attributeId)
                }
            }
            elseif ($line -match "^governsID")
            {
                $governsId = $line -split ":"
                $governsId = $governsId[1].Trim()
                $currentSchemaObject = $schemaObjects | Where-Object { $_.governsID -eq $governsId }

                if ($null -ne $currentSchemaObject)
                {
                    Write-Verbose -Message ($localizedData.ExtensionObjectFound -f $currentSchemaObject.adminDisplayName)

                    $currentId = $currentSchemaObject.governsId
                }
                else
                {
                    Write-Verbose -Message ($localizedData.ExtensionGovernsIdNotFound -f $governsId)
                }
            }
            if ($null -ne $currentSchemaObject)
            {
                $cimSchemaObjects += New-CimInstance -ClientOnly -Namespace $namespace -ClassName SchemaObject -Property @{
                    AdminDisplayName  = $currentSchemaObject.adminDisplayname
                    AttributeId       = $currentId
                    DistinguishedName = $currentSchemaObject.distinguishedName
                    Name              = $currentSchemaObject.name
                    ObjectGuid        = $currentSchemaObject.objectGuid.guid
                    ObjectClass       = $currentSchemaObject.objectClass
                }
            }
        }
    }
    else
    {
        Write-Verbose -Message ($localizedData.ErrorPathNotFound -f $SchemaPath)
    }

    $currentDomain = (Get-ADDomain).DistinguishedName

    if ($DistinguishedName -ne $currentDomain)
    {
        Write-Verbose -Message ($localizedData.DistinguishedName -f $DistinguishedName, $currentDomain)
    }

    $schemaObject = [Microsoft.Management.Infrastructure.CimInstance[]]@($cimSchemaObjects)

    $returnValue = @{
        SchemaPath        = $SchemaPath
        DistinguishedName = $DistinguishedName
        SchemaObject      = $schemaObject
    }

    return $returnValue
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
        $DistinguishedName,
        [parameter(Mandatory = $false)]
        [string]
        $LdfPlaceholder = "{_UNIT_DN_}"
    )

    $inDesiredState = $true
    $schemaTemplate = Get-Content -Path $SchemaPath
    $schemaConfig = (Get-ADRootDSE).SchemaNamingContext
    $schemaObjects = Get-ADObject -Filter * -SearchBase $schemaConfig -Properties 'adminDisplayName', 'attributeID', 'governsId', 'mayContain'

    foreach ($line in $schemaTemplate)
    {
        if ($line -match "^attributeID")
        {
            $attributeId = $line -split ":"
            $attributeId = $attributeId[1].Trim()
            $attributeObject = $schemaObjects | Where-Object -FilterScript { $_.attributeId -eq $attributeId }
            if ($null -ne $attributeObject)
            {
                Write-Verbose -Message ($localizedData.ExtensionObjectFound -f $attributeObject.adminDisplayName)
            }
            else
            {
                Write-Verbose -Message ($localizedData.ExtensionAttributeIdNotFound -f $attributeId)

                $inDesiredState = $false
            }
        }
        elseif ($line -match "^governsID")
        {
            $governsId = $line -split ":"
            $governsId = $governsId[1].Trim()
            $governsObject = $schemaObjects | Where-Object -FilterScript { $_.governsID -eq $governsID }

            if ($null -ne $governsObject)
            {
                Write-Verbose -Message ($localizedData.ExtensionObjectFound -f $governsObject.adminDisplayName)
            }
            else
            {
                Write-Verbose -Message ($localizedData.ExtensionGovernsIdNotFound -f $governsId)

                $inDesiredState = $false
            }
        }
        elseif ($line -match "^mayContain")
        {
            $mayId = $line -split ":"
            $mayId = $mayId[1].Trim()

            if ($governsObject.mayContain -match $mayId)
            {
                $governsName = $governsObject.Name

                Write-Verbose -Message ($localizedData.MayContainFound -f $mayId, $governsName)
            }
            else
            {
                Write-Verbose -Message ($localizedData.MayContainNotFound -f $mayId)

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
        $DistinguishedName,
        [parameter(Mandatory = $false)]
        [string]
        $LdfPlaceholder = "{_UNIT_DN_}"
    )

    if (Test-path $SchemaPath)
    {
        Write-Verbose -Message $localizedData.FileEncoding

        $encoding = Get-FileEncoding -FilePath $SchemaPath

        if ($encoding -ne 'ASCII')
        {
            Write-Verbose -Message ($localizedData.AsciiConversion)

            ConvertTo-ASCII -FilePath $SchemaPath
        }

        Write-Verbose -Message $localizedData.ldifde

        start-process -FilePath ldifde.exe -ArgumentList "-i -f $SchemaPath -s $env:COMPUTERNAME -c `"$LdfPlaceholder`" $DistinguishedName -v -k " -Wait -NoNewWindow

        $ldifdeError = Get-Content -Path $env:TEMP\ldif.err -ErrorAction SilentlyContinue

        if ($null -ne $ldifdeError)
        {
            Write-Verbose -Message ($localizedData.ldifdeErrorLog -f $ldifdeError)
        }
    }
    else
    {
        Write-Verbose -Message $localizedData.ErrorPathNotFound -f $SchemaPath
    }
}
