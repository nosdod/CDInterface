CDInterfaceModule
This powershell script is a Powershell module. It is designed to be installed onto the target system
before being used. It contains one exposed Powershell CmdLet - CDInterface.

It can still be invoke from the command line in a Powershell session in the following way ...
From the directory where the file CDInterfaceModule.psm1 is located
Import-Module .\CDInterfaceModule.psm1
Then in the same session run
CDInterface <arguments>

To install the modules on your system, run deploy.ps1.
This 
1) Creates C:\Program Files\WindowsPowerShell\Modules\CDInterfaceModule\1.0.0
2) Copies the module file into a new directory.
3) Creates a module manifest.
Once the module has been installed in this way, you can just invoke CDInterface from a Powershell session

The examples below assumes you have either installed or imported the module

To view all options available

CDInterface -help

This will display all the options available for the CmdLet.

To copy the contents of a specified directory to writeable media

CDInterface -writetomedia C:\Users\Mark\Documents -cdlabel MyBackup

To get the drive letter

CDInterface -driveletter

To get the drive status

CDInterface -getdrivestate

To get the module version

CDInterface -version

To list available drives

CDInterface -list

Add the -verbose option to any command to see more info on the scripts actions
Other options and commands are documented in the help page.

Mark Dodson
11/10/2021
