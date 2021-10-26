#Requires -RunAsAdministrator

[CmdletBinding()] param(
    [switch]$clean = $false ,
    [switch]$cleanonly = $false,
    [switch]$cleanall = $false ,
    [switch]$cleanallonly = $false 
)

$ver='1.0.4'
$dest="$env:ProgramFiles\WindowsPowerShell\Modules\CDInterfaceModule"
$location="$dest\$ver"

if ( $cleanall -Or $cleanallonly) {
    if (Test-Path -Path $dest) {
        Remove-Item $dest
        Write-Output "INFO : $dest deleted"
    }
    if ( $cleanallonly ) {
        return # All done
    }
} elseif ( $cleanonly -Or $clean) {
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

# Create the eventlog, if it doesn't exist
try {
    $eventlog = New-EventLog -LogName Application -Source "CDInterface" -ErrorAction Stop
    Write-Output "CDInterface Application log created"
} catch {
    Write-Output "CDInterface Application log already exists"
}

$user = Get-WMIObject -class Win32_ComputerSystem | Select UserName
Write-EventLog -LogName "Application" -Source "CDInterface" -EntryType Information -EventID 2 -Message "CDInterface $ver Deployed by $($user.UserName)"

mkdir $location
Copy-Item .\CDInterfaceModule.psm1 $location
Copy-Item .\CDInterfaceModuleSettings.json $location
New-ModuleManifest -Path $location\CDInterfaceModule.psd1 -RootModule CDInterfaceModule -ModuleVersion $ver -Author 'Mark Dodson' -Description 'CDInterfaceModule' -CompanyName 'DodTech Ltd'