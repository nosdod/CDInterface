BeforeAll {
    # Make sure no other versions of the module are loaded
    Get-Module CDInterfaceModule | Remove-Module

    # Make sure we have the local version loaded
    Import-Module $PSScriptRoot\CDInterfaceModule.psm1

    # Common Mocks define here
    class fake_Get_ChildItem {
        [string] $Fullname = "ADirectory"
        [int] $length = 100000000
    }

    $0discMasterMock = New-Module -AsCustomObject -ScriptBlock {
        [int] $Count = 0
        function Item ($ind) {
            return ""
        }
        Export-ModuleMember -Variable * -Function *
    }

    $1discMasterMock = New-Module -AsCustomObject -ScriptBlock {
        [array] $drives = @("drive0")
        [int] $Count = 1
        function Item ($ind) {
            return $drives[$ind]
        }
        Export-ModuleMember -Variable * -Function *
    }

    # ImageStream object
    class fake_ImageStream {
    }

    # We create a fake IMAPI2.MsftDiscRecorder2 object to control its behaviour in the test
    class fake_IMAPI2_MsftDiscRecorder2 {
        [string] $VendorId = "AVendor"
        [string] $ProductId = "AMediaDrive"
        [string] $VolumePaths = "D:\"
        [void] InitializeDiscRecorder([string]$drive) {}
        [void] AcquireExclusiveAccess([bool]$flag,[string]$ClientName) {}
        [void] ReleaseExclusiveAccess() {}
        [void] EjectMedia() {}
    }

    # We create a fake IMAPI2.MsftDiscFormat2Data object to control its behaviour in the test
    class fake_IMAPI2_MsftDiscFormat2Data {
        [string] $Recorder = "drive0"
        [string] $ClientName = "AClientName"
        [bool] $ForceMediaToBeClosed = $true
        [int] $CurrentPhysicalMediaType = 2 # CDR
        [bool] IsCurrentMediaSupported([string]$recorder) { return $true }
        [bool] $MediaHeuristicallyBlank = $true
        [void] Write([fake_ImageStream]$ImageStream) {}
        [int] $TotalSectorsOnMedia = 359000
    }

    class fake_IMAPI2_MsftDiscFormat2Data_CDR_NOT_BLANK {
        [string] $Recorder = "drive0"
        [string] $ClientName = "AClientName"
        [bool] $ForceMediaToBeClosed = $true
        [int] $CurrentPhysicalMediaType = 2 # CDR
        [bool] IsCurrentMediaSupported([string]$recorder) { return $true }
        [bool] $MediaHeuristicallyBlank = $false
        [void] Write([fake_ImageStream]$ImageStream) {}
        [int] $TotalSectorsOnMedia = 359000
    }

    class fake_IMAPI2_MsftDiscFormat2Data_CDRW_NOT_BLANK {
        [string] $Recorder = "drive0"
        [string] $ClientName = "AClientName"
        [bool] $ForceMediaToBeClosed = $true
        [int] $CurrentPhysicalMediaType = 3 # CDRW
        [bool] IsCurrentMediaSupported([string]$recorder) { return $true }
        [bool] $MediaHeuristicallyBlank = $false
        [void] Write([fake_ImageStream]$ImageStream) {}
        [int] $TotalSectorsOnMedia = 359000
    }

    class fake_IMAPI2_MsftDiscFormat2Data_CDRW {
        [string] $Recorder = "drive0"
        [string] $ClientName = "AClientName"
        [bool] $ForceMediaToBeClosed = $true
        [int] $CurrentPhysicalMediaType = 3 # CDRW
        [bool] IsCurrentMediaSupported([string]$recorder) { return $true }
        [bool] $MediaHeuristicallyBlank = $true
        [void] Write([fake_ImageStream]$ImageStream) {}
        [int] $TotalSectorsOnMedia = 359000
    }

    # We create a fake IMAPI2.MsftDiscRecorder2 object to control its behaviour in the test
    class fake_IMAPI2FS_MsftFileSystemImage_Root {
        [void] AddTreeWithNamedStreams([string]$path,[bool] $writeflag) {}
    }

    class fake_IMAPI2FS_MsftFileSystemImage_Root_Exception {
        [void] AddTreeWithNamedStreams([string]$path,[bool] $writeflag) { Throw } # Simulate a path not found error
    }

    class fake_IMAPI2FS_MsftFileSystemImage_ResultImage {
        [fake_ImageStream] $ImageStream
    }

    class fake_IMAPI2FS_MsftFileSystemImage {
        [string] $FileSystemsToCreate
        [string] $VolumeName
        [string] $VolumePaths
        [fake_IMAPI2FS_MsftFileSystemImage_ResultImage] CreateResultImage() { return New-Object 'fake_IMAPI2FS_MsftFileSystemImage_ResultImage' }
        [fake_IMAPI2FS_MsftFileSystemImage_Root] $Root

        fake_IMAPI2FS_MsftFileSystemImage() {
            $this.Root = New-Object 'fake_IMAPI2FS_MsftFileSystemImage_Root'
        }
    }

    class fake_IMAPI2FS_MsftFileSystemImage_Exception {
        [string] $FileSystemsToCreate
        [string] $VolumeName
        [string] $VolumePaths
        [fake_IMAPI2FS_MsftFileSystemImage_ResultImage] CreateResultImage() { return New-Object 'fake_IMAPI2FS_MsftFileSystemImage_ResultImage' }
        [fake_IMAPI2FS_MsftFileSystemImage_Root] $Root

        fake_IMAPI2FS_MsftFileSystemImage() {
            $this.Root = New-Object 'fake_IMAPI2FS_MsftFileSystemImage_Root_Exception'
        }
    }

}

Describe 'Write-Response' {
    It 'Given no parameters, it outputs nothing' {
        InModuleScope CDInterfaceModule {
            $wr = Write-Response
            $wr.Count | Should -Be 0
        }
    }
    It 'Given a bad parameter, it outputs nothing' {
        InModuleScope CDInterfaceModule {
            $wr = Write-Response -failed
            $wr.Count | Should -Be 0
        }
    }
    It 'For an error response, it outputs 2 lines' {
        InModuleScope CDInterfaceModule {
            $wr = Write-Response -failure -message "Test output"
            $wr.Count | Should -Be 2
            $wr[0] | Should -Be "ERROR"
        }
    }
    It 'For an error response, first line should be ERROR' {
        InModuleScope CDInterfaceModule {
            $wr = Write-Response -failure -message "Test output"
            $wr[0] | Should -Be "ERROR"
        }
    }
    It 'For an error response, second line should be the given message' {
        InModuleScope CDInterfaceModule {
            $wr = Write-Response -failure -message "Test output"
            $wr[1] | Should -Be "Test output"
        }
    }
}

Describe 'Get-Usage' {
    It 'Given no parameters, it outputs usage text' {
        InModuleScope CDInterfaceModule {
            $gu = Get-Usage
            $gu.Count | Should -Not -Be 0 
        }
    }
}

Describe 'Get-Version' {
    It 'Given no parameters, it returns a version string' {
        InModuleScope CDInterfaceModule {
            $gv = Get-Version
            $gv | Should -Match '^[0-9][0-9]*\.[0-9][0-9]*\.[0-9][0-9]*'
        }
    }
}

Describe 'CDInterface' {
    It 'Given no parameters, it outputs usage text' {
        $cdi = CDInterface
        $cdi.Count | Should -Not -Be 0
    }
}

Describe 'CDInterface -list' {
    BeforeAll {
    }

    Context "A system with 2 drives" {
        It 'it should list 2 devices' {
            Mock -ModuleName CDInterfaceModule New-Object {
                return @("drive0","drive1") # Simulate a system with 2 drives
            } -ParameterFilter { $ComObject -eq "IMAPI2.MsftDiscMaster2" }

            # Mock the recorder object creation
            Mock -ModuleName CDInterfaceModule 'New-Object' { 
                New-Object 'fake_IMAPI2_MsftDiscRecorder2' 
            } -ParameterFilter { $ComObject -eq "IMAPI2.MsftDiscRecorder2" }

            $cdi = CDInterface -list
            $cdi.Count | Should -Be 2
            $cdi[0] | Should -Match "0 Device.*AVendor.*AMediaDrive.*D"
            $cdi[1] | Should -Match "1 Device.*AVendor.*AMediaDrive.*D"
        }
    }

    Context "A system with 1 drive" {
        It 'it should list 1 devices' {
            Mock -ModuleName CDInterfaceModule 'New-Object' {
                $1discMasterMock
            } -ParameterFilter { $ComObject -eq "IMAPI2.MsftDiscMaster2" }
            
            # Mock the recorder object creation
            Mock -ModuleName CDInterfaceModule 'New-Object' { 
                New-Object 'fake_IMAPI2_MsftDiscRecorder2' 
            } -ParameterFilter { $ComObject -eq "IMAPI2.MsftDiscRecorder2" }

            $cdi = CDInterface -list
            $cdi | Should -Match "0 Device.*AVendor.*AMediaDrive.*D"
        }
    }

    Context "A system with no drives" {
        It 'Given the list parameter, it should list 0 devices' {
            Mock -ModuleName CDInterfaceModule New-Object {
                $0discMasterMock # Simulate a system with 0 drives
            } -ParameterFilter { $ComObject -eq "IMAPI2.MsftDiscMaster2" }
            
            $cdi = CDInterface -list
            $cdi.Count | Should -Be 0
        }
    }
}

Describe 'CDInterface -getdrivestate PRODUCTION' {
    BeforeAll {
        # Mock the settings file - setting production mode
        Mock -ModuleName CDInterfaceModule Get-Content {
            $settings = 
                        @' 
                            {
                                "sizeOfSector" : 1800,
                                "driveDefault" : 0,
                                "mediaTypeForProduction" : 2,
                                "production" : true
                            }
'@ | Set-Content -Path TestDrive:\settings.json
            return Get-Content -Path TestDrive:\settings.json
        }
    }

    Context "Normal behaviour for a blank CDR loaded in production on a system with 1 drive" {

        It 'it should show cd is blank and output 2 lines' {
            # Mock the get Drives object creation
            Mock -ModuleName CDInterfaceModule 'New-Object' {
                $1discMasterMock # Simulate a system with 1 drive
            } -ParameterFilter { $ComObject -eq "IMAPI2.MsftDiscMaster2" }

            # Mock the recorder object creation
            Mock -ModuleName CDInterfaceModule 'New-Object' { 
                New-Object 'fake_IMAPI2_MsftDiscRecorder2' 
            } -ParameterFilter { $ComObject -eq "IMAPI2.MsftDiscRecorder2" }

            # Mock the formatter object
            Mock -ModuleName CDInterfaceModule 'New-Object' { 
                New-Object 'fake_IMAPI2_MsftDiscFormat2Data' 
            } -ParameterFilter { $ComObject -eq "IMAPI2.MsftDiscFormat2Data" }

            $cdi = CDInterface -getdrivestate
            $cdi.Count | Should -Be 2
            $cdi[0] | Should -Be "BLANK_CD"
        }
    }

    Context "Error behaviour CDR is not blank CDR in production on a system with 1 drive" {

        It 'it should show cd is not blank and output 2 lines' {
            # Mock the get Drives object creation
            Mock -ModuleName CDInterfaceModule 'New-Object' {
                $1discMasterMock # Simulate a system with 1 drive
            } -ParameterFilter { $ComObject -eq "IMAPI2.MsftDiscMaster2" }

            # Mock the recorder object creation
            Mock -ModuleName CDInterfaceModule 'New-Object' { 
                New-Object 'fake_IMAPI2_MsftDiscRecorder2' 
            } -ParameterFilter { $ComObject -eq "IMAPI2.MsftDiscRecorder2" }

            # Mock the formatter object
            Mock -ModuleName CDInterfaceModule 'New-Object' { 
                New-Object 'fake_IMAPI2_MsftDiscFormat2Data_CDR_NOT_BLANK' 
            } -ParameterFilter { $ComObject -eq "IMAPI2.MsftDiscFormat2Data" }

            $cdi = CDInterface -getdrivestate
            $cdi.Count | Should -Be 2
            $cdi[0] | Should -Be "NON_WRITEABLE_DISC"
        }
    }

    Context "Error behaviour Media loaded is not CDR in production on a system with 1 drive" {
        It 'it should show media is wrong type and output 2 lines' {
            # Mock the get Drives object creation
            Mock -ModuleName CDInterfaceModule 'New-Object' {
                $1discMasterMock # Simulate a system with 1 drive
            } -ParameterFilter { $ComObject -eq "IMAPI2.MsftDiscMaster2" }

            # Mock the recorder object creation
            Mock -ModuleName CDInterfaceModule 'New-Object' { 
                New-Object 'fake_IMAPI2_MsftDiscRecorder2' 
            } -ParameterFilter { $ComObject -eq "IMAPI2.MsftDiscRecorder2" }

            # Mock the formatter object
            Mock -ModuleName CDInterfaceModule 'New-Object' { 
                New-Object 'fake_IMAPI2_MsftDiscFormat2Data_CDRW' 
            } -ParameterFilter { $ComObject -eq "IMAPI2.MsftDiscFormat2Data" }

            $cdi = CDInterface -getdrivestate
            $cdi.Count | Should -Be 2
            $cdi[0] | Should -Be "INVALID_MEDIA"
        }
    }
}

Describe 'CDInterface -writetomedia <path> -cdlabel <label> PRODUCTION' {
    BeforeAll {
        # Mock the settings file - setting production mode
        Mock -ModuleName CDInterfaceModule Get-Content {
            $settings = 
                        @' 
                            {
                                "sizeOfSector" : 1800,
                                "driveDefault" : 0,
                                "mediaTypeForProduction" : 2,
                                "production" : true
                            }
'@ | Set-Content -Path TestDrive:\settings.json
            return Get-Content -Path TestDrive:\settings.json
        }
    }

    Context "Normal behaviour for a blank CDR loaded in production on a system with 1 drive" {
        It 'it should show that the write succeeded and output 2 lines' {
            # Mock the get Drives object creation
            Mock -ModuleName CDInterfaceModule 'New-Object' {
                $1discMasterMock # Simulate a system with 1 drive
            } -ParameterFilter { $ComObject -eq "IMAPI2.MsftDiscMaster2" }

            # Mock the recorder object creation
            Mock -ModuleName CDInterfaceModule 'New-Object' { 
                New-Object 'fake_IMAPI2_MsftDiscRecorder2' 
            } -ParameterFilter { $ComObject -eq "IMAPI2.MsftDiscRecorder2" }

            # Mock the formatter object
            Mock -ModuleName CDInterfaceModule 'New-Object' { 
                New-Object 'fake_IMAPI2_MsftDiscFormat2Data' 
            } -ParameterFilter { $ComObject -eq "IMAPI2.MsftDiscFormat2Data" }

            # Mock the file system object
            Mock -ModuleName CDInterfaceModule 'New-Object' { 
                New-Object 'fake_IMAPI2FS_MsftFileSystemImage' 
            } -ParameterFilter { $ComObject -eq "IMAPI2FS.MsftFileSystemImage" }

            # Mock the Get-ChildItem cmdlet
            Mock -ModuleName CDInterfaceModule 'Get-ChildItem' {
                New-Object 'fake_Get_ChildItem'
            }

            $cdi = CDInterface -writetomedia "C:\Users\Mark" -cdlabel "MyBackup"
            $cdi.Count | Should -Be 2
            $cdi[0] | Should -Be "WRITE_SUCCESS"
        }
    }
}

Describe 'CDInterface -writetomedia <path> -cdlabel <label> -production -verbose' {
    BeforeAll {
        # Mock the settings file - setting production mode
        Mock -ModuleName CDInterfaceModule Get-Content {
            $settings = 
                        @' 
                            {
                                "sizeOfSector" : 1800,
                                "driveDefault" : 0,
                                "mediaTypeForProduction" : 2,
                                "production" : true
                            }
'@ | Set-Content -Path TestDrive:\settings.json
            return Get-Content -Path TestDrive:\settings.json
        }
    }

    Context "Verbose behaviour for a blank CDR loaded in production on a system with 1 drive" {
    
        It 'it should show that the write succeeded and output 2 lines' {
            # Mock the get Drives object creation
            Mock -ModuleName CDInterfaceModule 'New-Object' {
                $1discMasterMock # Simulate a system with 1 drive
            } -ParameterFilter { $ComObject -eq "IMAPI2.MsftDiscMaster2" }

            # Mock the recorder object creation
            Mock -ModuleName CDInterfaceModule 'New-Object' { 
                New-Object 'fake_IMAPI2_MsftDiscRecorder2' 
            } -ParameterFilter { $ComObject -eq "IMAPI2.MsftDiscRecorder2" }

            # Mock the formatter object
            Mock -ModuleName CDInterfaceModule 'New-Object' { 
                New-Object 'fake_IMAPI2_MsftDiscFormat2Data' 
            } -ParameterFilter { $ComObject -eq "IMAPI2.MsftDiscFormat2Data" }

            # Mock the file system object
            Mock -ModuleName CDInterfaceModule 'New-Object' { 
                New-Object 'fake_IMAPI2FS_MsftFileSystemImage' 
            } -ParameterFilter { $ComObject -eq "IMAPI2FS.MsftFileSystemImage" }

            # Mock the Get-ChildItem cmdlet
            Mock -ModuleName CDInterfaceModule 'Get-ChildItem' {
                New-Object 'fake_Get_ChildItem'
            }

            $cdi = CDInterface -writetomedia "C:\Users\Mark" -cdlabel "MyBackup" -Verbose
            $cdi.Count | Should -Be 2
            $cdi[0] | Should -Be "WRITE_SUCCESS"
        }
    }
}

Describe 'CDInterface -writetomedia <path> -cdlabel <label> PRODUCTION error paths' {
    BeforeAll {
        # Mock the settings file - setting production mode
        Mock -ModuleName CDInterfaceModule Get-Content {
            $settings = 
                        @' 
                            {
                                "sizeOfSector" : 1800,
                                "driveDefault" : 0,
                                "mediaTypeForProduction" : 2,
                                "production" : true
                            }
'@ | Set-Content -Path TestDrive:\settings.json
            return Get-Content -Path TestDrive:\settings.json
        }
    }

    Context "Error behaviour CDR is not blank CDR in production on a system with 1 drive" {

        It 'it should show cd is not blank and output 2 lines' {
            # Mock the get Drives object creation
            Mock -ModuleName CDInterfaceModule 'New-Object' {
                $1discMasterMock # Simulate a system with 1 drive
            } -ParameterFilter { $ComObject -eq "IMAPI2.MsftDiscMaster2" }

            # Mock the recorder object creation
            Mock -ModuleName CDInterfaceModule 'New-Object' { 
                New-Object 'fake_IMAPI2_MsftDiscRecorder2' 
            } -ParameterFilter { $ComObject -eq "IMAPI2.MsftDiscRecorder2" }

            # Mock the formatter object
            Mock -ModuleName CDInterfaceModule 'New-Object' { 
                New-Object 'fake_IMAPI2_MsftDiscFormat2Data_CDR_NOT_BLANK' 
            } -ParameterFilter { $ComObject -eq "IMAPI2.MsftDiscFormat2Data" }

            # Mock the Get-ChildItem cmdlet
            Mock -ModuleName CDInterfaceModule 'Get-ChildItem' {
                New-Object 'fake_Get_ChildItem'
            }

            $cdi = CDInterface -writetomedia "C:\Users\Mark" -cdlabel "ALabel"
            $cdi.Count | Should -Be 2
            $cdi[0] | Should -Be "ERROR"
        }
    }

    Context "Specified path not found with a blank CDR loaded in production on a system with 1 drive" {
        It 'it should show that the write fails and describe why and output 2 lines' {
            # Mock the get Drives object creation
            Mock -ModuleName CDInterfaceModule 'New-Object' {
                $1discMasterMock # Simulate a system with 1 drive
            } -ParameterFilter { $ComObject -eq "IMAPI2.MsftDiscMaster2" }

            # Mock the recorder object creation
            Mock -ModuleName CDInterfaceModule 'New-Object' { 
                New-Object 'fake_IMAPI2_MsftDiscRecorder2' 
            } -ParameterFilter { $ComObject -eq "IMAPI2.MsftDiscRecorder2" }

            # Mock the formatter object
            Mock -ModuleName CDInterfaceModule 'New-Object' { 
                New-Object 'fake_IMAPI2_MsftDiscFormat2Data' 
            } -ParameterFilter { $ComObject -eq "IMAPI2.MsftDiscFormat2Data" }

            # Mock the file system object
            Mock -ModuleName CDInterfaceModule 'New-Object' { 
                New-Object 'fake_IMAPI2FS_MsftFileSystemImage' 
            } -ParameterFilter { $ComObject -eq "IMAPI2FS.MsftFileSystemImage" }

            # Mock the Get-ChildItem cmdlet
            Mock -ModuleName CDInterfaceModule 'Get-ChildItem' {
                Throw
            }

            $cdi = CDInterface -writetomedia "Invalid" -cdlabel "MyBackup"
            $cdi.Count | Should -Be 2
            $cdi[0] | Should -Be "ERROR"
            $cdi[1] | Should -Match "^Exception occurred accessing path"
        }
    }
}

Describe 'CDInterface -writetomedia PRODUCTION Invocation error handling' {
    BeforeAll {
        # Mock the settings file - setting production mode
        Mock -ModuleName CDInterfaceModule Get-Content {
            $settings = 
                        @' 
                            {
                                "sizeOfSector" : 1800,
                                "driveDefault" : 0,
                                "mediaTypeForProduction" : 2,
                                "production" : true
                            }
'@ | Set-Content -Path TestDrive:\settings.json
            return Get-Content -Path TestDrive:\settings.json
        }
    }

    Context "Error behaviour for missing cdlabel parameter in production on a system with 1 drive" {
        It 'it should show that the write failed and output 2 lines' {
            $cdi = CDInterface -writetomedia "C:\Users\Mark"
            $cdi.Count | Should -Be 2
            $cdi[0] | Should -Be "ERROR"
        }
    }

    # Some of the parameter handling is currently done by Powershell
    Context "Error behaviour for missing value on cdlabel parameter in production on a system with 1 drive" {
        It 'script terminates with explanatory text generated by Powershell' {
            { CDInterface -writetomedia "C:\Users\Mark" -cdlabel } | Should -Throw
        }
    }

    Context "Error behaviour for missing value on writetomedia parameter in production on a system with 1 drive" {
        It 'script terminates with explanatory text generated by Powershell' {
            { CDInterface -writetomedia } | Should -Throw
        }
    }
}

Describe 'CDInterface -getdrivestate (Development mode))' {
    BeforeAll {
        # Mock the settings file - setting non-production mode
        Mock -ModuleName CDInterfaceModule Get-Content {
            $settings = 
                        @' 
                            {
                                "sizeOfSector" : 1800,
                                "driveDefault" : 0,
                                "mediaTypeForProduction" : 2,
                                "production" : false
                            }
'@ | Set-Content -Path TestDrive:\settings.json
            return Get-Content -Path TestDrive:\settings.json
        }
    }

    Context "Normal behaviour for a blank CDR loaded on a system with 1 drive" {

        It 'it should show cd is blank and output 2 lines' {
            # Mock the get Drives object creation
            Mock -ModuleName CDInterfaceModule 'New-Object' {
                $1discMasterMock # Simulate a system with 1 drive
            } -ParameterFilter { $ComObject -eq "IMAPI2.MsftDiscMaster2" }

            # Mock the recorder object creation
            Mock -ModuleName CDInterfaceModule 'New-Object' { 
                New-Object 'fake_IMAPI2_MsftDiscRecorder2' 
            } -ParameterFilter { $ComObject -eq "IMAPI2.MsftDiscRecorder2" }

            # Mock the formatter object
            Mock -ModuleName CDInterfaceModule 'New-Object' { 
                New-Object 'fake_IMAPI2_MsftDiscFormat2Data' 
            } -ParameterFilter { $ComObject -eq "IMAPI2.MsftDiscFormat2Data" }

            $cdi = CDInterface -getdrivestate
            $cdi.Count | Should -Be 2
            $cdi[0] | Should -Be "BLANK_CD"
        }
    }

    Context "Same Normal behaviour for a blank CDRW loaded on a system with 1 drive" {

        It 'it should show cd is blank and output 2 lines' {
            # Mock the get Drives object creation
            Mock -ModuleName CDInterfaceModule 'New-Object' {
                $1discMasterMock # Simulate a system with 1 drive
            } -ParameterFilter { $ComObject -eq "IMAPI2.MsftDiscMaster2" }

            # Mock the recorder object creation
            Mock -ModuleName CDInterfaceModule 'New-Object' { 
                New-Object 'fake_IMAPI2_MsftDiscRecorder2' 
            } -ParameterFilter { $ComObject -eq "IMAPI2.MsftDiscRecorder2" }

            # Mock the formatter object
            Mock -ModuleName CDInterfaceModule 'New-Object' { 
                New-Object 'fake_IMAPI2_MsftDiscFormat2Data_CDRW' 
            } -ParameterFilter { $ComObject -eq "IMAPI2.MsftDiscFormat2Data" }

            $cdi = CDInterface -getdrivestate
            $cdi.Count | Should -Be 2
            $cdi[0] | Should -Be "BLANK_CD"
        }
    }

    Context "Error behaviour CDRW is not blank CDRW on a system with 1 drive" {

        It 'it should show cd is not blank and output 2 lines' {
            # Mock the get Drives object creation
            Mock -ModuleName CDInterfaceModule 'New-Object' {
                $1discMasterMock # Simulate a system with 1 drive
            } -ParameterFilter { $ComObject -eq "IMAPI2.MsftDiscMaster2" }

            # Mock the recorder object creation
            Mock -ModuleName CDInterfaceModule 'New-Object' { 
                New-Object 'fake_IMAPI2_MsftDiscRecorder2' 
            } -ParameterFilter { $ComObject -eq "IMAPI2.MsftDiscRecorder2" }

            # Mock the formatter object
            Mock -ModuleName CDInterfaceModule 'New-Object' { 
                New-Object 'fake_IMAPI2_MsftDiscFormat2Data_CDRW_NOT_BLANK' 
            } -ParameterFilter { $ComObject -eq "IMAPI2.MsftDiscFormat2Data" }

            $cdi = CDInterface -getdrivestate
            $cdi.Count | Should -Be 2
            $cdi[0] | Should -Be "NON_WRITEABLE_DISC"
        }
    }
}