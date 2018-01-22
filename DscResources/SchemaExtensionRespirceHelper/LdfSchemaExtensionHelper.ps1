<#
.SYNOPSIS
    Gets file encoding.

.DESCRIPTION
    The Get-FileEncoding function determines encoding by looking at Byte Order Mark (BOM).
    Based on port of C# code from http://www.west-wind.com/Weblog/posts/197245.aspx

.EXAMPLE
    In this example, the function gets the file encoding of the test file

        Get-FileEncoding -FilePath 'C:\Test.txt'
#>
function Get-FileEncoding
{
    [CmdletBinding()] 
    Param 
    (
        [Parameter(Mandatory = $True)] 
        [string]
        $FilePath
    )
 
    [byte[]]$byte = get-content -Encoding byte -ReadCount 4 -TotalCount 4 -Path $FilePath
    
    if ( $byte[0] -eq 0xef -and $byte[1] -eq 0xbb -and $byte[2] -eq 0xbf )
    { 
        Write-Output 'UTF8' 
    }
    elseif ($byte[0] -eq 0xfe -and $byte[1] -eq 0xff)
    { 
        Write-Output 'Unicode UTF-16 Big-Endian' 
    }
    elseif ($byte[0] -eq 0xff -and $byte[1] -eq 0xfe)
    { 
        Write-Output 'Unicode UTF-16 Little-Endian' 
    }
    elseif ($byte[0] -eq 0 -and $byte[1] -eq 0 -and $byte[2] -eq 0xfe -and $byte[3] -eq 0xff)
    { 
        Write-Output 'UTF32 Big-Endian'
    }
    elseif ($byte[0] -eq 0xfe -and $byte[1] -eq 0xff -and $byte[2] -eq 0 -and $byte[3] -eq 0)
    { 
        Write-Output 'UTF32 Little-Endian' 
    }
    elseif ($byte[0] -eq 0x2b -and $byte[1] -eq 0x2f -and $byte[2] -eq 0x76 -and ($byte[3] -eq 0x38 -or $byte[3] -eq 0x39 -or $byte[3] -eq 0x2b -or $byte[3] -eq 0x2f) )
    { 
        Write-Output 'UTF7'
    }
    elseif ( $byte[0] -eq 0xf7 -and $byte[1] -eq 0x64 -and $byte[2] -eq 0x4c )
    { 
        Write-Output 'UTF-1' 
    }
    elseif ($byte[0] -eq 0xdd -and $byte[1] -eq 0x73 -and $byte[2] -eq 0x66 -and $byte[3] -eq 0x73)
    { 
        Write-Output 'UTF-EBCDIC' 
    }
    elseif ( $byte[0] -eq 0x0e -and $byte[1] -eq 0xfe -and $byte[2] -eq 0xff )
    { 
        Write-Output 'SCSU' 
    }
    elseif ( $byte[0] -eq 0xfb -and $byte[1] -eq 0xee -and $byte[2] -eq 0x28 )
    { 
        Write-Output 'BOCU-1' 
    }
    elseif ($byte[0] -eq 0x84 -and $byte[1] -eq 0x31 -and $byte[2] -eq 0x95 -and $byte[3] -eq 0x33)
    { 
        Write-Output 'GB-18030' 
    }
    else
    { 
        Write-Output 'ASCII' 
    }
} 

<#
.SYNOPSIS
    Converts file encoding from Unicode to ASCII.

.PARAMETER FilePath
    The path of the file to be converted to ASCII.

.EXAMPLE
    In this example, the test file is being converted to ASCII.

        ConvertTo-ASCII -FilePath "C:\Test.txt"
#>
function ConvertTo-ASCII
{
    [CmdletBinding()]
    param
    (
        [parameter(Mandatory = $true)]
        [string]
        $FilePath
    )

    $fileContent = Get-Content -Path $FilePath -Encoding 'Unicode' -Raw

    [System.IO.File]::WriteAllText($FilePath, $fileContent, [System.Text.Encoding]::ASCII)
} 

Function Test-SchemaExtension
{
    [CmdletBinding()]
    [OutputType([System.Boolean])]
    param
    (
        [parameter(Mandatory = $true)]
        [string]
        $SchemaPath
    )

    $returnValue = $true
    $schemaTemplate = Get-Content -Path $SchemaPath
    $schemaConfig = (Get-ADRootDSE).SchemaNamingContext
    $schemaObjects = Get-ADObject -Filter * -SearchBase $schemaConfig -Properties

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
                $returnValue = $false
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
                
                $returnValue = $false
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
                $returnValue = $false
            }
        }
    }
    return $returnValue
}
