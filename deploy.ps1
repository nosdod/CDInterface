#Requires -RunAsAdministrator

[CmdletBinding()] param(
    [switch]$clean = $false ,
    [switch]$cleanonly = $false 
)

$ver='1.0.2'
$dest="$env:ProgramFiles\WindowsPowerShell\Modules\CDInterfaceModule"
$location="$dest\$ver"

if ( $cleanonly -Or $clean ) {
    if (Test-Path -Path $location) {
        Remove-Item $location
        Write-Output "INFO : $location deleted"
    }
    if ( $cleanonly ) {
        return # All done
    }
}

if (Test-Path -Path $location) {
    "ERROR : Destination for this version ($location) already exists! (Add -clean to replace existing)"
    return
} elseif ( -Not { Test-Path -Path $dest } ) {
    mkdir $env:ProgramFiles\WindowsPowerShell\Modules\CDInterfaceModule
}

mkdir $location
Copy-Item .\CDInterfaceModule.psm1 $location
Copy-Item .\CDInterfaceModuleSettings.json $location
New-ModuleManifest -Path $location\CDInterfaceModule.psd1 -RootModule CDInterfaceModule -ModuleVersion $ver -Author 'Mark Dodson' -Description 'CDInterfaceModule' -CompanyName 'DodTech Ltd'