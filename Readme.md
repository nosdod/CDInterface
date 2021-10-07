CDInterface
This powershell script can be invoke from the command line in a Powershell session.
No installation is required, just copy the file and run it.

Example
.\CDInterface.ps1 -help
This will display all the options available for the script.

To copy the contents of a specified directory to writeable media
.\CDInterface.ps1 -writetomedia C:\Users\Mark\Documents -cdlabel MyBackup

Tp get the drive letter
.\CDInterface.ps1 -driveletter

To get the drive status
.\CDInterface.ps1 -getdrivestate

Tp get the script version
.\CDInterface.ps1 -version

Tp list available drives
.\CDInterface.ps1 -list

Add the -verbose option to any command to see more info on the scripts actions
Other options and commands are documented in the Usage output in the help page.

Mark Dodson
07/10/2021