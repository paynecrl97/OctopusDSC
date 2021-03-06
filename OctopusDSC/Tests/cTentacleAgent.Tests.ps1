#requires -Version 4.0

$moduleName = Split-Path ($PSCommandPath -replace '\.Tests\.ps1$', '') -Leaf
$modulePath = Split-Path $PSCommandPath -Parent
$modulePath = Resolve-Path "$PSCommandPath/../../DSCResources/$moduleName/$moduleName.psm1"
$module = $null

try
{
    $prefix = [guid]::NewGuid().Guid -replace '-'
    $module = Import-Module $modulePath -Prefix $prefix -PassThru -ErrorAction Stop

    InModuleScope $module.Name {

        # Get-Service is not available on mac/unix systems - fake it
        $getServiceCommand = Get-Command "Get-Service" -ErrorAction SilentlyContinue
        if ($null -eq $getServiceCommand) {
            function Get-Service {}
        }

        Describe 'cTentacleAgent' {
            BeforeEach {
                $desiredConfiguration = @{
                     Name                   = 'Stub'
                     Ensure                 = 'Present'
                     State                  = 'Started'
                }
            }

            Context 'Confirm-RegistrationParameters' {
                It 'Throws if RegisterWithServer is false but environment provided' {
                    { Confirm-RegistrationParameters -RegisterWithServer $False -Environments @('My Env') } | Should Throw "Invalid configuration requested"
                }
                It 'Throws if RegisterWithServer is false but roles provided' {
                    { Confirm-RegistrationParameters -RegisterWithServer $False -Roles @('app-server') } | Should Throw "Invalid configuration requested"
                }
                It 'Throws if RegisterWithServer is false but tenants provided' {
                    { Confirm-RegistrationParameters -RegisterWithServer $False -Tenants @('Jim-Bob') } | Should Throw "Invalid configuration requested"
                }
                It 'Throws if RegisterWithServer is false but tenant Tags provided' {
                    { Confirm-RegistrationParameters -RegisterWithServer $False -TenantTags @('CustomerType/VIP', 'Hosting/OnPrem') } | Should Throw "Invalid configuration requested"
                }
                It 'Throws if RegisterWithServer is false but policy provided' {
                    { Confirm-RegistrationParameters -RegisterWithServer $False -Policy "my policy" } | Should Throw "Invalid configuration requested"
                }
                It 'Does not throw if RegisterWithServer is false and environment provided as empty string' {
                    Confirm-RegistrationParameters -RegisterWithServer $False -Environments ""
                }
                It 'Does not throw if RegisterWithServer is false and environment provided as empty array' {
                    Confirm-RegistrationParameters -RegisterWithServer $False -Environments @()
                }
                It 'Does not throw if RegisterWithServer is false and environment provided as array with empty element' {
                    Confirm-RegistrationParameters -RegisterWithServer $False -Environments @('')
                }
                It 'Does not throw if RegisterWithServer is false and no environment provided' {
                    Confirm-RegistrationParameters -RegisterWithServer $False
                }
            }

            Context 'Confirm-RequestedState' {
                It 'Throws if RegisterWithServer is false but environment provided' {
                    { Confirm-RequestedState -Ensure "Absent" -State "Started" } | Should Throw "Invalid configuration requested"
                }
            }

            Context 'Get-TargetResource' {
                Mock Get-ItemProperty { return @{ InstallLocation = "c:\Octopus\Tentacle\Stub" }}
                Mock Get-Service { return @{ Status = "Running" }}

                It 'Returns the proper data' {
                    $config = Get-TargetResource -Name 'Stub'

                    $config.GetType()                  | Should Be ([hashtable])
                    $config['Name']                    | Should Be 'Stub'
                    $config['Ensure']                  | Should Be 'Present'
                    $config['State']                   | Should Be 'Started'
                }
            }

            Context 'Test-TargetResource' {
                $response = @{ Ensure="Absent"; State="Stopped" }
                Mock Get-TargetResource { return $response }

                It 'Returns True when Ensure is set to Absent and Tentacle does not exist' {
                    $desiredConfiguration['Ensure'] = 'Absent'
                    $desiredConfiguration['State'] = 'Stopped'
                    $response['Ensure'] = 'Absent'
                    $response['State'] = 'Stopped'

                    Test-TargetResource @desiredConfiguration | Should Be $true
                }

               It 'Returns True when Ensure is set to Present and Tentacle exists' {
                    $desiredConfiguration['Ensure'] = 'Present'
                    $desiredConfiguration['State'] = 'Started'
                    $response['Ensure'] = 'Present'
                    $response['State'] = 'Started'

                    Test-TargetResource @desiredConfiguration | Should Be $true
                }
            }

            Context 'Set-TargetResource' {
                #todo: more tests
            }
        }
    }
}
finally
{
    if ($module) {
        Remove-Module -ModuleInfo $module
    }
}