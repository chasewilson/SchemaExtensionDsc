# Examples

To run the example you must do the following:

1. Go in the examples folder
   1. `cd Examples`
1. Add this repo to your psModulePath
    1. ```powershell
        $path = Split-Path $PWD -Parent
        if ($env:PSModulePath -notlike "*$path*") {
            $env:PSModulePath = $env:PSModulePath + "$([System.IO.Path]::PathSeparator)$path";
        }
        ```
1. Run the sample
    1. `.\Sample_LdfSchemaExtension.ps1`
