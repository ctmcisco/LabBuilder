#
# This is a PowerShell Unit Test file.
# You need a unit test framework such as Pester to run PowerShell Unit tests. 
# You can download Pester from http://go.microsoft.com/fwlink/?LinkID=534084
#

$ModuleRoot = Split-Path -Parent (Split-Path -Parent (Split-Path -Parent $Script:MyInvocation.MyCommand.Path))

Set-Location $ModuleRoot
if (Get-Module LabBuilder -All)
{
    Get-Module LabBuilder -All | Remove-Module
}

Import-Module "$ModuleRoot\LabBuilder.psd1" -Force -DisableNameChecking
$Global:TestConfigPath = "$ModuleRoot\Tests\PesterTestConfig"
$Global:TestConfigOKPath = "$Global:TestConfigPath\PesterTestConfig.OK.xml"
$Global:ArtifactPath = "$ModuleRoot\Artifacts"
$null = New-Item -Path "$Global:ArtifactPath" -ItemType Directory -Force -ErrorAction SilentlyContinue



InModuleScope LabBuilder {
<#
.SYNOPSIS
   Helper function that just creates an exception record for testing.
#>
    function New-Exception
    {
        [CmdLetBinding()]
        param
        (
            [Parameter(Mandatory)]
            [String] $errorId,

            [Parameter(Mandatory)]
            [System.Management.Automation.ErrorCategory] $errorCategory,

            [Parameter(Mandatory)]
            [String] $errorMessage,
            
            [Switch]
            $terminate
        )

        $exception = New-Object -TypeName System.Exception `
            -ArgumentList $errorMessage
        $errorRecord = New-Object -TypeName System.Management.Automation.ErrorRecord `
            -ArgumentList $exception, $errorId, $errorCategory, $null
        return $errorRecord
    }

    Describe 'Download-WMF5Installer' {
        Context 'WMF 5.0 Installer File Exists' {
            It 'Does not throw an Exception' {
                Mock Test-Path -MockWith { $true }
                Mock Invoke-WebRequest

                { Download-WMF5Installer } | Should Not Throw
            }
            It 'Calls appropriate mocks' {
                Assert-MockCalled Test-Path -Exactly 1
                Assert-MockCalled Invoke-WebRequest -Exactly 0
            }
        }

        Context 'WMF 5.0 Installer File Does Not Exist' {
            It 'Does not throw an Exception' {
                Mock Test-Path -MockWith { $false }
                Mock Invoke-WebRequest

                { Download-WMF5Installer } | Should Not Throw
            }
            It 'Calls appropriate mocks' {
                Assert-MockCalled Test-Path -Exactly 1
                Assert-MockCalled Invoke-WebRequest -Exactly 1
            }
        }

        Context 'WMF 5.0 Installer File Does Not Exist and Fails Downloading' {
            It 'Throws a FileDownloadError Exception' {
                Mock Test-Path -MockWith { $false }
                Mock Invoke-WebRequest { Throw ('Download Error') }

                $ExceptionParameters = @{
                    errorId = 'FileDownloadError'
                    errorCategory = 'InvalidArgument'
                    errorMessage = $($LocalizedData.FileDownloadError `
                        -f 'WMF 5.0 Installer','https://download.microsoft.com/download/2/C/6/2C6E1B4A-EBE5-48A6-B225-2D2058A9CEFB/W2K12R2-KB3094174-x64.msu','Download Error')
                }
                $Exception = New-Exception @ExceptionParameters

                { Download-WMF5Installer } | Should Throw $Exception
            }
            It 'Calls appropriate mocks' {
                Assert-MockCalled Test-Path -Exactly 1
                Assert-MockCalled Invoke-WebRequest -Exactly 1
            }
        }
    }



    Describe 'Download-CertGenerator' {
        Context 'Certificate Generator Zip File and PS1 File Exists' {
            It 'Does not throw an Exception' {
                Mock Test-Path -MockWith { $true }
                Mock Invoke-WebRequest

                { Download-CertGenerator } | Should Not Throw
            }
            It 'Calls appropriate mocks' {
                Assert-MockCalled Test-Path -Exactly 2
                Assert-MockCalled Invoke-WebRequest -Exactly 0
            }
        }

        Context 'Certificate Generator Zip File Exists but PS1 File Does Not' {
            It 'Does not throw an Exception' {
                Mock Test-Path -ParameterFilter { $Path -like '*.zip' } -MockWith { $true }
                Mock Test-Path -ParameterFilter { $Path -like '*.ps1' } -MockWith { $false }
                Mock Expand-Archive
                Mock Invoke-WebRequest

                { Download-CertGenerator } | Should Not Throw
            }
            It 'Calls appropriate mocks' {
                Assert-MockCalled Test-Path -Exactly 2
                Assert-MockCalled Expand-Archive -Exactly 1
                Assert-MockCalled Invoke-WebRequest -Exactly 0
            }
        }

        Context 'Certificate Generator Zip File Does Not Exist' {
            It 'Does not throw an Exception' {
                Mock Test-Path -MockWith { $false }
                Mock Expand-Archive
                Mock Invoke-WebRequest

                { Download-CertGenerator } | Should Not Throw
            }
            It 'Calls appropriate mocks' {
                Assert-MockCalled Test-Path -Exactly 2
                Assert-MockCalled Expand-Archive -Exactly 1
                Assert-MockCalled Invoke-WebRequest -Exactly 1
            }
        }

        Context 'Certificate Generator Zip File Does Not Exist and Fails Downloading' {
            It 'Throws a FileDownloadError Exception' {
                Mock Test-Path -MockWith { $false }
                Mock Invoke-WebRequest { Throw ('Download Error') }

                $ExceptionParameters = @{
                    errorId = 'FileDownloadError'
                    errorCategory = 'InvalidArgument'
                    errorMessage = $($LocalizedData.FileDownloadError `
                        -f 'Certificate Generator','https://gallery.technet.microsoft.com/scriptcenter/Self-signed-certificate-5920a7c6/file/101251/1/New-SelfSignedCertificateEx.zip','Download Error')
                }
                $Exception = New-Exception @ExceptionParameters

                { Download-CertGenerator } | Should Throw $Exception
            }
            It 'Calls appropriate mocks' {
                Assert-MockCalled Test-Path -Exactly 1
                Assert-MockCalled Invoke-WebRequest -Exactly 1
            }
        }
    }



    Describe 'Get-ModulesInDSCConfig' {
        Context 'Called with Test DSC Resource File' {
            $Modules = Get-ModulesInDSCConfig `
                -DSCConfigFile (Join-Path -Path $Global:TestConfigPath -ChildPath 'PesterTest.DSC.ps1')
            It 'Should Return Expected Modules' {
                @(Compare-Object -ReferenceObject $Modules `
                    -DifferenceObject @('xActiveDirectory','xComputerManagement','xDHCPServer','xNetworking')).Count `
                | Should Be 0
            }
        }
    }



    Describe 'Get-LabConfiguration' {
        Context 'Path is provided and valid XML file exists' {
            It 'Returns XmlDocument object with valid content' {
                $Config = Get-LabConfiguration -Path $Global:TestConfigOKPath
                $Config.GetType().Name | Should Be 'XmlDocument'
                $Config.labbuilderconfig | Should Not Be $null
            }
        }

        Context 'Path is provided but file does not exist' {
            It 'Throws ConfigurationFileNotFoundError Exception' {

                $ExceptionParameters = @{
                    errorId = 'ConfigurationFileNotFoundError'
                    errorCategory = 'InvalidArgument'
                    errorMessage = $($LocalizedData.ConfigurationFileNotFoundError `
                        -f 'c:\doesntexist.xml')
                }
                $Exception = New-Exception @ExceptionParameters

                Mock Test-Path -MockWith { $false }

                { Get-LabConfiguration -Path 'c:\doesntexist.xml' } | Should Throw $Exception
            }
        }

        Context 'Path is provided and file exists but is empty' {
            It 'Throws ConfigurationFileEmptyError Exception' {

                $ExceptionParameters = @{
                    errorId = 'ConfigurationFileEmptyError'
                    errorCategory = 'InvalidArgument'
                    errorMessage = $($LocalizedData.ConfigurationFileEmptyError `
                        -f 'c:\isempty.xml')
                }
                $Exception = New-Exception @ExceptionParameters

                Mock Test-Path -MockWith { $true }
                Mock Get-Content -MockWith {''}

                { Get-LabConfiguration -Path 'c:\isempty.xml' } | Should Throw $Exception
            }
        }
    }



    Describe 'Test-LabConfiguration' {

        $Config = Get-LabConfiguration -Path $Global:TestConfigOKPath

        Mock Test-Path -ParameterFilter { $Path -eq 'c:\exists\' } -MockWith { $true }
        Mock Test-Path -ParameterFilter { $Path -eq 'c:\doesnotexist\' } -MockWith { $false }

        Context 'Valid Configuration is provided and all paths exist' {
            It 'Returns True' {
                $Config.labbuilderconfig.settings.vmpath = 'c:\exists\'
                $Config.labbuilderconfig.settings.vhdparentpath = 'c:\exists\'

                Test-LabConfiguration -Configuration $Config | Should Be $True
            }
        }

        Context 'Valid Configuration is provided and VMPath is empty' {
            It 'Throws ConfigurationMissingElementError Exception' {
                $Config.labbuilderconfig.settings.vmpath = ''
                $Config.labbuilderconfig.settings.vhdparentpath = 'c:\exists\'

                $ExceptionParameters = @{
                    errorId = 'ConfigurationMissingElementError'
                    errorCategory = 'InvalidArgument'
                    errorMessage = $($LocalizedData.ConfigurationMissingElementError `
                        -f '<settings>\<vmpath>')
                }
                $Exception = New-Exception @ExceptionParameters

                { Test-LabConfiguration -Configuration $Config } | Should Throw $Exception
            }
        }

        Context 'Valid Configuration is provided and VMPath folder does not exist' {
            It 'Throws PathNotFoundError Exception' {
                $Config.labbuilderconfig.settings.vmpath = 'c:\doesnotexist\'
                $Config.labbuilderconfig.settings.vhdparentpath = 'c:\exists\'
            
                $ExceptionParameters = @{
                    errorId = 'PathNotFoundError'
                    errorCategory = 'InvalidArgument'
                    errorMessage = $($LocalizedData.PathNotFoundError `
                        -f '<settings>\<vmpath>','c:\doesnotexist\')
                }
                $Exception = New-Exception @ExceptionParameters

                { Test-LabConfiguration -Configuration $Config } | Should Throw $Exception
            }
        }
        
        Context 'Valid Configuration is provided and VHDParentPath is empty' {
            It 'Throws ConfigurationMissingElementError Exception' {
                $Config.labbuilderconfig.settings.vmpath = 'c:\exists\'
                $Config.labbuilderconfig.settings.vhdparentpath = ''

                $ExceptionParameters = @{
                    errorId = 'ConfigurationMissingElementError'
                    errorCategory = 'InvalidArgument'
                    errorMessage = $($LocalizedData.ConfigurationMissingElementError `
                        -f '<settings>\<vhdparentpath>')
                }
                $Exception = New-Exception @ExceptionParameters

                { Test-LabConfiguration -Configuration $Config } | Should Throw $Exception
            }
        }

        Context 'Valid Configuration is provided and VHDParentPath folder does not exist' {
            It 'Throws PathNotFoundError Exception' {
                $Config.labbuilderconfig.settings.vmpath = 'c:\exists\'
                $Config.labbuilderconfig.settings.vhdparentpath = 'c:\doesnotexist\'
                
                $ExceptionParameters = @{
                    errorId = 'PathNotFoundError'
                    errorCategory = 'InvalidArgument'
                    errorMessage = $($LocalizedData.PathNotFoundError `
                        -f '<settings>\<vhdparentpath>','c:\doesnotexist\')
                }
                $Exception = New-Exception @ExceptionParameters

                { Test-LabConfiguration -Configuration $Config } | Should Throw $Exception
            }
        }
    }



    Describe 'Install-LabHyperV' {

        $Config = Get-LabConfiguration -Path $Global:TestConfigOKPath

        If ((Get-CimInstance Win32_OperatingSystem).ProductType -eq 1) {
            Mock Get-WindowsOptionalFeature { [PSObject]@{ FeatureName = 'Mock'; State = 'Disabled'; } }
            Mock Enable-WindowsOptionalFeature 
        } Else {
            Mock Get-WindowsFeature { [PSObject]@{ Name = 'Mock'; Installed = $false; } }
            Mock Install-WindowsFeature
        }

        Context 'The function is called' {
            It 'Does not throw an Exception' {
                { Install-LabHyperV } | Should Not Throw
            }
            If ((Get-CimInstance Win32_OperatingSystem).ProductType -eq 1) {
                It 'Calls appropriate mocks' {
                    Assert-MockCalled Get-WindowsOptionalFeature -Exactly 1
                    Assert-MockCalled Enable-WindowsOptionalFeature -Exactly 1
                }
            } Else {
                It 'Calls appropriate mocks' {
                    Assert-MockCalled Get-WindowsFeature -Exactly 1
                    Assert-MockCalled Install-WindowsFeature -Exactly 1
                }
            }
        }
    }



    Describe 'Initialize-LabConfiguration' {
        $Config = Get-LabConfiguration -Path $Global:TestConfigOKPath

        Mock Download-CertGenerator
        Mock Download-WMF5Installer
        Mock Download-LabResources
        Mock Set-VMHost
        Mock Get-VMSwitch
        Mock New-VMSwitch
        Mock Get-VMNetworkAdapter -MockWith { @{ Name = 'LabBuilder Management PesterTestConfig' } }
        Mock Get-VMNetworkAdapterVlan
        Mock Set-VMNetworkAdapterVlan        

        Context 'Valid configuration is passed' {
            It 'Does not throw an Exception' {
                { Initialize-LabConfiguration -Configuration $Config } | Should Not Throw
            }
            It 'Calls appropriate mocks' {
                Assert-MockCalled Download-CertGenerator -Exactly 1
                Assert-MockCalled Download-WMF5Installer -Exactly 1
                Assert-MockCalled Download-LabResources -Exactly 1
                Assert-MockCalled Set-VMHost -Exactly 1
                Assert-MockCalled Get-VMSwitch -Exactly 1
                Assert-MockCalled New-VMSwitch -Exactly 1
                Assert-MockCalled Get-VMNetworkAdapter -Exactly 1
                Assert-MockCalled Get-VMNetworkAdapterVlan -Exactly 1
                Assert-MockCalled Set-VMNetworkAdapterVlan -Exactly 1
            }		
        }
    }



    Describe 'Download-LabModule' {
        $URL = 'https://github.com/PowerShell/xNetworking/archive/dev.zip'
        
        Mock Get-Module -MockWith { @( New-Object -TypeName PSObject -Property @{ Name = 'xNetworking'; Version = '2.4.0.0'; } ) }
        Mock Invoke-WebRequest
        Mock Expand-Archive
        Mock Rename-Item
        Mock Test-Path -MockWith { $false }
        Mock Remove-Item
        Mock Get-PackageProvider
        Mock Install-Module

        Context 'Correct module already installed; Valid URL and Folder passed' {
            It 'Does not throw an Exception' {
                {
                    Download-LabModule `
                        -Name 'xNetworking' `
                        -URL $URL `
                        -Folder 'xNetworkingDev'
                } | Should Not Throw
            }
            It 'Should call appropriate Mocks' {
                Assert-MockCalled Get-Module -Exactly 1
                Assert-MockCalled Invoke-WebRequest -Exactly 0
                Assert-MockCalled Expand-Archive -Exactly 0
                Assert-MockCalled Rename-Item -Exactly 0
                Assert-MockCalled Test-Path -Exactly 0
                Assert-MockCalled Remove-Item -Exactly 0
                Assert-MockCalled Get-PackageProvider -Exactly 0
                Assert-MockCalled Install-Module -Exactly 0
            }
        }

        Mock Get-Module -MockWith { }

        Context 'Module is not installed; Valid URL and Folder passed' {
            It 'Does not throw an Exception' {
                {
                    Download-LabModule `
                        -Name 'xNetworking' `
                        -URL $URL `
                        -Folder 'xNetworkingDev'
                } | Should Not Throw
            }
            It 'Should call appropriate Mocks' {
                Assert-MockCalled Get-Module -Exactly 1
                Assert-MockCalled Invoke-WebRequest -Exactly 1
                Assert-MockCalled Expand-Archive -Exactly 1
                Assert-MockCalled Rename-Item -Exactly 1
                Assert-MockCalled Test-Path -Exactly 1
                Assert-MockCalled Remove-Item -Exactly 0
                Assert-MockCalled Get-PackageProvider -Exactly 0
                Assert-MockCalled Install-Module -Exactly 0
            }
        }

        Context 'Module is not installed; No URL or Folder passed' {
            It 'Does not throw an Exception' {
                {
                    Download-LabModule `
                        -Name 'xNetworking'
                } | Should Not Throw
            }
            It 'Should call appropriate Mocks' {
                Assert-MockCalled Get-Module -Exactly 1
                Assert-MockCalled Invoke-WebRequest -Exactly 0
                Assert-MockCalled Expand-Archive -Exactly 0
                Assert-MockCalled Rename-Item -Exactly 0
                Assert-MockCalled Test-Path -Exactly 0
                Assert-MockCalled Remove-Item -Exactly 0
                Assert-MockCalled Get-PackageProvider -Exactly 1
                Assert-MockCalled Install-Module -Exactly 1
            }
        }

        Mock Get-Module -MockWith { @( New-Object -TypeName PSObject -Property @{ Name = 'xNetworking'; Version = '2.4.0.0'; } ) }

        Context 'Wrong version of module is installed; Valid URL, Folder and Required Version passed' {
            It 'Does not throw an Exception' {
                {
                    Download-LabModule `
                        -Name 'xNetworking' `
                        -URL $URL `
                        -Folder 'xNetworkingDev' `
                        -RequiredVersion '2.5.0.0'
                } | Should Not Throw
            }
            It 'Should call appropriate Mocks' {
                Assert-MockCalled Get-Module -Exactly 1
                Assert-MockCalled Invoke-WebRequest -Exactly 1
                Assert-MockCalled Expand-Archive -Exactly 1
                Assert-MockCalled Rename-Item -Exactly 1
                Assert-MockCalled Test-Path -Exactly 1
                Assert-MockCalled Remove-Item -Exactly 0
                Assert-MockCalled Get-PackageProvider -Exactly 0
                Assert-MockCalled Install-Module -Exactly 0
            }
        }

        Context 'Wrong version of module is installed; No URL or Folder passed, but Required Version passed' {
            It 'Does not throw an Exception' {
                {
                    Download-LabModule `
                        -Name 'xNetworking' `
                        -RequiredVersion '2.5.0.0'
                } | Should Not Throw
            }
            It 'Should call appropriate Mocks' {
                Assert-MockCalled Get-Module -Exactly 1
                Assert-MockCalled Invoke-WebRequest -Exactly 0
                Assert-MockCalled Expand-Archive -Exactly 0
                Assert-MockCalled Rename-Item -Exactly 0
                Assert-MockCalled Test-Path -Exactly 0
                Assert-MockCalled Remove-Item -Exactly 0
                Assert-MockCalled Get-PackageProvider -Exactly 1
                Assert-MockCalled Install-Module -Exactly 1
            }
        }

        Context 'Correct version of module is installed; Valid URL, Folder and Required Version passed' {
            It 'Does not throw an Exception' {
                {
                    Download-LabModule `
                        -Name 'xNetworking' `
                        -URL $URL `
                        -Folder 'xNetworkingDev' `
                        -RequiredVersion '2.4.0.0'
                } | Should Not Throw
            }
            It 'Should call appropriate Mocks' {
                Assert-MockCalled Get-Module -Exactly 1
                Assert-MockCalled Invoke-WebRequest -Exactly 0
                Assert-MockCalled Expand-Archive -Exactly 0
                Assert-MockCalled Rename-Item -Exactly 0
                Assert-MockCalled Test-Path -Exactly 0
                Assert-MockCalled Remove-Item -Exactly 0
                Assert-MockCalled Get-PackageProvider -Exactly 0
                Assert-MockCalled Install-Module -Exactly 0
            }
        }

        Context 'Correct version of module is installed; No URL and Folder passed, but Required Version passed' {
            It 'Does not throw an Exception' {
                {
                    Download-LabModule `
                        -Name 'xNetworking' `
                        -RequiredVersion '2.4.0.0'
                } | Should Not Throw
            }
            It 'Should call appropriate Mocks' {
                Assert-MockCalled Get-Module -Exactly 1
                Assert-MockCalled Invoke-WebRequest -Exactly 0
                Assert-MockCalled Expand-Archive -Exactly 0
                Assert-MockCalled Rename-Item -Exactly 0
                Assert-MockCalled Test-Path -Exactly 0
                Assert-MockCalled Remove-Item -Exactly 0
                Assert-MockCalled Get-PackageProvider -Exactly 0
                Assert-MockCalled Install-Module -Exactly 0
            }
        }

        Context 'Wrong version of module is installed; Valid URL, Folder and Minimum Version passed' {
            It 'Does not throw an Exception' {
                {
                    Download-LabModule `
                        -Name 'xNetworking' `
                        -URL $URL `
                        -Folder 'xNetworkingDev' `
                        -MinimumVersion '2.5.0.0'
                } | Should Not Throw
            }
            It 'Should call appropriate Mocks' {
                Assert-MockCalled Get-Module -Exactly 1
                Assert-MockCalled Invoke-WebRequest -Exactly 1
                Assert-MockCalled Expand-Archive -Exactly 1
                Assert-MockCalled Rename-Item -Exactly 1
                Assert-MockCalled Test-Path -Exactly 1
                Assert-MockCalled Remove-Item -Exactly 0
                Assert-MockCalled Get-PackageProvider -Exactly 0
                Assert-MockCalled Install-Module -Exactly 0
            }
        }

        Context 'Wrong version of module is installed; No URL and Folder passed, but Minimum Version passed' {
            It 'Does not throw an Exception' {
                {
                    Download-LabModule `
                        -Name 'xNetworking' `
                        -MinimumVersion '2.5.0.0'
                } | Should Not Throw
            }
            It 'Should call appropriate Mocks' {
                Assert-MockCalled Get-Module -Exactly 1
                Assert-MockCalled Invoke-WebRequest -Exactly 0
                Assert-MockCalled Expand-Archive -Exactly 0
                Assert-MockCalled Rename-Item -Exactly 0
                Assert-MockCalled Test-Path -Exactly 0
                Assert-MockCalled Remove-Item -Exactly 0
                Assert-MockCalled Get-PackageProvider -Exactly 1
                Assert-MockCalled Install-Module -Exactly 1
            }
        }

        Context 'Correct version of module is installed; Valid URL, Folder and Minimum Version passed' {
            It 'Does not throw an Exception' {
                {
                    Download-LabModule `
                        -Name 'xNetworking' `
                        -URL $URL `
                        -Folder 'xNetworkingDev' `
                        -MinimumVersion '2.4.0.0'
                } | Should Not Throw
            }
            It 'Should call appropriate Mocks' {
                Assert-MockCalled Get-Module -Exactly 1
                Assert-MockCalled Invoke-WebRequest -Exactly 0
                Assert-MockCalled Expand-Archive -Exactly 0
                Assert-MockCalled Rename-Item -Exactly 0
                Assert-MockCalled Test-Path -Exactly 0
                Assert-MockCalled Remove-Item -Exactly 0
                Assert-MockCalled Get-PackageProvider -Exactly 0
                Assert-MockCalled Install-Module -Exactly 0
            }
        }

        Context 'Correct version of module is installed; No URL and Folder passed, but Minimum Version passed' {
            It 'Does not throw an Exception' {
                {
                    Download-LabModule `
                        -Name 'xNetworking' `
                        -MinimumVersion '2.4.0.0'
                } | Should Not Throw
            }
            It 'Should call appropriate Mocks' {
                Assert-MockCalled Get-Module -Exactly 1
                Assert-MockCalled Invoke-WebRequest -Exactly 0
                Assert-MockCalled Expand-Archive -Exactly 0
                Assert-MockCalled Rename-Item -Exactly 0
                Assert-MockCalled Test-Path -Exactly 0
                Assert-MockCalled Remove-Item -Exactly 0
                Assert-MockCalled Get-PackageProvider -Exactly 0
                Assert-MockCalled Install-Module -Exactly 0
            }
        }

        Mock Get-Module -MockWith { }
        Mock Invoke-WebRequest -MockWith { Throw ('Download Error') }

        Context 'Module is not installed; Bad URL passed' {
            It 'Throws a FileDownloadError exception' {
                $ExceptionParameters = @{
                    errorId = 'FileDownloadError'
                    errorCategory = 'InvalidOperation'
                    errorMessage = $($LocalizedData.FileDownloadError `
                        -f 'Module Resource xNetworking',$URL,'Download Error')
                }
                $Exception = New-Exception @ExceptionParameters

                {
                    Download-LabModule `
                        -Name 'xNetworking' `
                        -URL $URL `
                        -Folder 'xNetworkingDev'
                } | Should Throw $Exception
            }
            It 'Should call appropriate Mocks' {
                Assert-MockCalled Get-Module -Exactly 1
                Assert-MockCalled Invoke-WebRequest -Exactly 1
                Assert-MockCalled Expand-Archive -Exactly 0
                Assert-MockCalled Rename-Item -Exactly 0
                Assert-MockCalled Test-Path -Exactly 0
                Assert-MockCalled Remove-Item -Exactly 0
                Assert-MockCalled Get-PackageProvider -Exactly 0
                Assert-MockCalled Install-Module -Exactly 0
            }
        }

        Mock Install-Module -MockWith { Throw ("No match was found for the specified search criteria and module name 'xDoesNotExist'" )}

        Context 'Module is not installed; Not available in Repository' {
            It 'Throws a ModuleNotAvailableError exception' {
                $ExceptionParameters = @{
                    errorId = 'ModuleNotAvailableError'
                    errorCategory = 'InvalidArgument'
                    errorMessage = $($LocalizedData.ModuleNotAvailableError `
                        -f 'xDoesNotExist','any version',"No match was found for the specified search criteria and module name 'xDoesNotExist'")
                }
                $Exception = New-Exception @ExceptionParameters

                {
                    Download-LabModule `
                        -Name 'xDoesNotExist'
                } | Should Throw $Exception
            }
            It 'Should call appropriate Mocks' {
                Assert-MockCalled Get-Module -Exactly 1
                Assert-MockCalled Invoke-WebRequest -Exactly 0
                Assert-MockCalled Expand-Archive -Exactly 0
                Assert-MockCalled Rename-Item -Exactly 0
                Assert-MockCalled Test-Path -Exactly 0
                Assert-MockCalled Remove-Item -Exactly 0
                Assert-MockCalled Get-PackageProvider -Exactly 1
                Assert-MockCalled Install-Module -Exactly 1
            }
        }

        Mock Install-Module -MockWith { Throw ("No match was found for the specified search criteria and module name 'xNetworking'" )}

        Context 'Wrong version of module is installed; No URL or Folder passed, but Required Version passed. Required Version is not available' {
            It ' Throws a ModuleNotAvailableError Exception' {
                $ExceptionParameters = @{
                    errorId = 'ModuleNotAvailableError'
                    errorCategory = 'InvalidArgument'
                    errorMessage = $($LocalizedData.ModuleNotAvailableError `
                        -f 'xNetworking','2.5.0.0',"No match was found for the specified search criteria and module name 'xNetworking'" )
                }
                $Exception = New-Exception @ExceptionParameters

                {
                    Download-LabModule `
                        -Name 'xNetworking' `
                        -RequiredVersion '2.5.0.0'
                } | Should Throw $Exception
            }
            It 'Should call appropriate Mocks' {
                Assert-MockCalled Get-Module -Exactly 1
                Assert-MockCalled Invoke-WebRequest -Exactly 0
                Assert-MockCalled Expand-Archive -Exactly 0
                Assert-MockCalled Rename-Item -Exactly 0
                Assert-MockCalled Test-Path -Exactly 0
                Assert-MockCalled Remove-Item -Exactly 0
                Assert-MockCalled Get-PackageProvider -Exactly 1
                Assert-MockCalled Install-Module -Exactly 1
            }
        }
        
        Context 'Wrong version of module is installed; No URL or Folder passed, but Minimum Version passed. Minimum Version is not available' {
            It ' Throws a ModuleNotAvailableError Exception' {
                $ExceptionParameters = @{
                    errorId = 'ModuleNotAvailableError'
                    errorCategory = 'InvalidArgument'
                    errorMessage = $($LocalizedData.ModuleNotAvailableError `
                        -f 'xNetworking','min 2.5.0.0',"No match was found for the specified search criteria and module name 'xNetworking'" )
                }
                $Exception = New-Exception @ExceptionParameters

                {
                    Download-LabModule `
                        -Name 'xNetworking' `
                        -MinimumVersion '2.5.0.0'
                } | Should Throw $Exception
            }
            It 'Should call appropriate Mocks' {
                Assert-MockCalled Get-Module -Exactly 1
                Assert-MockCalled Invoke-WebRequest -Exactly 0
                Assert-MockCalled Expand-Archive -Exactly 0
                Assert-MockCalled Rename-Item -Exactly 0
                Assert-MockCalled Test-Path -Exactly 0
                Assert-MockCalled Remove-Item -Exactly 0
                Assert-MockCalled Get-PackageProvider -Exactly 1
                Assert-MockCalled Install-Module -Exactly 1
            }
        }

    }



    Describe 'Download-LabResources' -Tags 'Incomplete' {
        $Config = Get-LabConfiguration -Path $Global:TestConfigOKPath

        Context 'Valid configuration is passed' {
            Mock Download-LabModule
            It 'Does not throw an Exception' {
                { Download-LabResources -Configuration $Config } | Should Not Throw
            }
            It 'Should call appropriate Mocks' {
                Assert-MockCalled Download-LabModule -Exactly 4
            }
        }
    }



    Describe 'Get-LabSwitches' {
        Context 'Configuration passed with switch missing Switch Name.' {
            It 'Throws a SwitchNameIsEmptyError Exception' {
                $ExceptionParameters = @{
                    errorId = 'SwitchNameIsEmptyError'
                    errorCategory = 'InvalidArgument'
                    errorMessage = $($LocalizedData.SwitchNameIsEmptyError)
                }
                $Exception = New-Exception @ExceptionParameters

                { Get-LabSwitches -Configuration (Get-LabConfiguration -Path "$Global:TestConfigPath\PesterTestConfig.SwitchFail.NoName.xml") } | Should Throw $Exception
            }
        }
        Context 'Configuration passed with switch missing Switch Type.' {
            It 'Throws a UnknownSwitchTypeError Exception' {
                $ExceptionParameters = @{
                    errorId = 'UnknownSwitchTypeError'
                    errorCategory = 'InvalidArgument'
                    errorMessage = $($LocalizedData.UnknownSwitchTypeError `
                        -f '','Pester Switch Fail')
                }
                $Exception = New-Exception @ExceptionParameters

                { Get-LabSwitches -Configuration (Get-LabConfiguration -Path "$Global:TestConfigPath\PesterTestConfig.SwitchFail.NoType.xml") } | Should Throw $Exception
            }
        }
        Context 'Configuration passed with switch invalid Switch Type.' {
            It 'Throws a UnknownSwitchTypeError Exception' {
                $ExceptionParameters = @{
                    errorId = 'UnknownSwitchTypeError'
                    errorCategory = 'InvalidArgument'
                    errorMessage = $($LocalizedData.UnknownSwitchTypeError `
                        -f 'BadType','Pester Switch Fail')
                }
                $Exception = New-Exception @ExceptionParameters

                { Get-LabSwitches -Configuration (Get-LabConfiguration -Path "$Global:TestConfigPath\PesterTestConfig.SwitchFail.BadType.xml") } | Should Throw $Exception
            }
        }
        Context 'Configuration passed with switch containing adapters but is not External type.' {
            It 'Throws a AdapterSpecifiedError Exception' {
                $ExceptionParameters = @{
                    errorId = 'AdapterSpecifiedError'
                    errorCategory = 'InvalidArgument'
                    errorMessage = $($LocalizedData.AdapterSpecifiedError `
                        -f 'Private','Pester Switch Fail')
                }
                $Exception = New-Exception @ExceptionParameters

                { Get-LabSwitches -Configuration (Get-LabConfiguration -Path "$Global:TestConfigPath\PesterTestConfig.SwitchFail.AdaptersSet.xml") } | Should Throw $Exception
            }
        }
        Context 'Valid configuration is passed' {
            It 'Returns Switches Object that matches Expected Object' {
                $Config = Get-LabConfiguration -Path $Global:TestConfigOKPath
                [Array]$Switches = Get-LabSwitches -Configuration $Config
                Set-Content -Path "$Global:ArtifactPath\ExpectedSwitches.json" -Value ($Switches | ConvertTo-Json -Depth 4)
                $ExpectedSwitches = Get-Content -Path "$Global:TestConfigPath\ExpectedSwitches.json"
                [String]::Compare((Get-Content -Path "$Global:ArtifactPath\ExpectedSwitches.json"),$ExpectedSwitches,$true) | Should Be 0
            }
        }
    }



    Describe 'Initialize-LabSwitches' {

        $Config = Get-LabConfiguration -Path $Global:TestConfigOKPath
        [Array]$Switches = Get-LabSwitches -Configuration $Config

        Mock Get-VMSwitch
        Mock New-VMSwitch
        Mock Add-VMNetworkAdapter
        Mock Set-VMNetworkAdapterVlan

        Context 'Valid configuration is passed' {	
            It 'Does not throw an Exception' {
                { Initialize-LabSwitches -Configuration $Config -Switches $Switches } | Should Not Throw
            }
            It 'Calls Mocked commands' {
                Assert-MockCalled Get-VMSwitch -Exactly 5
                Assert-MockCalled New-VMSwitch -Exactly 5
                Assert-MockCalled Add-VMNetworkAdapter -Exactly 4
                Assert-MockCalled Set-VMNetworkAdapterVlan -Exactly 0
            }
        }

        Context 'Valid configuration with invalid switch type passed' {	
            $Switches[0].Type='Invalid'
            It 'Throws a UnknownSwitchTypeError Exception' {
                $ExceptionParameters = @{
                    errorId = 'UnknownSwitchTypeError'
                    errorCategory = 'InvalidArgument'
                    errorMessage = $($LocalizedData.UnknownSwitchTypeError `
                        -f 'Invalid',$Switches[0].Name)
                }
                $Exception = New-Exception @ExceptionParameters

                { Initialize-LabSwitches -Configuration $Config -Switches $Switches } | Should Throw $Exception
            }
            It 'Calls Mocked commands' {
                Assert-MockCalled Get-VMSwitch -Exactly 1
                Assert-MockCalled New-VMSwitch -Exactly 0
                Assert-MockCalled Add-VMNetworkAdapter -Exactly 0
                Assert-MockCalled Set-VMNetworkAdapterVlan -Exactly 0
            }
        }

        Context 'Valid configuration NAT with blank NAT Subnet Address' {	
            $Switches[0].Type = 'NAT'
            It 'Throws a NatSubnetAddressEmptyError Exception' {
                $ExceptionParameters = @{
                    errorId = 'NatSubnetAddressEmptyError'
                    errorCategory = 'InvalidArgument'
                    errorMessage = $($LocalizedData.NatSubnetAddressEmptyError `
                        -f $Switches[0].Name)
                }
                $Exception = New-Exception @ExceptionParameters

                { Initialize-LabSwitches -Configuration $Config -Switches $Switches } | Should Throw $Exception
            }
            It 'Calls Mocked commands' {
                Assert-MockCalled Get-VMSwitch -Exactly 1
                Assert-MockCalled New-VMSwitch -Exactly 0
                Assert-MockCalled Add-VMNetworkAdapter -Exactly 0
                Assert-MockCalled Set-VMNetworkAdapterVlan -Exactly 0
            }
        }

        Context 'Valid configuration with blank switch name passed' {	
            $Switches[0].Type = 'External'
            $Switches[0].Name = ''
            It 'Throws a SwitchNameIsEmptyError Exception' {
                $ExceptionParameters = @{
                    errorId = 'SwitchNameIsEmptyError'
                    errorCategory = 'InvalidArgument'
                    errorMessage = $($LocalizedData.SwitchNameIsEmptyError)
                }
                $Exception = New-Exception @ExceptionParameters

                { Initialize-LabSwitches -Configuration $Config -Switches $Switches } | Should Throw $Exception
            }
            It 'Calls Mocked commands' {
                Assert-MockCalled Get-VMSwitch -Exactly 1
                Assert-MockCalled New-VMSwitch -Exactly 0
                Assert-MockCalled Add-VMNetworkAdapter -Exactly 0
                Assert-MockCalled Set-VMNetworkAdapterVlan -Exactly 0
            }
        }
    }



    Describe 'Remove-LabSwitches' {

        $Config = Get-LabConfiguration -Path $Global:TestConfigOKPath
        [Array]$Switches = Get-LabSwitches -Configuration $Config

        Mock Get-VMSwitch -MockWith { $Switches }
        Mock Remove-VMSwitch

        Context 'Valid configuration is passed' {	
            It 'Does not throw an Exception' {
                { Remove-LabSwitches -Configuration $Config -Switches $Switches } | Should Not Throw
            }
            It 'Calls Mocked commands' {
                Assert-MockCalled Get-VMSwitch -Exactly 5
                Assert-MockCalled Remove-VMSwitch -Exactly 5
            }
        }

        Context 'Valid configuration with invalid switch type passed' {	
            $Switches[0].Type='Invalid'
            It 'Throws a UnknownSwitchTypeError Exception' {
                $ExceptionParameters = @{
                    errorId = 'UnknownSwitchTypeError'
                    errorCategory = 'InvalidArgument'
                    errorMessage = $($LocalizedData.UnknownSwitchTypeError `
                        -f 'Invalid',$Switches[0].Name)
                }
                $Exception = New-Exception @ExceptionParameters

                { Remove-LabSwitches -Configuration $Config -Switches $Switches } | Should Throw $Exception
            }
            It 'Calls Mocked commands' {
                Assert-MockCalled Get-VMSwitch -Exactly 1
                Assert-MockCalled Remove-VMSwitch -Exactly 0
            }
        }

        Context 'Valid configuration with blank switch name passed' {	
            $Switches[0].Type = 'External'
            $Switches[0].Name = ''
            It 'Throws a SwitchNameIsEmptyError Exception' {
                $ExceptionParameters = @{
                    errorId = 'SwitchNameIsEmptyError'
                    errorCategory = 'InvalidArgument'
                    errorMessage = $($LocalizedData.SwitchNameIsEmptyError)
                }
                $Exception = New-Exception @ExceptionParameters

                { Remove-LabSwitches -Configuration $Config -Switches $Switches } | Should Throw $Exception
            }
            It 'Calls Mocked commands' {
                Assert-MockCalled Get-VMSwitch -Exactly 1
                Assert-MockCalled Remove-VMSwitch -Exactly 0
            }
        }

    }



    Describe 'Get-LabVMTemplates' {

        Mock Get-VM
        
        Context 'Configuration passed with template missing Template Name.' {
            It 'Throws a EmptyTemplateNameError Exception' {
                $ExceptionParameters = @{
                    errorId = 'EmptyTemplateNameError'
                    errorCategory = 'InvalidArgument'
                    errorMessage = $($LocalizedData.EmptyTemplateNameError)
                }
                $Exception = New-Exception @ExceptionParameters

                { Get-LabVMTemplates -Configuration (Get-LabConfiguration -Path "$Global:TestConfigPath\PesterTestConfig.TemplateFail.NoName.xml") } | Should Throw $Exception
            }
        }

        Context 'Configuration passed with template VHD empty.' {
            It 'Throws a EmptyTemplateVHDError Exception' {
                $ExceptionParameters = @{
                    errorId = 'EmptyTemplateVHDError'
                    errorCategory = 'InvalidArgument'
                    errorMessage = $($LocalizedData.EmptyTemplateVHDError `
                        -f 'No VHD')
                }
                $Exception = New-Exception @ExceptionParameters

                { Get-LabVMTemplates -Configuration (Get-LabConfiguration -Path "$Global:TestConfigPath\PesterTestConfig.TemplateFail.NoVHD.xml") } | Should Throw $Exception
            }
        }

        Context 'Configuration passed with template with Source VHD set to non-existent file.' {
            It 'Throws a TemplateSourceVHDNotFoundError Exception' {
                $ExceptionParameters = @{
                    errorId = 'TemplateSourceVHDNotFoundError'
                    errorCategory = 'InvalidArgument'
                    errorMessage = $($LocalizedData.TemplateSourceVHDNotFoundError `
                        -f 'Bad VHD','This File Doesnt Exist.vhdx')
                }
                $Exception = New-Exception @ExceptionParameters

                { Get-LabVMTemplates -Configuration (Get-LabConfiguration -Path "$Global:TestConfigPath\PesterTestConfig.TemplateFail.BadSourceVHD.xml") } | Should Throw $Exception
            }
        }
        
        $Config = Get-LabConfiguration -Path $Global:TestConfigOKPath

        Mock Get-VM
            
        Context 'Valid configuration is passed but no templates found' {
            It 'Returns Template Object that matches Expected Object' {
                [Array]$Templates = Get-LabVMTemplates -Configuration $Config 
                Set-Content -Path "$Global:ArtifactPath\ExpectedTemplates.json" -Value ($Templates | ConvertTo-Json -Depth 2)
                $ExpectedTemplates = Get-Content -Path "$Global:TestConfigPath\ExpectedTemplates.json"
                [String]::Compare((Get-Content -Path "$Global:ArtifactPath\ExpectedTemplates.json"),$ExpectedTemplates,$true) | Should Be 0
            }
            It 'Calls Mocked commands' {
                Assert-MockCalled Get-VM -Exactly 1
            }
        }

        Mock Get-VM -MockWith { @( 
                @{ name = 'Pester Windows Server 2012 R2 Datacenter Full' }
                @{ name = 'Pester Windows Server 2012 R2 Datacenter Core' } 
                @{ name = 'Pester Windows 10 Enterprise' } 
            ) }
        Mock Get-VMHardDiskDrive -ParameterFilter { $VMName -eq 'Pester Windows Server 2012 R2 Datacenter Full' } `
            -MockWith { @{ path = 'Pester Windows Server 2012 R2 Datacenter Full.vhdx' } }
        Mock Get-VMHardDiskDrive -ParameterFilter { $VMName -eq 'Pester Windows Server 2012 R2 Datacenter Core' } `
            -MockWith { @{ path = 'Pester Windows Server 2012 R2 Datacenter Core.vhdx' } }
        Mock Get-VMHardDiskDrive -ParameterFilter { $VMName -eq 'Pester Windows 10 Enterprise' } `
            -MockWith { @{ path = 'Pester Windows 10 Enterprise.vhdx' } }

        Context 'Valid configuration is passed and templates are found' {
            It 'Returns Template Object that matches Expected Object' {
                [Array]$Templates = Get-LabVMTemplates -Configuration $Config 
                Set-Content -Path "$Global:ArtifactPath\ExpectedTemplates.FromVM.json" -Value ($Templates | ConvertTo-Json -Depth 2)
                $ExpectedTemplates = Get-Content -Path "$Global:TestConfigPath\ExpectedTemplates.FromVM.json"
                [String]::Compare((Get-Content -Path "$Global:ArtifactPath\ExpectedTemplates.FromVM.json"),$ExpectedTemplates,$true) | Should Be 0
            }
            It 'Calls Mocked commands' {
                Assert-MockCalled Get-VM -Exactly 1
                Assert-MockCalled Get-VMHardDiskDrive -Exactly 3
            }
        }

    }



    Describe 'Initialize-LabVMTemplates' {

        $Config = Get-LabConfiguration -Path $Global:TestConfigOKPath

        Mock Copy-Item
        Mock Set-ItemProperty -ParameterFilter { ($Name -eq 'IsReadOnly') -and ($Value -eq $True) }
        Mock Set-ItemProperty -ParameterFilter { ($Name -eq 'IsReadOnly') -and ($Value -eq $False) }
        Mock Test-Path -ParameterFilter { $Path -eq 'This File Doesnt Exist.vhdx' } -MockWith { $false }
        Mock Optimize-VHD
        Mock Get-VM

        Context 'Valid Template Array with non-existent VHD source file' {
            [array]$Templates = @( @{
                name = 'Bad VHD'
                templatevhd = 'This File Doesnt Exist.vhdx' 
                sourcevhd = 'This File Doesnt Exist.vhdx'
            } )

            It 'Throws a TemplateSourceVHDNotFoundError Exception' {
                $ExceptionParameters = @{
                    errorId = 'TemplateSourceVHDNotFoundError'
                    errorCategory = 'InvalidArgument'
                    errorMessage = $($LocalizedData.TemplateSourceVHDNotFoundError `
                        -f 'Bad VHD','This File Doesnt Exist.vhdx')
                }
                $Exception = New-Exception @ExceptionParameters

                { Initialize-LabVMTemplates -Configuration $Config -VMTemplates $Templates } | Should Throw $Exception
            }
        }

        Context 'Valid Template Array is passed' {	
            [array]$Templates = Get-LabVMTemplates -Configuration $Config

            It 'Does not throw an Exception' {
                { Initialize-LabVMTemplates -Configuration $Config -VMTemplates $Templates } | Should Not Throw
            }
            It 'Calls Mocked commands' {
                Assert-MockCalled Copy-Item -Exactly 3
                Assert-MockCalled Set-ItemProperty -Exactly 3 -ParameterFilter { ($Name -eq 'IsReadOnly') -and ($Value -eq $True) }
                Assert-MockCalled Set-ItemProperty -Exactly 3 -ParameterFilter { ($Name -eq 'IsReadOnly') -and ($Value -eq $False) }
                Assert-MockCalled Optimize-VHD -Exactly 3
            }
        }
    }



    Describe 'Remove-LabVMTemplates' {

        $Config = Get-LabConfiguration -Path $Global:TestConfigOKPath

        Mock Set-ItemProperty -ParameterFilter { ($Name -eq 'IsReadOnly') -and ($Value -eq $False) }
        Mock Remove-Item
        Mock Test-Path -MockWith { $True }
        Mock Get-VM

        Context 'Valid configuration is passed' {	
            [Array]$Templates = Get-LabVMTemplates -Configuration $Config
            
            It 'Does not throw an Exception' {
                { Remove-LabVMTemplates -Configuration $Config -VMTemplates $Templates } | Should Not Throw
            }
            It 'Calls Mocked commands' {
                Assert-MockCalled Set-ItemProperty -Exactly 3 -ParameterFilter { ($Name -eq 'IsReadOnly') -and ($Value -eq $False) }
                Assert-MockCalled Remove-Item -Exactly 3
            }
        }
    }



    Describe 'Set-LabVMDSCMOFFile' -Tags 'Incomplete' {

        Mock Get-VM

        $Config = Get-LabConfiguration -Path $Global:TestConfigOKPath
        [Array]$Switches = Get-LabSwitches -Configuration $Config
        [Array]$Templates = Get-LabVMTemplates -Configuration $Config
        [Array]$VMs = Get-LabVMs -Configuration $Config -VMTemplates $Templates -Switches $Switches
        
        Mock Create-LabVMPath
        Mock Get-Module
        Mock Get-ModulesInDSCConfig -MockWith { @('TestModule') }

        Context 'Empty DSC Config' {
            $VM = $VMS[0].Clone()
            $VM.DSCConfigFile = ''
            It 'Does not throw an Exception' {
                { Set-LabVMDSCMOFFile -Configuration $Config -VM $VM } | Should Not Throw
            }
            It 'Calls Mocked commands' {
                Assert-MockCalled Create-LabVMPath -Exactly 1
                Assert-MockCalled Get-Module -Exactly 0
            }
        }

        Mock Find-Module
        
        Context 'DSC Module Not Found' {
            $VM = $VMS[0].Clone()
            $ExceptionParameters = @{
                errorId = 'DSCModuleDownloadError'
                errorCategory = 'InvalidArgument'
                errorMessage = $($LocalizedData.DSCModuleDownloadError `
                    -f $VM.DSCConfigFile,$VM.Name,'TestModule')
            }
            $Exception = New-Exception @ExceptionParameters

            It 'Throws a DSCModuleDownloadError Exception' {
                { Set-LabVMDSCMOFFile -Configuration $Config -VM $VM } | Should Throw $Exception
            }
            It 'Calls Mocked commands' {
                Assert-MockCalled Create-LabVMPath -Exactly 1
                Assert-MockCalled Get-Module -Exactly 1
                Assert-MockCalled Get-ModulesInDSCConfig -Exactly 1
                Assert-MockCalled Find-Module -Exactly 1
            }
        }

        Mock Find-Module -MockWith { @{ name = 'TestModule' } }
        Mock Install-Module -MockWith { Throw }
        
        Context 'DSC Module Download Error' {
            $VM = $VMS[0].Clone()
            $ExceptionParameters = @{
                errorId = 'DSCModuleDownloadError'
                errorCategory = 'InvalidArgument'
                errorMessage = $($LocalizedData.DSCModuleDownloadError `
                    -f $VM.DSCConfigFile,$VM.Name,'TestModule')
            }
            $Exception = New-Exception @ExceptionParameters

            It 'Throws a DSCModuleDownloadError Exception' {
                { Set-LabVMDSCMOFFile -Configuration $Config -VM $VM } | Should Throw $Exception
            }
            It 'Calls Mocked commands' {
                Assert-MockCalled Create-LabVMPath -Exactly 1
                Assert-MockCalled Get-Module -Exactly 1
                Assert-MockCalled Get-ModulesInDSCConfig -Exactly 1
                Assert-MockCalled Find-Module -Exactly 1
            }
        }

        Mock Install-Module -MockWith { }
        Mock Test-Path `
            -ParameterFilter { $Path -like '*TestModule' } `
            -MockWith { $false }
        
        Context 'DSC Module Not Found in Path' {
            $VM = $VMS[0].Clone()
            $ExceptionParameters = @{
                errorId = 'DSCModuleNotFoundError'
                errorCategory = 'InvalidArgument'
                errorMessage = $($LocalizedData.DSCModuleNotFoundError `
                    -f $VM.DSCConfigFile,$VM.Name,'TestModule')
            }
            $Exception = New-Exception @ExceptionParameters

            It 'Throws a DSCModuleNotFoundError Exception' {
                { Set-LabVMDSCMOFFile -Configuration $Config -VM $VM } | Should Throw $Exception
            }
            It 'Calls Mocked commands' {
                Assert-MockCalled Create-LabVMPath -Exactly 1
                Assert-MockCalled Get-Module -Exactly 1
                Assert-MockCalled Get-ModulesInDSCConfig -Exactly 1
                Assert-MockCalled Find-Module -Exactly 1
                Assert-MockCalled Install-Module -Exactly 1
            }
        }

        Mock Test-Path `
            -ParameterFilter { $Path -like '*TestModule' } `
            -MockWith { $true }
        Mock Copy-Item
        Mock Get-LabVMCertificate
        
        Context 'Certificate Create Failed' {
            $VM = $VMS[0].Clone()
            $ExceptionParameters = @{
                errorId = 'CertificateCreateError'
                errorCategory = 'InvalidArgument'
                errorMessage = $($LocalizedData.CertificateCreateError `
                    -f $VM.Name)
            }
            $Exception = New-Exception @ExceptionParameters

            It 'Throws a CertificateCreateError Exception' {
                { Set-LabVMDSCMOFFile -Configuration $Config -VM $VM } | Should Throw $Exception
            }
            It 'Calls Mocked commands' {
                Assert-MockCalled Create-LabVMPath -Exactly 1
                Assert-MockCalled Get-Module -Exactly 1
                Assert-MockCalled Get-ModulesInDSCConfig -Exactly 1
                Assert-MockCalled Find-Module -Exactly 1
                Assert-MockCalled Install-Module -Exactly 1
                Assert-MockCalled Copy-Item -Exactly 1
                Assert-MockCalled Get-LabVMCertificate -Exactly 1
            }
        }

        Mock Get-LabVMCertificate -MockWith { $true }
        Mock Import-Certificate
        Mock Get-ChildItem `
            -ParameterFilter { $path -eq 'cert:\LocalMachine\My' } `
            -MockWith { @{ 
                FriendlyName = 'DSC Credential Encryption'
                Thumbprint = '1FE3BA1B6DBE84FCDF675A1C944A33A55FD4B872'	
            } }
        Mock Remove-Item
        Mock ConfigLCM
        
        Context 'Meta MOF Create Failed' {
            $VM = $VMS[0].Clone()
            $ExceptionParameters = @{
                errorId = 'DSCConfigMetaMOFCreateError'
                errorCategory = 'InvalidArgument'
                errorMessage = $($LocalizedData.DSCConfigMetaMOFCreateError `
                    -f $VM.Name)
            }
            $Exception = New-Exception @ExceptionParameters

            It 'Throws a DSCConfigMetaMOFCreateError Exception' {
                { Set-LabVMDSCMOFFile -Configuration $Config -VM $VM } | Should Throw $Exception
            }
            It 'Calls Mocked commands' {
                Assert-MockCalled Create-LabVMPath -Exactly 1
                Assert-MockCalled Get-Module -Exactly 1
                Assert-MockCalled Get-ModulesInDSCConfig -Exactly 1
                Assert-MockCalled Find-Module -Exactly 1
                Assert-MockCalled Install-Module -Exactly 1
                Assert-MockCalled Copy-Item -Exactly 1
                Assert-MockCalled Get-LabVMCertificate -Exactly 1
                Assert-MockCalled Import-Certificate -Exactly 1			
                Assert-MockCalled Get-ChildItem -ParameterFilter { $path -eq 'cert:\LocalMachine\My' } -Exactly 1
                Assert-MockCalled Remove-Item
                Assert-MockCalled ConfigLCM -Exactly 1
            }
        }
    }



    Describe 'Set-LabVMDSCStartFile' {

        Mock Get-VM

        $Config = Get-LabConfiguration -Path $Global:TestConfigOKPath
        [Array]$Switches = Get-LabSwitches -Configuration $Config
        [Array]$Templates = Get-LabVMTemplates -Configuration $Config
        [Array]$VMs = Get-LabVMs -Configuration $Config -VMTemplates $Templates -Switches $Switches

        Mock Get-VMNetworkAdapter

        Context 'Network Adapter does not Exist' {
            $VM = $VMS[0].Clone()
            $VM.Adapters[0].Name = 'DoesNotExist'
            $ExceptionParameters = @{
                errorId = 'NetworkAdapterNotFoundError'
                errorCategory = 'InvalidArgument'
                errorMessage = $($LocalizedData.NetworkAdapterNotFoundError `
                    -f 'DoesNotExist',$VMS[0].Name)
            }
            $Exception = New-Exception @ExceptionParameters
            It 'Throws a NetworkAdapterNotFoundError Exception' {
                { Set-LabVMDSCStartFile -Configuration $Config -VM $VM } | Should Throw $Exception
            }
            It 'Calls Mocked commands' {
                Assert-MockCalled Get-VMNetworkAdapter -Exactly 1
            }
        }

        Mock Get-VMNetworkAdapter -MockWith { @{ Name = 'Exists'; MacAddress = '' }}

        Context 'Network Adapter has blank MAC Address' {
            $VM = $VMS[0].Clone()
            $VM.Adapters[0].Name = 'Exists'
            $ExceptionParameters = @{
                errorId = 'NetworkAdapterBlankMacError'
                errorCategory = 'InvalidArgument'
                errorMessage = $($LocalizedData.NetworkAdapterBlankMacError `
                    -f 'Exists',$VMS[0].Name)
            }
            $Exception = New-Exception @ExceptionParameters

            It 'Throws a NetworkAdapterBlankMacError Exception' {
                { Set-LabVMDSCStartFile -Configuration $Config -VM $VM } | Should Throw $Exception
            }
            It 'Calls Mocked commands' {
                Assert-MockCalled Get-VMNetworkAdapter -Exactly 1
            }
        }

        Mock Get-VMNetworkAdapter -MockWith { @{ Name = 'Exists'; MacAddress = '111111111111' }}
        Mock Set-Content
        
        Context 'Valid Configuration Passed' {
            $VM = $VMS[0].Clone()
            
            It 'Does Not Throw Exception' {
                { Set-LabVMDSCStartFile -Configuration $Config -VM $VM } | Should Not Throw
            }
            It 'Calls Mocked commands' {
                Assert-MockCalled Get-VMNetworkAdapter -Exactly ($VM.Adapters.Count+1)
                Assert-MockCalled Set-Content -Exactly 2
            }
        }
    }



    Describe 'Initialize-LabVMDSC' {

        Mock Get-VM

        $Config = Get-LabConfiguration -Path $Global:TestConfigOKPath
        [Array]$Switches = Get-LabSwitches -Configuration $Config
        [Array]$Templates = Get-LabVMTemplates -Configuration $Config
        [Array]$VMs = Get-LabVMs -Configuration $Config -VMTemplates $Templates -Switches $Switches

        Mock Set-LabVMDSCMOFFile
        Mock Set-LabVMDSCStartFile

        Context 'Valid Configuration Passed' {
            $VM = $VMS[0].Clone()
            
            It 'Does Not Throw Exception' {
                { Initialize-LabVMDSC -Configuration $Config -VM $VM } | Should Not Throw
            }
            It 'Calls Mocked commands' {
                Assert-MockCalled Set-LabVMDSCMOFFile -Exactly 1
                Assert-MockCalled Set-LabVMDSCStartFile -Exactly 1
            }
        }
    }



    Describe 'Start-LabVMDSC' -Tags 'Incomplete' {

        Mock Get-VM

        $Config = Get-LabConfiguration -Path $Global:TestConfigOKPath
        [Array]$Switches = Get-LabSwitches -Configuration $Config
        [Array]$Templates = Get-LabVMTemplates -Configuration $Config
        [Array]$VMs = Get-LabVMs -Configuration $Config -VMTemplates $Templates -Switches $Switches

    }



    Describe 'Get-LabUnattendFile' -Tags 'Incomplete' {

        Mock Get-VM

        Context 'Valid Parameters Passed' {
            $Config = Get-LabConfiguration -Path $Global:TestConfigOKPath
            [Array]$Switches = Get-LabSwitches -Configuration $Config
            [Array]$Templates = Get-LabVMTemplates -Configuration $Config
            [Array]$VMs = Get-LabVMs -Configuration $Config -VMTemplates $Templates -Switches $Switches
            [String]$UnattendFile = Get-LabUnattendFile -Configuration $Config -VM $VMs[0]
            Set-Content -Path "$($Global:ArtifactPath)\UnattendFile.xml" -Value $UnattendFile -Encoding UTF8 -NoNewLine
            It 'Returns Expected File Content' {
                $UnattendFile | Should Be $True
                $ExpectedUnattendFile = Get-Content -Path "$Global:TestConfigPath\ExpectedUnattendFile.xml" -Raw
                [String]::Compare($UnattendFile,$ExpectedUnattendFile,$true) | Should Be 0
            }
        }
    }



    Describe 'Set-LabVMInitializationFiles' -Tags 'Incomplete' {

        #region Mocks
        Mock Get-VM
        Mock Mount-WindowsImage
        Mock Dismount-WindowsImage
        Mock Invoke-WebRequest
        Mock Add-WindowsPackage
        Mock Set-Content
        Mock Copy-Item
        #endregion

        Context 'Valid configuration is passed' {	
            $Config = Get-LabConfiguration -Path $Global:TestConfigOKPath
            New-Item -Path $Config.labbuilderconfig.settings.vmpath -ItemType Directory -Force -ErrorAction SilentlyContinue
            New-Item -Path $Config.labbuilderconfig.settings.vhdparentpath -ItemType Directory -Force -ErrorAction SilentlyContinue

            [Array]$Templates = Get-LabVMTemplates -Configuration $Config
            [Array]$Switches = Get-LabSwitches -Configuration $Config
            [Array]$VMs = Get-LabVMs -Configuration $Config -VMTemplates $Templates -Switches $Switches
                    
            It 'Returns True' {
                Set-LabVMInitializationFiles -Configuration $Config -VM $VMs[0] -VMBootDiskPath 'c:\Dummy\' | Should Be $True
            }
            It 'Calls Mocked commands' {
                Assert-MockCalled Mount-WindowsImage -Exactly 1
                Assert-MockCalled Dismount-WindowsImage -Exactly 1
                Assert-MockCalled Invoke-WebRequest -Exactly 1
                Assert-MockCalled Add-WindowsPackage -Exactly 1
                Assert-MockCalled Set-Content -Exactly 6
                Assert-MockCalled Copy-Item -Exactly 1
            }

            Remove-Item -Path $Config.labbuilderconfig.settings.vmpath -Recurse -Force -ErrorAction SilentlyContinue
            Remove-Item -Path $Config.labbuilderconfig.settings.vhdparentpath -Recurse -Force -ErrorAction SilentlyContinue
        }
    }



    Describe 'Get-LabVMs' {

        #region mocks
        Mock Get-VM
        #endregion

        Context 'Configuration passed with VM missing VM Name.' {
            It 'Throw VMNameError Exception' {
                $Config = Get-LabConfiguration -Path $Global:TestConfigOKPath
                $Config.labbuilderconfig.vms.vm.RemoveAttribute('name')
                [Array]$Switches = Get-LabSwitches -Configuration $Config
                [array]$Templates = Get-LabVMTemplates -Configuration $Config
                $ExceptionParameters = @{
                    errorId = 'VMNameError'
                    errorCategory = 'InvalidArgument'
                    errorMessage = $($LocalizedData.VMNameError)
                }
                $Exception = New-Exception @ExceptionParameters
                { Get-LabVMs -Configuration $Config -VMTemplates $Templates -Switches $Switches } | Should Throw $Exception
            }
        }
        Context 'Configuration passed with VM missing Template.' {
            It 'Throw VMTemplateNameEmptyError Exception' {
                $Config = Get-LabConfiguration -Path $Global:TestConfigOKPath
                $Config.labbuilderconfig.vms.vm.RemoveAttribute('template')
                [Array]$Switches = Get-LabSwitches -Configuration $Config
                [array]$Templates = Get-LabVMTemplates -Configuration $Config
                $ExceptionParameters = @{
                    errorId = 'VMTemplateNameEmptyError'
                    errorCategory = 'InvalidArgument'
                    errorMessage = $($LocalizedData.VMTemplateNameEmptyError `
                        -f $Config.labbuilderconfig.vms.vm.name)
                }
                $Exception = New-Exception @ExceptionParameters
                { Get-LabVMs -Configuration $Config -VMTemplates $Templates -Switches $Switches } | Should Throw $Exception
            }
        }
        Context 'Configuration passed with VM invalid Template Name.' {
            It 'Throw VMTemplateNotFoundError Exception' {
                $Config = Get-LabConfiguration -Path $Global:TestConfigOKPath
                $Config.labbuilderconfig.vms.vm.template = 'BadTemplate'
                [Array]$Switches = Get-LabSwitches -Configuration $Config
                [array]$Templates = Get-LabVMTemplates -Configuration $Config
                $ExceptionParameters = @{
                    errorId = 'VMTemplateNotFoundError'
                    errorCategory = 'InvalidArgument'
                    errorMessage = $($LocalizedData.VMTemplateNotFoundError `
                        -f $Config.labbuilderconfig.vms.vm.name,'BadTemplate')
                }
                $Exception = New-Exception @ExceptionParameters
                { Get-LabVMs -Configuration $Config -VMTemplates $Templates -Switches $Switches } | Should Throw $Exception
            }
        }
        Context 'Configuration passed with VM missing adapter name.' {
            It 'Throw VMAdapterNameError Exception' {
                $Config = Get-LabConfiguration -Path $Global:TestConfigOKPath
                $Config.labbuilderconfig.vms.vm.adapters.adapter[0].RemoveAttribute('name')
                [Array]$Switches = Get-LabSwitches -Configuration $Config
                [array]$Templates = Get-LabVMTemplates -Configuration $Config
                $ExceptionParameters = @{
                    errorId = 'VMAdapterNameError'
                    errorCategory = 'InvalidArgument'
                    errorMessage = $($LocalizedData.VMAdapterNameError `
                        -f $Config.labbuilderconfig.vms.vm.name)
                }
                $Exception = New-Exception @ExceptionParameters
                { Get-LabVMs -Configuration $Config -VMTemplates $Templates -Switches $Switches } | Should Throw $Exception
            }
        }
        Context 'Configuration passed with VM missing adapter switch name.' {
            It 'Throw VMAdapterSwitchNameError Exception' {
                $Config = Get-LabConfiguration -Path $Global:TestConfigOKPath
                $Config.labbuilderconfig.vms.vm.adapters.adapter[0].RemoveAttribute('switchname')
                [Array]$Switches = Get-LabSwitches -Configuration $Config
                [array]$Templates = Get-LabVMTemplates -Configuration $Config
                $ExceptionParameters = @{
                    errorId = 'VMAdapterSwitchNameError'
                    errorCategory = 'InvalidArgument'
                    errorMessage = $($LocalizedData.VMAdapterSwitchNameError `
                        -f $Config.labbuilderconfig.vms.vm.name,$Config.labbuilderconfig.vms.vm.adapters.adapter[0].name)
                }
                $Exception = New-Exception @ExceptionParameters
                { Get-LabVMs -Configuration $Config -VMTemplates $Templates -Switches $Switches } | Should Throw $Exception
            }
        }
        Context 'Configuration passed with VM Data Disk with empty VHD.' {
            It 'Throw VMDataDiskVHDEmptyError Exception' {
                $Config = Get-LabConfiguration -Path $Global:TestConfigOKPath
                $Config.labbuilderconfig.vms.vm.datavhds.datavhd[0].vhd = ''
                [Array]$Switches = Get-LabSwitches -Configuration $Config
                [array]$Templates = Get-LabVMTemplates -Configuration $Config
                $ExceptionParameters = @{
                    errorId = 'VMDataDiskVHDEmptyError'
                    errorCategory = 'InvalidArgument'
                    errorMessage = $($LocalizedData.VMDataDiskVHDEmptyError `
                        -f $Config.labbuilderconfig.vms.vm.name)
                }
                $Exception = New-Exception @ExceptionParameters
                { Get-LabVMs -Configuration $Config -VMTemplates $Templates -Switches $Switches } | Should Throw $Exception
            }
        }
        Context "Configuration passed with VM Data Disk where ParentVHD can't be found." {
            It 'Throw VMDataDiskParentVHDNotFoundError Exception' {
                $Config = Get-LabConfiguration -Path $Global:TestConfigOKPath
                $Config.labbuilderconfig.vms.vm.datavhds.datavhd[3].parentvhd = 'c:\ThisFileDoesntExist.vhdx'
                [Array]$Switches = Get-LabSwitches -Configuration $Config
                [array]$Templates = Get-LabVMTemplates -Configuration $Config
                $ExceptionParameters = @{
                    errorId = 'VMDataDiskParentVHDNotFoundError'
                    errorCategory = 'InvalidArgument'
                    errorMessage = $($LocalizedData.VMDataDiskParentVHDNotFoundError `
                        -f $Config.labbuilderconfig.vms.vm.name,"c:\ThisFileDoesntExist.vhdx")
                }
                $Exception = New-Exception @ExceptionParameters
                { Get-LabVMs -Configuration $Config -VMTemplates $Templates -Switches $Switches } | Should Throw $Exception
            }
        }
        Context "Configuration passed with VM Data Disk where SourceVHD can't be found." {
            It 'Throw VMDataDiskSourceVHDNotFoundError Exception' {
                $Config = Get-LabConfiguration -Path $Global:TestConfigOKPath
                $Config.labbuilderconfig.vms.vm.datavhds.datavhd[0].sourcevhd = 'c:\ThisFileDoesntExist.vhdx'
                [Array]$Switches = Get-LabSwitches -Configuration $Config
                [array]$Templates = Get-LabVMTemplates -Configuration $Config
                $ExceptionParameters = @{
                    errorId = 'VMDataDiskSourceVHDNotFoundError'
                    errorCategory = 'InvalidArgument'
                    errorMessage = $($LocalizedData.VMDataDiskSourceVHDNotFoundError `
                        -f $Config.labbuilderconfig.vms.vm.name,"c:\ThisFileDoesntExist.vhdx")
                }
                $Exception = New-Exception @ExceptionParameters
                { Get-LabVMs -Configuration $Config -VMTemplates $Templates -Switches $Switches } | Should Throw $Exception
            }
        }
        Context "Configuration passed with VM Differencing Data Disk with empty ParentVHD." {
            It 'Throw VMDataDiskParentVHDMissingError Exception' {
                $Config = Get-LabConfiguration -Path $Global:TestConfigOKPath
                $Config.labbuilderconfig.vms.vm.datavhds.datavhd[3].RemoveAttribute('parentvhd')
                [Array]$Switches = Get-LabSwitches -Configuration $Config
                [array]$Templates = Get-LabVMTemplates -Configuration $Config
                $ExceptionParameters = @{
                    errorId = 'VMDataDiskParentVHDMissingError'
                    errorCategory = 'InvalidArgument'
                    errorMessage = $($LocalizedData.VMDataDiskParentVHDMissingError `
                        -f $Config.labbuilderconfig.vms.vm.name)
                }
                $Exception = New-Exception @ExceptionParameters
                { Get-LabVMs -Configuration $Config -VMTemplates $Templates -Switches $Switches } | Should Throw $Exception
            }
        }
        Context "Configuration passed with VM Data Disk where it is a Differencing type disk but is shared." {
            It 'Throw VMDataDiskSharedDifferencingError Exception' {
                $Config = Get-LabConfiguration -Path $Global:TestConfigOKPath
                $Config.labbuilderconfig.vms.vm.datavhds.datavhd[3].SetAttribute('Shared','Y')
                [Array]$Switches = Get-LabSwitches -Configuration $Config
                [array]$Templates = Get-LabVMTemplates -Configuration $Config
                $ExceptionParameters = @{
                    errorId = 'VMDataDiskSharedDifferencingError'
                    errorCategory = 'InvalidArgument'
                    errorMessage = $($LocalizedData.VMDataDiskSharedDifferencingError `
                        -f $Config.labbuilderconfig.vms.vm.name,"$($Config.labbuilderconfig.settings.vmpath)\$($Config.labbuilderconfig.vms.vm.name)\Virtual Hard Disks\$($Config.labbuilderconfig.vms.vm.datavhds.datavhd[3].vhd)")
                }
                $Exception = New-Exception @ExceptionParameters
                { Get-LabVMs -Configuration $Config -VMTemplates $Templates -Switches $Switches } | Should Throw $Exception
            }
        }
        Context "Configuration passed with VM Data Disk where it has an unknown Type." {
            It 'Throw VMDataDiskUnknownTypeError Exception' {
                $Config = Get-LabConfiguration -Path $Global:TestConfigOKPath
                $Config.labbuilderconfig.vms.vm.datavhds.datavhd[1].type = 'badtype'
                [Array]$Switches = Get-LabSwitches -Configuration $Config
                [array]$Templates = Get-LabVMTemplates -Configuration $Config
                $ExceptionParameters = @{
                    errorId = 'VMDataDiskUnknownTypeError'
                    errorCategory = 'InvalidArgument'
                    errorMessage = $($LocalizedData.VMDataDiskUnknownTypeError `
                        -f $Config.labbuilderconfig.vms.vm.name,"$($Config.labbuilderconfig.settings.vmpath)\$($Config.labbuilderconfig.vms.vm.name)\Virtual Hard Disks\$($Config.labbuilderconfig.vms.vm.datavhds.datavhd[1].vhd)",'badtype')
                }
                $Exception = New-Exception @ExceptionParameters
                { Get-LabVMs -Configuration $Config -VMTemplates $Templates -Switches $Switches } | Should Throw $Exception
            }
        }
        Context "Configuration passed with VM Data Disk is not Shared but SupportPR is Y." {
            It 'Throw VMDataDiskSupportPRError Exception' {
                $Config = Get-LabConfiguration -Path $Global:TestConfigOKPath
                $Config.labbuilderconfig.vms.vm.datavhds.datavhd[1].supportpr = 'Y'
                [Array]$Switches = Get-LabSwitches -Configuration $Config
                [array]$Templates = Get-LabVMTemplates -Configuration $Config
                $ExceptionParameters = @{
                    errorId = 'VMDataDiskSupportPRError'
                    errorCategory = 'InvalidArgument'
                    errorMessage = $($LocalizedData.VMDataDiskSupportPRError `
                        -f $Config.labbuilderconfig.vms.vm.name,"$($Config.labbuilderconfig.settings.vmpath)\$($Config.labbuilderconfig.vms.vm.name)\Virtual Hard Disks\$($Config.labbuilderconfig.vms.vm.datavhds.datavhd[1].vhd)")
                }
                $Exception = New-Exception @ExceptionParameters
                { Get-LabVMs -Configuration $Config -VMTemplates $Templates -Switches $Switches } | Should Throw $Exception
            }
        }        
        Context "Configuration passed with VM Data Disk that does not exist but Type missing." {
            It 'Throw VMDataDiskCantBeCreatedError Exception' {
                $Config = Get-LabConfiguration -Path $Global:TestConfigOKPath
                $Config.labbuilderconfig.vms.vm.datavhds.datavhd[1].RemoveAttribute('type')
                [Array]$Switches = Get-LabSwitches -Configuration $Config
                [array]$Templates = Get-LabVMTemplates -Configuration $Config
                $ExceptionParameters = @{
                    errorId = 'VMDataDiskCantBeCreatedError'
                    errorCategory = 'InvalidArgument'
                    errorMessage = $($LocalizedData.VMDataDiskCantBeCreatedError `
                        -f $Config.labbuilderconfig.vms.vm.name,"$($Config.labbuilderconfig.settings.vmpath)\$($Config.labbuilderconfig.vms.vm.name)\Virtual Hard Disks\$($Config.labbuilderconfig.vms.vm.datavhds.datavhd[1].vhd)")
                }
                $Exception = New-Exception @ExceptionParameters
                { Get-LabVMs -Configuration $Config -VMTemplates $Templates -Switches $Switches } | Should Throw $Exception
            }
        }
        Context "Configuration passed with VM Data Disk that does not exist but Size missing." {
            It 'Throw VMDataDiskCantBeCreatedError Exception' {
                $Config = Get-LabConfiguration -Path $Global:TestConfigOKPath
                $Config.labbuilderconfig.vms.vm.datavhds.datavhd[1].RemoveAttribute('size')
                [Array]$Switches = Get-LabSwitches -Configuration $Config
                [array]$Templates = Get-LabVMTemplates -Configuration $Config
                $ExceptionParameters = @{
                    errorId = 'VMDataDiskCantBeCreatedError'
                    errorCategory = 'InvalidArgument'
                    errorMessage = $($LocalizedData.VMDataDiskCantBeCreatedError `
                        -f $Config.labbuilderconfig.vms.vm.name,"$($Config.labbuilderconfig.settings.vmpath)\$($Config.labbuilderconfig.vms.vm.name)\Virtual Hard Disks\$($Config.labbuilderconfig.vms.vm.datavhds.datavhd[1].vhd)")
                }
                $Exception = New-Exception @ExceptionParameters
                { Get-LabVMs -Configuration $Config -VMTemplates $Templates -Switches $Switches } | Should Throw $Exception
            }
        }
        Context "Configuration passed with VM Data Disk that does not exist but SourceVHD missing." {
            It 'Throw VMDataDiskCantBeCreatedError Exception' {
                $Config = Get-LabConfiguration -Path $Global:TestConfigOKPath
                $Config.labbuilderconfig.vms.vm.datavhds.datavhd[0].RemoveAttribute('sourcevhd')
                [Array]$Switches = Get-LabSwitches -Configuration $Config
                [array]$Templates = Get-LabVMTemplates -Configuration $Config
                $ExceptionParameters = @{
                    errorId = 'VMDataDiskCantBeCreatedError'
                    errorCategory = 'InvalidArgument'
                    errorMessage = $($LocalizedData.VMDataDiskCantBeCreatedError `
                        -f $Config.labbuilderconfig.vms.vm.name,"$($Config.labbuilderconfig.settings.vmpath)\$($Config.labbuilderconfig.vms.vm.name)\Virtual Hard Disks\$($Config.labbuilderconfig.vms.vm.datavhds.datavhd[0].vhd)")
                }
                $Exception = New-Exception @ExceptionParameters
                { Get-LabVMs -Configuration $Config -VMTemplates $Templates -Switches $Switches } | Should Throw $Exception
            }
        }
        Context "Configuration passed with VM Data Disk that has MoveSourceVHD flag but SourceVHD missing." {
            It 'Throw VMDataDiskSourceVHDIfMoveError Exception' {
                $Config = Get-LabConfiguration -Path $Global:TestConfigOKPath
                $Config.labbuilderconfig.vms.vm.datavhds.datavhd[4].RemoveAttribute('sourcevhd')
                [Array]$Switches = Get-LabSwitches -Configuration $Config
                [array]$Templates = Get-LabVMTemplates -Configuration $Config
                $ExceptionParameters = @{
                    errorId = 'VMDataDiskSourceVHDIfMoveError'
                    errorCategory = 'InvalidArgument'
                    errorMessage = $($LocalizedData.VMDataDiskSourceVHDIfMoveError `
                        -f $Config.labbuilderconfig.vms.vm.name,"$($Config.labbuilderconfig.settings.vmpath)\$($Config.labbuilderconfig.vms.vm.name)\Virtual Hard Disks\$($Config.labbuilderconfig.vms.vm.datavhds.datavhd[4].vhd)")
                }
                $Exception = New-Exception @ExceptionParameters
                { Get-LabVMs -Configuration $Config -VMTemplates $Templates -Switches $Switches } | Should Throw $Exception
            }
        }
        Context "Configuration passed with VM unattend file that can't be found." {
            It 'Throw UnattendFileMissingError Exception' {
                $Config = Get-LabConfiguration -Path $Global:TestConfigOKPath
                $Config.labbuilderconfig.vms.vm.unattendfile = 'ThisFileDoesntExist.xml'
                [Array]$Switches = Get-LabSwitches -Configuration $Config
                [array]$Templates = Get-LabVMTemplates -Configuration $Config
                $ExceptionParameters = @{
                    errorId = 'UnattendFileMissingError'
                    errorCategory = 'InvalidArgument'
                    errorMessage = $($LocalizedData.UnattendFileMissingError `
                        -f $Config.labbuilderconfig.vms.vm.name,"$Global:TestConfigPath\ThisFileDoesntExist.xml")
                }
                $Exception = New-Exception @ExceptionParameters
                { Get-LabVMs -Configuration $Config -VMTemplates $Templates -Switches $Switches } | Should Throw $Exception
            }
        }
        Context "Configuration passed with VM setup complete file that can't be found." {
            It 'Throw SetupCompleteFileMissingError Exception' {
                $Config = Get-LabConfiguration -Path $Global:TestConfigOKPath
                $Config.labbuilderconfig.vms.vm.setupcomplete = 'ThisFileDoesntExist.ps1'
                [Array]$Switches = Get-LabSwitches -Configuration $Config
                [array]$Templates = Get-LabVMTemplates -Configuration $Config
                $ExceptionParameters = @{
                    errorId = 'SetupCompleteFileMissingError'
                    errorCategory = 'InvalidArgument'
                    errorMessage = $($LocalizedData.SetupCompleteFileMissingError `
                        -f $Config.labbuilderconfig.vms.vm.name,"$Global:TestConfigPath\ThisFileDoesntExist.ps1")
                }
                $Exception = New-Exception @ExceptionParameters
                { Get-LabVMs -Configuration $Config -VMTemplates $Templates -Switches $Switches } | Should Throw $Exception
            }
        }
        Context 'Configuration passed with VM setup complete file with an invalid file extension.' {
            It 'Throw SetupCompleteFileBadTypeError Exception' {
                $Config = Get-LabConfiguration -Path $Global:TestConfigOKPath
                $Config.labbuilderconfig.vms.vm.setupcomplete = 'ThisFileDoesntExist.abc'
                [Array]$Switches = Get-LabSwitches -Configuration $Config
                [array]$Templates = Get-LabVMTemplates -Configuration $Config
                $ExceptionParameters = @{
                    errorId = 'SetupCompleteFileBadTypeError'
                    errorCategory = 'InvalidArgument'
                    errorMessage = $($LocalizedData.SetupCompleteFileBadTypeError `
                        -f $Config.labbuilderconfig.vms.vm.name,"$Global:TestConfigPath\ThisFileDoesntExist.abc")
                }
                $Exception = New-Exception @ExceptionParameters
                { Get-LabVMs -Configuration $Config -VMTemplates $Templates -Switches $Switches } | Should Throw $Exception
            }
        }
        Context "Configuration passed with VM DSC Config File that can't be found." {
            It 'Throw DSCConfigFileMissingError Exception' {
                $Config = Get-LabConfiguration -Path $Global:TestConfigOKPath
                $Config.labbuilderconfig.vms.vm.dsc.configfile = 'ThisFileDoesntExist.ps1'
                [Array]$Switches = Get-LabSwitches -Configuration $Config
                [array]$Templates = Get-LabVMTemplates -Configuration $Config
                $ExceptionParameters = @{
                    errorId = 'DSCConfigFileMissingError'
                    errorCategory = 'InvalidArgument'
                    errorMessage = $($LocalizedData.DSCConfigFileMissingError `
                        -f $Config.labbuilderconfig.vms.vm.name,"$Global:TestConfigPath\ThisFileDoesntExist.ps1")
                }
                $Exception = New-Exception @ExceptionParameters
                { Get-LabVMs -Configuration $Config -VMTemplates $Templates -Switches $Switches } | Should Throw $Exception
            }
        }
        Context 'Configuration passed with VM DSC Config File with an invalid file extension.' {
            It 'Throw DSCConfigFileBadTypeError Exception' {
                $Config = Get-LabConfiguration -Path $Global:TestConfigOKPath
                $Config.labbuilderconfig.vms.vm.dsc.configfile = 'FileWithBadType.xyz'
                [Array]$Switches = Get-LabSwitches -Configuration $Config
                [array]$Templates = Get-LabVMTemplates -Configuration $Config
                $ExceptionParameters = @{
                    errorId = 'DSCConfigFileBadTypeError'
                    errorCategory = 'InvalidArgument'
                    errorMessage = $($LocalizedData.DSCConfigFileBadTypeError `
                        -f $Config.labbuilderconfig.vms.vm.name,"$Global:TestConfigPath\FileWithBadType.xyz")
                }
                $Exception = New-Exception @ExceptionParameters
                { Get-LabVMs -Configuration $Config -VMTemplates $Templates -Switches $Switches } | Should Throw $Exception
            }
        }
        Context 'Configuration passed with VM DSC Config File but no DSC Name.' {
            It 'Throw DSCConfigNameIsEmptyError Exception' {
                $Config = Get-LabConfiguration -Path $Global:TestConfigOKPath
                $Config.labbuilderconfig.vms.vm.dsc.configname = ''
                [Array]$Switches = Get-LabSwitches -Configuration $Config
                [Array]$Templates = Get-LabVMTemplates -Configuration $Config
                $ExceptionParameters = @{
                    errorId = 'DSCConfigNameIsEmptyError'
                    errorCategory = 'InvalidArgument'
                    errorMessage = $($LocalizedData.DSCConfigNameIsEmptyError `
                        -f $Config.labbuilderconfig.vms.vm.name)
                }
                $Exception = New-Exception @ExceptionParameters
                { Get-LabVMs -Configuration $Config -VMTemplates $Templates -Switches $Switches } | Should Throw $Exception
            }
        }
        Context 'Valid configuration is passed with VM Data Disk with rooted VHD path.' {
            $Config = Get-LabConfiguration -Path $Global:TestConfigOKPath
            $Config.labbuilderconfig.vms.vm.datavhds.datavhd[0].vhd = "$Global:TestConfigPath\DataDisk.vhdx"
            [Array]$Switches = Get-LabSwitches -Configuration $Config
            [Array]$Templates = Get-LabVMTemplates -Configuration $Config
            [Array]$VMs = Get-LabVMs -Configuration $Config -VMTemplates $Templates -Switches $Switches
            It 'Returns Template Object containing VHD with correct rooted path' {
                $VMs[0].DataVhds[0].vhd | Should Be "$Global:TestConfigPath\DataDisk.vhdx"
            }
        }
        Context 'Valid configuration is passed with VM Data Disk with non-rooted VHD path.' {
            $Config = Get-LabConfiguration -Path $Global:TestConfigOKPath
            $Config.labbuilderconfig.vms.vm.datavhds.datavhd[0].vhd = "DataDisk.vhdx"
            [Array]$Switches = Get-LabSwitches -Configuration $Config
            [Array]$Templates = Get-LabVMTemplates -Configuration $Config
            [Array]$VMs = Get-LabVMs -Configuration $Config -VMTemplates $Templates -Switches $Switches
            It 'Returns Template Object containing VHD with correct rooted path' {
                $VMs[0].DataVhds[0].vhd | Should Be "$($Config.labbuilderconfig.settings.vmpath)\$($Config.labbuilderconfig.vms.vm.name)\Virtual Hard Disks\DataDisk.vhdx"
            }
        }
        Context 'Valid configuration is passed with VM Data Disk with rooted Parent VHD path.' {
            $Config = Get-LabConfiguration -Path $Global:TestConfigOKPath
            $Config.labbuilderconfig.vms.vm.datavhds.datavhd[3].parentvhd = "$Global:TestConfigPath\DataDisk.vhdx"
            [Array]$Switches = Get-LabSwitches -Configuration $Config
            [Array]$Templates = Get-LabVMTemplates -Configuration $Config
            [Array]$VMs = Get-LabVMs -Configuration $Config -VMTemplates $Templates -Switches $Switches
            It 'Returns Template Object containing Parent VHD with correct rooted path' {
                $VMs[0].DataVhds[3].parentvhd | Should Be "$Global:TestConfigPath\DataDisk.vhdx"
            }
        }
        Context 'Valid configuration is passed with VM Data Disk with non-rooted Parent VHD path.' {
            Mock Test-Path -MockWith { $true }
            $Config = Get-LabConfiguration -Path $Global:TestConfigOKPath
            $Config.labbuilderconfig.vms.vm.datavhds.datavhd[3].parentvhd = "DataDisk.vhdx"
            [Array]$Switches = Get-LabSwitches -Configuration $Config
            [Array]$Templates = Get-LabVMTemplates -Configuration $Config
            [Array]$VMs = Get-LabVMs -Configuration $Config -VMTemplates $Templates -Switches $Switches
            It 'Returns Template Object containing Parent VHD with correct rooted path' {
                $VMs[0].DataVhds[3].parentvhd | Should Be "$Global:TestConfigPath\DataDisk.vhdx"
            }
        }
        Context 'Valid configuration is passed with VM Data Disk with rooted Source VHD path.' {
            $Config = Get-LabConfiguration -Path $Global:TestConfigOKPath
            $Config.labbuilderconfig.vms.vm.datavhds.datavhd[0].sourcevhd = "$Global:TestConfigPath\DataDisk.vhdx"
            [Array]$Switches = Get-LabSwitches -Configuration $Config
            [Array]$Templates = Get-LabVMTemplates -Configuration $Config
            [Array]$VMs = Get-LabVMs -Configuration $Config -VMTemplates $Templates -Switches $Switches
            It 'Returns Template Object containing Source VHD with correct rooted path' {
                $VMs[0].DataVhds[0].sourcevhd | Should Be "$Global:TestConfigPath\DataDisk.vhdx"
            }
        }
        Context 'Valid configuration is passed with VM Data Disk with non-rooted Source VHD path.' {
            Mock Test-Path -MockWith { $true }
            $Config = Get-LabConfiguration -Path $Global:TestConfigOKPath
            $Config.labbuilderconfig.vms.vm.datavhds.datavhd[0].sourcevhd = "DataDisk.vhdx"
            [Array]$Switches = Get-LabSwitches -Configuration $Config
            [Array]$Templates = Get-LabVMTemplates -Configuration $Config
            [Array]$VMs = Get-LabVMs -Configuration $Config -VMTemplates $Templates -Switches $Switches
            It 'Returns Template Object containing Source VHD with correct rooted path' {
                $VMs[0].DataVhds[0].sourcevhd | Should Be "$Global:TestConfigPath\DataDisk.vhdx"
            }
        }
        Context 'Valid configuration is passed' {
            $Config = Get-LabConfiguration -Path $Global:TestConfigOKPath
            [Array]$Switches = Get-LabSwitches -Configuration $Config
            [Array]$Templates = Get-LabVMTemplates -Configuration $Config
            [Array]$VMs = Get-LabVMs -Configuration $Config -VMTemplates $Templates -Switches $Switches
            # Remove the Source VHD and Parent VHD values for any data disks because they
            # will usually be relative to the test folder and won't exist
            foreach ($DataVhd in $VMs[0].DataVhds)
            {
                $DataVhd.ParentVHD = ''
                $DataVhd.SourceVHD = ''
            }
            # Remove the DSCConfigFile path as this will be relative as well
            $VMs[0].DSCConfigFile = ''
            It 'Returns Template Object that matches Expected Object' {
                Set-Content -Path "$Global:ArtifactPath\ExpectedVMs.json" -Value ($VMs | ConvertTo-Json -Depth 6)
                $ExpectedVMs = Get-Content -Path "$Global:TestConfigPath\ExpectedVMs.json"
                [String]::Compare((Get-Content -Path "$Global:ArtifactPath\ExpectedVMs.json"),$ExpectedVMs,$true) | Should Be 0
            }
        }        
    }



    Describe 'Get-LabVMSelfSignedCert' -Tags 'Incomplete' {
    }



    Describe 'Start-LabVM' -Tags 'Incomplete' {
        #region Mocks
        Mock Get-VM -ParameterFilter { $Name -eq 'PESTER01' } -MockWith { [PSObject]@{ Name='PESTER01'; State='Off' } }
        Mock Get-VM -ParameterFilter { $Name -eq 'pester template *' }
        Mock Start-VM
        Mock Wait-LabVMInit -MockWith { $True }
        Mock Get-LabVMSelfSignedCert -MockWith { $True }
        Mock Initialize-LabVMDSC
        Mock Start-LabVMDSC
        #endregion

        Context 'Valid configuration is passed' {	
            $Config = Get-LabConfiguration -Path $Global:TestConfigOKPath
            New-Item -Path $Config.labbuilderconfig.settings.vmpath -ItemType Directory -Force -ErrorAction SilentlyContinue
            New-Item -Path $Config.labbuilderconfig.settings.vhdparentpath -ItemType Directory -Force -ErrorAction SilentlyContinue

            [Array]$Templates = Get-LabVMTemplates -Configuration $Config
            [Array]$Switches = Get-LabSwitches -Configuration $Config
            [Array]$VMs = Get-LabVMs -Configuration $Config -VMTemplates $Templates -Switches $Switches
                    
            It 'Returns True' {
                Start-LabVM -Configuration $Config -VM $VMs[0] | Should Be $True
            }
            It 'Calls Mocked commands' {
                Assert-MockCalled Get-VM -ParameterFilter { $Name -eq 'PESTER01' } -Exactly 1
                Assert-MockCalled Get-VM -ParameterFilter { $Name -eq 'pester template *' } -Exactly 1
                Assert-MockCalled Start-VM -Exactly 1
                Assert-MockCalled Wait-LabVMInit -Exactly 1
                Assert-MockCalled Get-LabVMSelfSignedCert -Exactly 1
                Assert-MockCalled Initialize-LabVMDSC -Exactly 1
                Assert-MockCalled Start-LabVMDSC -Exactly 1
            }
            
            Remove-Item -Path $Config.labbuilderconfig.settings.vmpath -Recurse -Force -ErrorAction SilentlyContinue
            Remove-Item -Path $Config.labbuilderconfig.settings.vhdparentpath -Recurse -Force -ErrorAction SilentlyContinue
        }
    }



    Describe 'Update-LabVMDataDisk' -Tags 'InProcess' {
        #region Mocks
        Mock Get-VM
        Mock Get-VHD
        Mock Resize-VHD
        Mock Move-Item
        Mock Copy-Item
        Mock New-VHD
        Mock Get-VMHardDiskDrive
        Mock Add-VMHardDiskDrive
        Mock Test-Path -ParameterFilter { $Path -eq 'DoesNotExist.Vhdx' } -MockWith { $False }        
        Mock Test-Path -ParameterFilter { $Path -eq 'DoesExist.Vhdx' } -MockWith { $True }        
        #endregion

        # The same VM will be used for all tests, but a different
        # DataVHds array will be created/assigned for each test.
        $Config = Get-LabConfiguration -Path $Global:TestConfigOKPath
        [Array]$Templates = Get-LabVMTemplates -Configuration $Config
        [Array]$Switches = Get-LabSwitches -Configuration $Config
        [Array]$VMs = Get-LabVMs -Configuration $Config -VMTemplates $Templates -Switches $Switches

        Context 'Valid configuration is passed with no DataVHDs' {
            $VMs[0].DataVHDs = @()
            It 'Does not throw an Exception' {
                { Update-LabVMDataDisk -Configuration $Config -VM $VMs[0] } | Should Not Throw 
            }
            It 'Calls Mocked commands' {
                Assert-MockCalled Get-VHD -Exactly 0
                Assert-MockCalled Resize-VHD -Exactly 0
                Assert-MockCalled Move-Item -Exactly 0
                Assert-MockCalled Copy-Item -Exactly 0
                Assert-MockCalled New-VHD -Exactly 0
                Assert-MockCalled Get-VMHardDiskDrive -Exactly 0
                Assert-MockCalled Add-VMHardDiskDrive -Exactly 0
            }
        }
        Context 'Valid configuration is passed with a DataVHD that exists but has different type' {
            $VMs[0].DataVHDs = @( @{
                Vhd = 'DoesExist.vhdx'
                Type = 'Fixed'
                Size = 10GB
                
            } )
            Mock Get-VHD -MockWith { @{
                VhdType =  'Dynamic'
            } }
            It 'Throws VMDataDiskVHDConvertError Exception' {
                $ExceptionParameters = @{
                    errorId = 'VMDataDiskVHDConvertError'
                    errorCategory = 'InvalidArgument'
                    errorMessage = $($LocalizedData.VMDataDiskVHDConvertError `
                        -f $VMs[0].Name,$VMs[0].DataVHDs.Vhd,$VMs[0].DataVHDs.Type)
                }
                $Exception = New-Exception @ExceptionParameters
                { Update-LabVMDataDisk -Configuration $Config -VM $VMs[0] } | Should Throw 
            }
            It 'Calls Mocked commands' {
                Assert-MockCalled Get-VHD -Exactly 1
                Assert-MockCalled Resize-VHD -Exactly 0
                Assert-MockCalled Move-Item -Exactly 0
                Assert-MockCalled Copy-Item -Exactly 0
                Assert-MockCalled New-VHD -Exactly 0
                Assert-MockCalled Get-VMHardDiskDrive -Exactly 0
                Assert-MockCalled Add-VMHardDiskDrive -Exactly 0
            }
        }
        Context 'Valid configuration is passed with a DataVHD that exists but has smaller size' {
            $VMs[0].DataVHDs = @( @{
                Vhd = 'DoesExist.vhdx'
                Type = 'Fixed'
                Size = 10GB
            } )
            Mock Get-VHD -MockWith { @{
                VhdType =  'Fixed'
                Size = 20GB
            } }
            It 'Throws VMDataDiskVHDShrinkError Exception' {
                $ExceptionParameters = @{
                    errorId = 'VMDataDiskVHDShrinkError'
                    errorCategory = 'InvalidArgument'
                    errorMessage = $($LocalizedData.VMDataDiskVHDShrinkError `
                        -f $VMs[0].Name,$VMs[0].DataVHDs[0].Vhd,$VMs[0].DataVHDs[0].Size)
                }
                $Exception = New-Exception @ExceptionParameters
                { Update-LabVMDataDisk -Configuration $Config -VM $VMs[0] } | Should Throw $Exception
            }
            It 'Calls Mocked commands' {
                Assert-MockCalled Get-VHD -Exactly 1
                Assert-MockCalled Resize-VHD -Exactly 0
                Assert-MockCalled Move-Item -Exactly 0
                Assert-MockCalled Copy-Item -Exactly 0
                Assert-MockCalled New-VHD -Exactly 0
                Assert-MockCalled Get-VMHardDiskDrive -Exactly 0
                Assert-MockCalled Add-VMHardDiskDrive -Exactly 0
            }
        }
        Context 'Valid configuration is passed with a DataVHD that exists but has larger size' {
            $VMs[0].DataVHDs = @( @{
                Vhd = 'DoesExist.vhdx'
                Type = 'Fixed'
                Size = 30GB
            } )
            Mock Get-VHD -MockWith { @{
                VhdType =  'Fixed'
                Size = 20GB
            } }
            It 'Does not throw an Exception' {
                { Update-LabVMDataDisk -Configuration $Config -VM $VMs[0] } | Should Not Throw
            }
            It 'Calls Mocked commands' {
                Assert-MockCalled Get-VHD -Exactly 1
                Assert-MockCalled Resize-VHD -Exactly 1
                Assert-MockCalled Move-Item -Exactly 0
                Assert-MockCalled Copy-Item -Exactly 0
                Assert-MockCalled New-VHD -Exactly 0
                Assert-MockCalled Get-VMHardDiskDrive -Exactly 1
                Assert-MockCalled Add-VMHardDiskDrive -Exactly 1
            }
        }
        
        Mock Get-VHD
        
        Context 'Valid configuration is passed with a SourceVHD and DataVHD that do not exist' {
            $VMs[0].DataVHDs = @( @{
                Vhd = 'DoesNotExist.vhdx'
                SourceVhd = 'DoesNotExist.Vhdx'
            } )
            It 'Throws VMDataDiskSourceVHDNotFoundError Exception' {
                $ExceptionParameters = @{
                    errorId = 'VMDataDiskSourceVHDNotFoundError'
                    errorCategory = 'InvalidArgument'
                    errorMessage = $($LocalizedData.VMDataDiskSourceVHDNotFoundError `
                        -f $VMs[0].Name,$VMs[0].DataVHDs[0].SourceVhd)
                }
                $Exception = New-Exception @ExceptionParameters
                { Update-LabVMDataDisk -Configuration $Config -VM $VMs[0] } | Should Throw $Exception
            }
            It 'Calls Mocked commands' {
                Assert-MockCalled Get-VHD -Exactly 0
                Assert-MockCalled Resize-VHD -Exactly 0
                Assert-MockCalled Move-Item -Exactly 0
                Assert-MockCalled Copy-Item -Exactly 0
                Assert-MockCalled New-VHD -Exactly 0
                Assert-MockCalled Get-VMHardDiskDrive -Exactly 0
                Assert-MockCalled Add-VMHardDiskDrive -Exactly 0
            }
        }
        Context 'Valid configuration is passed with a SourceVHD that exists and DataVHD that do not exist' {
            $VMs[0].DataVHDs = @( @{
                Vhd = 'DoesNotExist.vhdx'
                SourceVhd = 'DoesExist.Vhdx'
            } )
            It 'Does not throw an Exception' {
                { Update-LabVMDataDisk -Configuration $Config -VM $VMs[0] } | Should Not Throw
            }
            It 'Calls Mocked commands' {
                Assert-MockCalled Get-VHD -Exactly 0
                Assert-MockCalled Resize-VHD -Exactly 0
                Assert-MockCalled Move-Item -Exactly 0
                Assert-MockCalled Copy-Item -Exactly 1
                Assert-MockCalled New-VHD -Exactly 0
                Assert-MockCalled Get-VMHardDiskDrive -Exactly 1
                Assert-MockCalled Add-VMHardDiskDrive -Exactly 1
            }
        }
        Context 'Valid configuration is passed with a SourceVHD that exists and DataVHD that do not exist and MoveSourceVHD set' {
            $VMs[0].DataVHDs = @( @{
                Vhd = 'DoesNotExist.vhdx'
                SourceVhd = 'DoesExist.Vhdx'
                MoveSourceVHD = $true
            } )
            It 'Does not throw an Exception' {
                { Update-LabVMDataDisk -Configuration $Config -VM $VMs[0] } | Should Not Throw
            }
            It 'Calls Mocked commands' {
                Assert-MockCalled Get-VHD -Exactly 0
                Assert-MockCalled Resize-VHD -Exactly 0
                Assert-MockCalled Move-Item -Exactly 1
                Assert-MockCalled Copy-Item -Exactly 0
                Assert-MockCalled New-VHD -Exactly 0
                Assert-MockCalled Get-VMHardDiskDrive -Exactly 1
                Assert-MockCalled Add-VMHardDiskDrive -Exactly 1
            }
        }
        Context 'Valid configuration is passed with a 10GB Fixed DataVHD that does not exist' {
            $VMs[0].DataVHDs = @( @{
                Vhd = 'DoesNotExist.vhdx'
                Type = 'Fixed'
                Size = 10GB
            } )
            It 'Does not throw an Exception' {
                { Update-LabVMDataDisk -Configuration $Config -VM $VMs[0] } | Should Not Throw
            }
            It 'Calls Mocked commands' {
                Assert-MockCalled Get-VHD -Exactly 0
                Assert-MockCalled Resize-VHD -Exactly 0
                Assert-MockCalled Move-Item -Exactly 0
                Assert-MockCalled Copy-Item -Exactly 0
                Assert-MockCalled New-VHD -Exactly 1
                Assert-MockCalled Get-VMHardDiskDrive -Exactly 1
                Assert-MockCalled Add-VMHardDiskDrive -Exactly 1
            }
        }
        Context 'Valid configuration is passed with a 10GB Dynamic DataVHD that does not exist' {
            $VMs[0].DataVHDs = @( @{
                Vhd = 'DoesNotExist.vhdx'
                Type = 'Dynamic'
                Size = 10GB
            } )
            It 'Does not throw an Exception' {
                { Update-LabVMDataDisk -Configuration $Config -VM $VMs[0] } | Should Not Throw
            }
            It 'Calls Mocked commands' {
                Assert-MockCalled Get-VHD -Exactly 0
                Assert-MockCalled Resize-VHD -Exactly 0
                Assert-MockCalled Move-Item -Exactly 0
                Assert-MockCalled Copy-Item -Exactly 0
                Assert-MockCalled New-VHD -Exactly 1
                Assert-MockCalled Get-VMHardDiskDrive -Exactly 1
                Assert-MockCalled Add-VMHardDiskDrive -Exactly 1
            }
        }
        Context 'Valid configuration is passed with a 10GB Differencing DataVHD that does not exist where ParentVHD is not set' {
            $VMs[0].DataVHDs = @( @{
                Vhd = 'DoesNotExist.vhdx'
                Type = 'Differencing'
                Size = 10GB
            } )
            It 'Throws VMDataDiskParentVHDMissingError Exception' {
                $ExceptionParameters = @{
                    errorId = 'VMDataDiskParentVHDMissingError'
                    errorCategory = 'InvalidArgument'
                    errorMessage = $($LocalizedData.VMDataDiskParentVHDMissingError `
                        -f $VMs[0].Name)
                }
                $Exception = New-Exception @ExceptionParameters
                { Update-LabVMDataDisk -Configuration $Config -VM $VMs[0] } | Should Throw $Exception
            }
            It 'Calls Mocked commands' {
                Assert-MockCalled Get-VHD -Exactly 0
                Assert-MockCalled Resize-VHD -Exactly 0
                Assert-MockCalled Move-Item -Exactly 0
                Assert-MockCalled Copy-Item -Exactly 0
                Assert-MockCalled New-VHD -Exactly 0
                Assert-MockCalled Get-VMHardDiskDrive -Exactly 0
                Assert-MockCalled Add-VMHardDiskDrive -Exactly 0
            }
        }
        Context 'Valid configuration is passed with a 10GB Differencing DataVHD that does not exist where ParentVHD does not exist' {
            $VMs[0].DataVHDs = @( @{
                Vhd = 'DoesNotExist.vhdx'
                Type = 'Differencing'
                Size = 10GB
                ParentVHD = 'DoesNotExist.vhdx'
            } )
            It 'Throws VMDataDiskParentVHDNotFoundError Exception' {
                $ExceptionParameters = @{
                    errorId = 'VMDataDiskParentVHDNotFoundError'
                    errorCategory = 'InvalidArgument'
                    errorMessage = $($LocalizedData.VMDataDiskParentVHDNotFoundError `
                        -f $VMs[0].Name,$VMs[0].DataVHDs[0].ParentVhd)
                }
                $Exception = New-Exception @ExceptionParameters
                { Update-LabVMDataDisk -Configuration $Config -VM $VMs[0] } | Should Throw $Exception
            }
            It 'Calls Mocked commands' {
                Assert-MockCalled Get-VHD -Exactly 0
                Assert-MockCalled Resize-VHD -Exactly 0
                Assert-MockCalled Move-Item -Exactly 0
                Assert-MockCalled Copy-Item -Exactly 0
                Assert-MockCalled New-VHD -Exactly 0
                Assert-MockCalled Get-VMHardDiskDrive -Exactly 0
                Assert-MockCalled Add-VMHardDiskDrive -Exactly 0
            }
        }
        Context 'Valid configuration is passed with a 10GB Differencing DataVHD that does not exist' {
            $VMs[0].DataVHDs = @( @{
                Vhd = 'DoesNotExist.vhdx'
                Type = 'Dynamic'
                Size = 10GB
                ParentVHD = 'DoesExist.vhdx'
            } )
            It 'Does not throw an Exception' {
                { Update-LabVMDataDisk -Configuration $Config -VM $VMs[0] } | Should Not Throw
            }
            It 'Calls Mocked commands' {
                Assert-MockCalled Get-VHD -Exactly 0
                Assert-MockCalled Resize-VHD -Exactly 0
                Assert-MockCalled Move-Item -Exactly 0
                Assert-MockCalled Copy-Item -Exactly 0
                Assert-MockCalled New-VHD -Exactly 1
                Assert-MockCalled Get-VMHardDiskDrive -Exactly 1
                Assert-MockCalled Add-VMHardDiskDrive -Exactly 1
            }
        }
        Context 'Valid configuration is passed with a DataVHD that does not exist and an unknown Type' {
            $VMs[0].DataVHDs = @( @{
                Vhd = 'DoesNotExist.vhdx'
                Type = 'Unknown'
                Size = 10GB
            } )
            It 'Throws VMDataDiskUnknownTypeError Exception' {
                $ExceptionParameters = @{
                    errorId = 'VMDataDiskUnknownTypeError'
                    errorCategory = 'InvalidArgument'
                    errorMessage = $($LocalizedData.VMDataDiskUnknownTypeError `
                        -f $VMs[0].Name,$VMs[0].DataVHDs[0].Vhd,$VMs[0].DataVHDs[0].Type)
                }
                $Exception = New-Exception @ExceptionParameters
                { Update-LabVMDataDisk -Configuration $Config -VM $VMs[0] } | Should Throw $Exception
            }
            It 'Calls Mocked commands' {
                Assert-MockCalled Get-VHD -Exactly 0
                Assert-MockCalled Resize-VHD -Exactly 0
                Assert-MockCalled Move-Item -Exactly 0
                Assert-MockCalled Copy-Item -Exactly 0
                Assert-MockCalled New-VHD -Exactly 0
                Assert-MockCalled Get-VMHardDiskDrive -Exactly 0
                Assert-MockCalled Add-VMHardDiskDrive -Exactly 0
            }
        }

        Mock Get-VHD -MockWith { @{
            VhdType =  'Fixed'
            Size = 10GB
        } }

        Context 'Valid configuration is passed with a 10GB Fixed DataVHD that exists and is already added to VM' {
            Mock Get-VMHardDiskDrive -MockWith { @{ Path = 'DoesExist.vhdx' } }
            $VMs[0].DataVHDs = @( @{
                Vhd = 'DoesExist.vhdx'
                Type = 'Fixed'
                Size = 10GB
            } )
            It 'Does not throw an Exception' {
                { Update-LabVMDataDisk -Configuration $Config -VM $VMs[0] } | Should Not Throw
            }
            It 'Calls Mocked commands' {
                Assert-MockCalled Get-VHD -Exactly 1
                Assert-MockCalled Resize-VHD -Exactly 0
                Assert-MockCalled Move-Item -Exactly 0
                Assert-MockCalled Copy-Item -Exactly 0
                Assert-MockCalled New-VHD -Exactly 0
                Assert-MockCalled Get-VMHardDiskDrive -Exactly 1
                Assert-MockCalled Add-VMHardDiskDrive -Exactly 0
            }
        }

    }



    Describe 'Initialize-LabVMs'  -Tags 'Incomplete' {
        #region Mocks
        Mock New-VHD
        Mock New-VM
        Mock Get-VM -MockWith { [PSObject]@{ ProcessorCount = '2'; State = 'Off' } }
        Mock Set-VM
        Mock Get-VMHardDiskDrive
        Mock Set-LabVMInitializationFiles
        Mock Get-VMNetworkAdapter
        Mock Add-VMNetworkAdapter
        Mock Start-VM
        Mock Wait-LabVMInit -MockWith { $True }
        Mock Get-LabVMSelfSignedCert
        Mock Initialize-LabVMDSC
        Mock Start-LabVMDSC
        #endregion

        Context 'Valid configuration is passed' {	
            $Config = Get-LabConfiguration -Path $Global:TestConfigOKPath
            New-Item -Path $Config.labbuilderconfig.settings.vmpath -ItemType Directory -Force -ErrorAction SilentlyContinue
            New-Item -Path $Config.labbuilderconfig.settings.vhdparentpath -ItemType Directory -Force -ErrorAction SilentlyContinue

            [Array]$Templates = Get-LabVMTemplates -Configuration $Config
            [Array]$Switches = Get-LabSwitches -Configuration $Config
            [Array]$VMs = Get-LabVMs -Configuration $Config -VMTemplates $Templates -Switches $Switches
                    
            It 'Returns True' {
                Initialize-LabVMs -Configuration $Config -VMs $VMs | Should Be $True
            }
            It 'Calls Mocked commands' {
                Assert-MockCalled New-VHD -Exactly 1
                Assert-MockCalled New-VM -Exactly 1
                Assert-MockCalled Set-VM -Exactly 1
                Assert-MockCalled Get-VMHardDiskDrive -Exactly 1
                Assert-MockCalled Set-LabVMInitializationFiles -Exactly 1
                Assert-MockCalled Get-VMNetworkAdapter -Exactly 9
                Assert-MockCalled Add-VMNetworkAdapter -Exactly 4
                Assert-MockCalled Start-VM -Exactly 1
                Assert-MockCalled Wait-LabVMInit -Exactly 1
                Assert-MockCalled Get-LabVMSelfSignedCert -Exactly 1
                Assert-MockCalled Initialize-LabVMDSC -Exactly 1
                Assert-MockCalled Start-LabVMDSC -Exactly 1
            }
            
            Remove-Item -Path $Config.labbuilderconfig.settings.vmpath -Recurse -Force -ErrorAction SilentlyContinue
            Remove-Item -Path $Config.labbuilderconfig.settings.vhdparentpath -Recurse -Force -ErrorAction SilentlyContinue
        }
    }



    Describe 'Remove-LabVMs' {
        #region Mocks
        Mock Get-VM -MockWith { [PSObject]@{ Name = 'PESTER01'; State = 'Running'; } }
        Mock Stop-VM
        Mock Wait-LabVMOff -MockWith { Return $True }
        Mock Get-VMHardDiskDrive
        Mock Remove-VM
        #endregion

        Context 'Valid configuration is passed' {	
            $Config = Get-LabConfiguration -Path $Global:TestConfigOKPath
            [Array]$Templates = Get-LabVMTemplates -Configuration $Config
            [Array]$Switches = Get-LabSwitches -Configuration $Config
            [Array]$VMs = Get-LabVMs -Configuration $Config -VMTemplates $Templates -Switches $Switches

            # Create the dummy VM's that the Remove-LabVMs function 
            It 'Returns True' {
                Remove-LabVMs -Configuration $Config -VMs $VMs | Should Be $True
            }
            It 'Calls Mocked commands' {
                Assert-MockCalled Get-VM -Exactly 4
                Assert-MockCalled Stop-VM -Exactly 1
                Assert-MockCalled Wait-LabVMOff -Exactly 1
                Assert-MockCalled Get-VMHardDiskDrive -Exactly 1
                Assert-MockCalled Remove-VM -Exactly 1
            }
        }
    }



    Describe 'Wait-LabVMInit' -Tags 'Incomplete' {
    }



    Describe 'Wait-LabVMStart' -Tags 'Incomplete'  {
    }



    Describe 'Wait-LabVMOff' -Tags 'Incomplete'  {
    }



    Describe 'Install-Lab' -Tags 'Incomplete'  {
    }



    Describe 'Uninstall-Lab' -Tags 'Incomplete'  {
    }
}