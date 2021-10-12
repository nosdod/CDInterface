#Requires -RunAsAdministrator

[CmdletBinding()] param(
    [switch]$clean = $false 
)

$ver='1.0.0'
$dest="$env:ProgramFiles\WindowsPowerShell\Modules\CDInterfaceModule"
$location="$dest\$ver"

if ( $clean ) {
    if (Test-Path -Path $location) {
        Remove-Item $location
        Write-Output "INFO : $location deleted"
    }
    return # All done
}

if (Test-Path -Path $location) {
    "ERROR : Destination for this version ($location) already exists! (Delete first to replace)"
    return
} elseif ( -Not { Test-Path -Path $dest } ) {
    mkdir $env:ProgramFiles\WindowsPowerShell\Modules\CDInterfaceModule
}

mkdir $location
Copy-Item .\CDInterfaceModule.psm1 $location
New-ModuleManifest -Path $location\CDInterfaceModule.psd1 -RootModule CDInterfaceModule -ModuleVersion $ver -Author 'Mark Dodson' -Description 'CDInterfaceModule' -CompanyName 'DodTech Ltd'