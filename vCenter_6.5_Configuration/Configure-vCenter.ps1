<#
.SYNOPSIS
    This script creates and configures the vCenter inventory based on a JSON input file.
.DESCRIPTION
    Script to configure the complete vCenter inventory and all associated settings. The script loads a json file containing all vcenter inventory items and related configuration.
    Based on this JSON file the complete inventory of a vCenter is created and configured.
    Included items:
        - vCenter folders
        - Roles
        - Permissions
        - Clusters
        - Datacenter
        - vDswitches
        - Portgroups
        - vCenter server level advanced settings
        - Datastoreclusters
.EXAMPLE
    Example of how to use this cmdlet
.EXAMPLE
    Another example of how to use this cmdlet
.INPUTS
    Inputs to this cmdlet (if any)
.OUTPUTS
    Output from this cmdlet (if any)
.NOTES
    General notes
#>

#region parameters
############################################################################################################### 
$jsonPath = "/Users/stijnvermoesen/Documents/Scripting/Dev-Powershell/vCenter_6.5_Configuration/vCenterInventory.json"
[string]$vCenter = Read-Host -Prompt "Enter the vCenter server FQDN (required)"
[string]$CustomJsonPath = Read-Host -Prompt "Enter the full path to the custom JSON file.(optional)"
###############################################################################################################
#endregion

#region functions

function import-Json {
    # .SYNOPSIS
    #     Function to verify the JSON file contains all required sections. Verification is done only on primary level.
    # .DESCRIPTION
    #     This Function checks for the existance of the Folders, Roles, Permissions, vCenters, settings and storage policies sections in the JSON file.
    
    Param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$jsonPath
    )

    Process { 
        Try { 
            write-statusoutput -message “Attempting JSON file import.” -type info
            $Json = Get-Content -path $JsonPath | ConvertFrom-Json
            return $Json
        } 
        Catch { 
            write-statusoutput -message “JSON file import failed. The file does not contain valid JSON.” -Type warning
            return $false  
        } 
    } 
}

function Test-Json {
    # .SYNOPSIS
    #     Function to verify the JSON file contains all required sections. Verification is done only on primary level.
    # .DESCRIPTION
    #     This Function checks for the existance of the Folders, Roles, Permissions, vCenters, settings and storage policies sections in the JSON file.
    
    Param(
        [Parameter(Mandatory = $true, ValueFromPipelineByPropertyName = $true)]
        [ValidateNotNullOrEmpty()]
        #[ValidateScript({$_ -ge (Get-Date)})]
        [array]$Folders
        ,        
        [Parameter(Mandatory = $true, ValueFromPipelineByPropertyName = $true)]
        [ValidateNotNullOrEmpty()]
        [array]$Roles
        ,
        [Parameter(Mandatory = $true, ValueFromPipelineByPropertyName = $true)]
        [ValidateNotNullOrEmpty()]
        [array]$Permissions
        ,
        [Parameter(Mandatory = $true, ValueFromPipelineByPropertyName = $true)]
        [ValidateNotNullOrEmpty()]
        [array]$vCenters
        ,
        [Parameter(Mandatory = $true, ValueFromPipelineByPropertyName = $true)]
        [ValidateNotNullOrEmpty()]
        [array]$Settings
        ,
        [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
        $json
    )
    Process { 
        Try { 
            write-statusoutput -message “Ensuring the JSON file contains the required sections.” -Type info
        } 
        Catch { 
            write-statusoutput -message “JSON validation failed.” -Type error
        } 
    } 
}
function Configure-vCenter {
    # .SYNOPSIS
    #     Main function used to configure the vCenter server.
    # .DESCRIPTION
    # 
    # .INPUTS
    #     - The imported content of the JSON file
    #     - The vCenter server which needs to be configured

    Param(
        [parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]    
        $JSON,
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]    
        [string] $vCenterServer

    )
    
    # Writing Header message
    write-statusoutput -message "========================================================================================================================" -type Success
    write-statusoutput -message "========================================================================================================================" -type Success
    write-statusoutput -message "Starting vCenter configuration." -type Success
    write-statusoutput -message "========================================================================================================================" -type Success
    write-statusoutput -message "========================================================================================================================" -type Success

    # Configure vCenter server settings
    Set-vCenterSettings -JSON $JSON -vCenterServer $vCenterServer

    write-statusoutput -message "========================================================================================================================" -type Success

    # Create datacenter(s)
    add-datacenter -Datacenters $JSON.vCenters.(get-hostname -serverFQDN $vCenterServer).vDatacenters
    
    write-statusoutput -message "========================================================================================================================" -type Success

    # Create cluster(s)
    add-clusters -Clusters $JSON.vCenters.(get-hostname -serverFQDN $vCenterServer).Clusters  

    write-statusoutput -message "========================================================================================================================" -type Success

    # Create roles
    add-role -roles $JSON.roles

    write-statusoutput -message "========================================================================================================================" -type Success

    # Create inventory folders
    # add-folders -Folders $JSON.Folders
    add-folders -json $JSON -vCenterServer $vCenterServer

    write-statusoutput -message "========================================================================================================================" -type Success

    # Configure permissions
    Add-permissions -json $JSON -vCenterServer $vCenterServer

    write-statusoutput -message "========================================================================================================================" -type Success

    # Configure vDswitches
    Add-vDswitches -vDswitchJson $JSON.vCenters.(get-hostname -serverFQDN $vCenterServer).DvSwitches

    write-statusoutput -message "========================================================================================================================" -type Success

    # Configure Datastore clusters
    Add-DatastoreClusters -DatastoreClusterData $JSON.vCenters.(get-hostname -serverFQDN $vCenterServer).DatastoreClusters

    write-statusoutput -message "========================================================================================================================" -type Success

    Configure-UpdateManager 

    # Writing Footer message
    write-statusoutput -message "========================================================================================================================" -type Success
    write-statusoutput -message "========================================================================================================================" -type Success
    write-statusoutput -message "vCenter configuration completed." -type Success
    write-statusoutput -message "========================================================================================================================" -type Success
    write-statusoutput -message "========================================================================================================================" -type Success
}

function Set-vCenterSettings {
    # .SYNOPSIS
    #     Function to configure vCenter server settings and advanced settings.
    # .DESCRIPTION
    #     This function is used to configure vcenter server level (advanced) settings. This function configures:
    #     - Increasing the performance statitics level 
    #     - vCenter server logging level
    #     - Database retention policy for event and tasks
    #     - syslog server settings for vCenter level (not vSphere host level)
    param(
        # Parameter help description
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]    
        $JSON,
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]    
        $vcenterServer
    )

    # Customizing performance statistics level, only the statistics level is being customized
    Get-StatInterval -name 'Past day' | set-statintervallevel -level $JSON.settings.vCenter.statisticslevelPastDay -Confirm:$false > $null
    Get-StatInterval -name 'Past week' | set-statintervallevel -level $JSON.settings.vCenter.statisticslevelPastWeek -Confirm:$false > $null
    Get-StatInterval -name 'Past month' | set-statintervallevel -level $JSON.settings.vCenter.statisticslevelPastMonth -Confirm:$false > $null
    Get-StatInterval -name 'Past year' | set-statintervallevel -level $JSON.settings.vCenter.statisticslevelPastYear -Confirm:$false > $null

    # Customizing vCenter log behaviour
    Get-AdvancedSetting -Entity $vcenterServer -Name 'config.log.outputToSyslog' | Set-AdvancedSetting -value $JSON.settings.vCenter.config_log_outputToSyslog -Confirm:$false -ErrorAction SilentlyContinue > $null
    Get-AdvancedSetting -Entity $vcenterServer -Name 'config.log.level' | Set-AdvancedSetting -value $JSON.settings.vCenter.config_log_level -Confirm:$false -ErrorAction SilentlyContinue > $null

    # Customizing vCenter tasks and events retention behaviour
    Get-AdvancedSetting -Entity $vcenterServer -Name 'task.maxAgeEnabled' | Set-AdvancedSetting -Value $JSON.settings.vCenter.task_maxAgeEnabled -Confirm:$false -ErrorAction SilentlyContinue > $null
    Get-AdvancedSetting -Entity $vcenterServer -Name 'task.maxAge' | Set-AdvancedSetting -Value $JSON.settings.vCenter.Task_MaxAge -Confirm:$false -ErrorAction SilentlyContinue > $null
    Get-AdvancedSetting -Entity $vcenterServer -Name 'event.maxAgeEnabled' | Set-AdvancedSetting -Value $JSON.settings.vCenter.event_maxAgeEnabled -Confirm:$false -ErrorAction SilentlyContinue > $null
    Get-AdvancedSetting -Entity $vcenterServer -Name 'event.maxAge' | Set-AdvancedSetting -Value $JSON.settings.vCenter.event_maxAge -Confirm:$false -ErrorAction SilentlyContinue > $null
}

function Set-StatIntervalLevel {
    # .SYNOPSIS
    #     Function to customize the vCenter statistics level
    # .DESCRIPTION
    #     Function only works to increase the statitics level. Also a statistics level cannot be higher then the previous interval.
    #     eg. The past week level cannot be 2 if the past day level is only 1.

    [CmdletBinding(SupportsShouldProcess = $true, Confirmimpact = 'High')]
    param (
        [Parameter(mandatory = $true, ValueFromPipeline = $true, HelpMessage = 'Enter the interval name')]
        [VMware.vimautomation.Types.StatInterval] $Interval,
        [Parameter(mandatory = $true, ValueFromPipeline = $true, HelpMessage = 'Enter the interval level')]
        [string] $level      
    )

    begin {
        $ServiceInstance = Get-View ServiceInstance
        $PerfMgr = Get-View $ServiceInstance.content.perfManager
    }       

    process {
        $CustomInterval = $PerfMgr.historicalInterval | Where-Object { $_.Name -eq $Interval.name }
        $CustomInterval.level = $level
        Write-StatusOutput -Message "Changing interval '$Interval' to level $level" -Type info
        if ($PScmdlet.shouldProcess($Level, 'Change statistics level')) {
            $PerfMgr.UpdatePerfInterval($CustomInterval)
        }
    }

    end {
    }          
}

function Add-datacenter {
    # .SYNOPSIS
    #     Function to create vCenter datacenters.
    # .DESCRIPTION
    # 
    param(
        # Array containing the datacenter names which need to be created
        [Parameter(Mandatory = $true, ValueFromPipeline = $True)]
        [ValidateNotNullOrEmpty()]    
        $Datacenters    
    )

    begin {
        Write-StatusOutput -Message "Starting datacenter creation." -type Success
    }
    
    process {
        $datacenters | ForEach-Object {
            if ( (Get-Datacenter -name $_ -ErrorAction SilentlyContinue) -eq $null ) {

                Write-StatusOutput -Message "Creating datacenter $_." -type info
                New-Datacenter -location (Get-Folder -Norecursion) -name $_ -ErrorAction SilentlyContinue -Confirm:$false > $null
            }
            else {
                Write-StatusOutput -Message "Datacenter $_ already exists. Skipping creation." -type warning
            }
        }
    }
    
    end {
        Write-StatusOutput -Message "Finished creation of datacenter items." -type Success
    }
}

function Add-Clusters {
    # .SYNOPSIS
    #     Function to create vCenter clusters
    # .DESCRIPTION
    # 
    param(
        # Parameter help description
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]    
        $Clusters
    )

    begin {
        Write-StatusOutput -Message "Starting host cluster creation." -type Success
    }

    process {
        $Clusters | ForEach-Object {
            if (!(Get-Datacenter -name $_.datacenter | Get-Cluster -name $_.name -ErrorAction SilentlyContinue)) {
                $NewClusterParam = @{
                    Name                      = $_.Name
                    location                  = Get-Datacenter -name $_.datacenter
                    EVCmode                   = $_.EVCmode
                    HAEnabled                 = $_.HAEnabled
                    HAAdmissionControlEnabled = $_.HAAdmissionControlEnabled
                    HAFailoverLevel           = $_.HAFailoverLevel
                    DrsEnabled                = $_.DrsEnabled
                    DrsAutomationLevel        = $_.DrsAutomationLevel
                    Confirm                   = $false
                    ErrorAction               = "SilentlyContinue"
                }
                $message = "Creating cluster " + $_.Name + " in " + $_.Datacenter + "."
                Write-StatusOutput -Message $message -type info
                New-Cluster @NewClusterParam > $null
            }
            else {
                $message = "Cluster " + $_.Name + " already exists in " + $_.Datacenter + "."
                Write-StatusOutput -Message $message -type warning
            }
        }
    }

    end {
        Write-StatusOutput -Message "Finished creation of clusters." -type Success
    }  
}
function Add-role {
    # .SYNOPSIS
    #     function to create roles and assign their priviliges
    # .DESCRIPTION
    #     Function to create vCenter roles and assign the associated priviliges for each role.
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $True, ValueFromPipeline = $True)]
        [ValidateNotNullOrEmpty()]    
        $Roles        
    )
    
    begin {
        Write-StatusOutput -Message "Starting creation of Role items." -type Success
    }
    
    process {

        if ($Roles -ne $null) {
            $Roles | ForEach-Object {
                if ((Get-VIRole -name $_.name -erroraction SilentlyContinue) -eq $null) {
                    $message = "Creating role " + $_.name
                    Write-StatusOutput -Message $message -type info
                    New-VIRole -name $_.name -ErrorAction SilentlyContinue -Confirm:$false  > $null                    
                    Add-Privileges -Role (Get-VIRole -name $_.name) -privileges $_.privilegeIDs -ErrorAction SilentlyContinue > $null                                       
                }
                else {
                    $message = "Role " + $_.name + " already exists. Skipping role creation. Verifying role privileges."
                    Write-StatusOutput -Message $message -type warning
                    # Role already exists, verifying assigned privileges and assigning missing ones if needed.
                    Add-Privileges -Role (Get-VIRole -name $_.name) -privileges $_.privilegeIDs -ErrorAction SilentlyContinue > $null  
                }
            }
        }
        else {
            Write-StatusOutput -Message "No roles supplied to add-role function. Role array is empty." -type error
        }        
    }    

    end {
        Write-StatusOutput -Message "Finished creation of Role items." -type Success
    }
}
function Add-Privileges {
    # .SYNOPSIS
    #     Function to assign priviliges to roles

    param(
        # Parameter help description
        [Parameter(Mandatory = $true, valueFromPipeline = $true)]
        [ValidateNotNullOrEmpty()]    
        $Role,
        # Parameter help description
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]    
        $Privileges
    )

    begin {
        write-statusoutput -Message "Starting privilege assignment for role $Role." -type info
    }

    process {
        # Using privilige IDs instead of names to distinguish between the different privilige groups
        $existingRolePrivileges = $Role | Get-VIPrivilege | Select-Object id

        # Assigning non-standard privileges to role. Read, view and anonymous are standard privileges which each role has by default.
        $Privileges | Where-Object { ($_ -ne "System.Read") -and ($_ -ne "System.View") -and ($_ -ne "System.Anonymous") } | ForEach-Object {
            if (Get-VIPrivilege -id $_ -ErrorAction silentlyContinue ) {
                if ($existingRolePrivileges -notcontains $_) {
                    Set-VIRole -Role $Role -AddPrivilege (Get-VIPrivilege -id $_) > $null
                }
                else {
                    write-statusoutput -Message "ViPrivilege $_ for role $Role already assigned." -type warning
                }
            }    
            else {
                write-statusoutput -Message "ViPrivilege $_ for role $Role is not valid. Only valid ViPrivileges can be assigned." -type warning            
            }
        }
    }

    end {
        write-statusoutput -Message "Finished privilege assignment for role $Role." -type info
    }
}
function Add-Folders {
    ############ Only VM folders currently

    # .SYNOPSIS
    #     Function containing the folder creation logic
    # .DESCRIPTION
    #     Actual folder creation is done in Add-Folder function

    [CmdletBinding()]     
    Param (
        # Param1 help description
        [Parameter(Mandatory = $true,
            ValueFromPipeline = $true)]
        [ValidateNotNullOrEmpty()]                        
        $Json,
        # Param1 help description
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]                        
        $vCenterServer
    )
        
    begin {
        write-statusoutput -Message "Starting folder creation." -type Success
    }
        
    process {
        $JSON.vCenters.(get-hostname -serverFQDN $vCenterServer).vDatacenters | ForEach-Object { 
            # Iterating folder creation on each datacenter in the JSON file. Other will be ignored.
            Get-Datacenter -Name $_| ForEach-Object {
                $addFolderParam = @{
                    datacenter = $_
                    name       = ""
                    level      = ""
                    type       = "VM"
                    Parent     = ""
                }
                # Creating top level VM folders first, sublevel folders during 2nd iteration
                $json.Folders | Where-Object { $_.level -eq "2" } | ForEach-Object {    
                    if ($_.parent.count -eq "0") {
                        # Adding folder specifics to splatting array
                        $addFolderParam.name = $_.name
                        $addFolderParam.level = $_.level
                        $message = "Creating folder " + $addFolderParam.name
                        Write-StatusOutput $message -type info
                        Add-Folder @addFolderParam
                    }
                    else {
                        write-statusoutput -Message "Level 2 folders cannot have a parent. Skipping folder creation." -type info
                        # Add-Folder -name $_.name -level $_.level -type "VM"
                    }                
                }
                # Creating sublevel VM folders after 
                $json.Folders | Where-Object { $_.level -eq "3" } | ForEach-Object {
                    # Adding folder specifics to splatting array
                    $addFolderParam.name = $_.name
                    $addFolderParam.level = $_.level
                    $_.parent | ForEach-Object {
                        #Adding Parent info to splatting array
                        $addFolderParam.Parent = $_
                        $message = "Creating folder " + $addFolderParam.name + " in " + $addFolderParam.Parent
                        Write-StatusOutput $message -type info
                        Add-folder @AddFolderParam
                    }
                }
        
            }
        }
    }

    end {
        write-statusoutput -Message "Finished folder creation." -type Success
    }
}
function Add-Folder {
    # .SYNOPSIS
    #     Function to create the folder

    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]       
        $datacenter,
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]       
        [String] $Name,
        [ValidateNotNullOrEmpty()]       
        [Int] $Level,
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]       
        [string]$Type,
        [Parameter(Mandatory = $false)]
        [String] $Parent
    )
    
    switch ($Type) {
        VM { 
            switch ($Level) {
                2 {  
                    if ($parent -eq "") {
                        if (!(Get-Folder -Name $Name -Location ($datacenter | Get-Folder vm) -ErrorAction SilentlyContinue)) {
                            # Creating toplevel VM folder in the datacenter root
                            write-statusoutput -Message "Creating $Name folder." -type info
                            New-Folder -Name $Name -Location ($datacenter | Get-Folder vm) -Confirm:$false -ErrorAction SilentlyContinue > $null
                        }
                        else {
                            write-statusoutput -Message "Top level $Name folder already exists. Skipping creation" -type warning
                        }
                    }
                    else {
                        write-statusoutput -Message "Parent item cannot be specified for top level folders. They will be created in each datacenter." -type warning
                    }

                }
                3 {
                    if ($_.parent -eq "") {
                        write-statusoutput -Message "Parent item needs to be specified for subfolders. Parent field needs to contain top level folders." -type warning
                    }
                    else {
                        # Creating sublevel folders
                        if (Get-Folder -name $Parent -location $datacenter -ErrorAction SilentlyContinue) {
                            if (!(Get-Folder -name $name -location (Get-Folder $Parent -location $datacenter) -ErrorAction SilentlyContinue)) {
                                write-statusoutput -Message "Creating folder $Parent/$Name." -type info
                                New-Folder -Name $Name -Location (Get-Folder $Parent -location $datacenter) -Confirm:$false -ErrorAction SilentlyContinue > $null
                            }
                            else {
                                write-statusoutput -Message "Folder $Parent/$Name already exists, skipping creation." -type warning
                            }
                        }
                        else {
                            write-statusoutput -Message "Folder $Name not created as parent folder $Parent does not exist." -type warning
                        }
                    }
                }
            }
        }
        Network {
            write-statusoutput -Message "Folder creation in the network view has not been implemented yet." -type warning
        }
        Host {
            write-statusoutput -Message "Folder creation in the Hosts view has not been implemented yet." -type warning
        }
        Datastore {
            write-statusoutput -Message "Folder creation in the datastore view has not been implemented yet." -type warning
        }
    }
}

function Add-Permissions {
    # .SYNOPSIS
    #     Function to configure permissions on vCenter items.
    # .NOTES
    #     Role names seen in the GUI do not match the ones used by PowerCLI. 
    #     Use Get-ViRole to get the role name used in PowerCLI.
    [CmdletBinding()]
    param (
        # Parameter help description
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()] 
        $json,
        # Parameter help description
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()] 
        $vCenterServer
    )

    begin {
        write-statusoutput -Message "Start configuring vCenter item permissions." -type Success
        $TopLevelVmFolder = $true
    }

    process {
        $json.Permissions | ForEach-Object {
            $PermissionItem = $_
            $NewViPermissionParam = @{
                Role          = ""
                Principal     = ""
                Entity        = ""
                Propagate     = ""
                Confirm       = $false
                ErrorAction   = "SilentlyContinue"
                ErrorVariable = "+ErrorLog"
            }
            switch ($_.itemType) {

                vCenter {
                    write-statusoutput -Message "Configuring vCenter level permissions." -type info
                    # Configuring permissions on vCenter root level, all vCenters are configured identically
                    $PermissionItem.ItemPermissions | Where-Object { $_.Environment -eq $JSON.vCenters.(get-hostname -serverFQDN $vCenterServer).Environment} | ForEach-Object {
                        $NewViPermissionParam.role = $_.role
                        $NewViPermissionParam.Principal = $_.AdDomain + "\" + $_.AdGroup
                        $NewViPermissionParam.Entity = (Get-Folder -NoRecursion)
                        $NewViPermissionParam.Propagate = $_.Propagate
                        # Check for existing principal needs to be added once AD module is available in Powershell core
                        if (!(Get-VIPermission -entity $NewViPermissionParam.Entity -Principal $NewViPermissionParam.Principal -ErrorVariable +ErrorLog)) {
                            New-VIPermission @NewViPermissionParam > $null
                        }
                        else {
                            $message = $NewViPermissionParam.Principal + " has already permissions on " + $NewViPermissionParam.Entity.name + "."
                            write-statusoutput -Message $message -type warning
                        }
                    }
                    continue
                }

                Datacenter {  
                    write-statusoutput -Message "Configuring datacenter level permissions." -type info
                    # Configuring permissions on datacenter level, all datacenters are configured identically
                        $PermissionItem.ItemPermissions | Where-Object { $_.Environment -eq $JSON.vCenters.(get-hostname -serverFQDN $vCenterServer).Environment} | ForEach-Object {
                        $NewViPermissionParam.role = $_.role
                        $NewViPermissionParam.Principal = $_.AdDomain + "\" + $_.AdGroup
                        $NewViPermissionParam.Propagate = $_.Propagate                  
                        # Check for existing principal needs to be added once AD module is available in Powershell core  
                        $json.vCenters.(get-hostname -serverFQDN $vCenterServer).vDatacenters | ForEach-Object {      
                            Get-Datacenter -Name $_ | ForEach-Object {           
                                $NewViPermissionParam.Entity = $_
                                if (!(Get-VIPermission -entity $NewViPermissionParam.Entity -Principal $NewViPermissionParam.Principal -ErrorVariable +ErrorLog)) {  
                                    New-VIPermission @NewViPermissionParam > $null
                                }
                                else {
                                    $message = $NewViPermissionParam.Principal + " has already permissions on " + $NewViPermissionParam.Entity.name + "."
                                    write-statusoutput -Message $message -type warning
                                }
                            }
                        }
                    }
                    continue
                }

                VmFolder {
                    if ($TopLevelVmFolder -eq $true) {
                        write-statusoutput -Message "Configuring folder permissions." -type info
                        $TopLevelVmFolder = $false
                    }
                    # Configuring permissions on the topfolder level, folderlevel permissions are folder specific
                    $PermissionItem | Where-Object { ($_.level -eq "2") -and ($_.parent -eq "Datacenter") } | ForEach-Object {
                            $_.ItemPermissions | Where-Object { $_.Environment -eq $JSON.vCenters.(get-hostname -serverFQDN $vCenterServer).Environment} | ForEach-Object {
                            $NewViPermissionParam.role = $_.role
                            $NewViPermissionParam.Principal = $_.AdDomain + "\" + $_.AdGroup
                            $NewViPermissionParam.Propagate = $_.Propagate
                            # Check for existing principal needs to be added once AD module is available in Powershell core
                            $json.vCenters.(get-hostname -serverFQDN $vCenterServer).vDatacenters | ForEach-Object {      
                                $NewViPermissionParam.Entity = Get-Folder -Name $PermissionItem.inventoryItem -Location (Get-Datacenter -Name $_ )
                                if (!(Get-VIPermission -entity $NewViPermissionParam.Entity -Principal $NewViPermissionParam.Principal -ErrorVariable +ErrorLog)) {                                    
                                    $message = "Configuring " + $NewViPermissionParam.role + " permissions on " + $NewViPermissionParam.Entity + " on " + $NewViPermissionParam.Entity.parent + "."  
                                    Write-StatusOutput -Message $message -type info   
                                    New-VIPermission @NewViPermissionParam > $null
                                }
                                else {
                                    $message = $NewViPermissionParam.Principal + " has already permissions on " + $NewViPermissionParam.Entity.name + "."
                                    write-statusoutput -Message $message -type warning
                                }
                            }
                        }
                    }
                    # Configuring permissions on the subfolder level, folderlevel permissions are folder specific
                    $PermissionItem | Where-Object { ($_.level -eq "3") -and ($_.parent -ne "Datacenter") } | ForEach-Object {
                            $_.ItemPermissions | Where-Object { $_.Environment -eq $JSON.vCenters.(get-hostname -serverFQDN $vCenterServer).Environment} | ForEach-Object {
                            $NewViPermissionParam.role = $_.role
                            $NewViPermissionParam.Principal = $_.AdDomain + "\" + $_.AdGroup
                            $NewViPermissionParam.Propagate = $_.Propagate 
                            # Check for existing principal needs to be added once AD module is available in Powershell core
                            $json.vCenters.(get-hostname -serverFQDN $vCenterServer).vDatacenters | ForEach-Object {      
                                $ToplevelFolder = Get-Folder -Name $PermissionItem.Parent -Location (Get-Datacenter -Name $_ )
                                $SublevelFolder = Get-Folder -name $PermissionItem.InventoryItem -Location $ToplevelFolder
                                $NewViPermissionParam.Entity = $SublevelFolder
                                if (!(Get-VIPermission -entity $NewViPermissionParam.Entity -Principal $NewViPermissionParam.Principal -ErrorVariable +ErrorLog)) {  
                                    $message = "Configuring " + $NewViPermissionParam.role + " permissions on " + $NewViPermissionParam.Entity + "."  
                                    Write-StatusOutput -Message $message -Type info                                  
                                    New-VIPermission @NewViPermissionParam > $null
                                }
                                else {
                                    $message = $NewViPermissionParam.Principal + " has already permissions on " + $NewViPermissionParam.Entity.name + "."
                                    write-statusoutput -Message $message -type warning
                                }
                            }
                        }
                    } 
                    continue
                }  

                cluster {   
                    write-statusoutput -Message "Cluster level permissions not yet implemented." -type info
                }

                Datastore {
                    write-statusoutput -Message "Datastore level permissions not yet implemented." -type info
                }

                ContentLibrary {
                    write-statusoutput -Message "Content Library level permissions not yet implemented." -type info
                }          
            } 
        } 
    }
    end {
        write-statusoutput -Message "Finished vCenter item level permissions configuration." -type Success
    }
}

function Add-vDswitches {
    # .SYNOPSIS
    #     Function to create the DvSwitches and their portgroups
    # .DESCRIPTION
    #     Long description
    param(
        # Parameter help description
        [Parameter(mandatory = $true)]
        [ValidateNotNullOrEmpty()] 
        $vDswitchJson
    )

    begin {
        write-statusoutput -Message "Starting vDswitch creation." -type Success
    }

    process {
        $vDswitchJson | ForEach-Object {
            $vDswitchJsonItem = $_
            if (!(get-vdswitch -name $vDswitchJsonItem.name -location (Get-Datacenter -name $vDswitchJsonItem.datacenter) -ErrorAction SilentlyContinue)) {
                $vDswitchParam = @{
                    Location                       = Get-Datacenter -name $vDswitchJsonItem.datacenter
                    Name                           = $vDswitchJsonItem.Name
                    NumUplinkPorts                 = $vDswitchJsonItem.NumOfUplinks
                    LinkDiscoveryProtocol          = $vDswitchJsonItem.LinkDiscoveryProtocol
                    LinkDiscoveryProtocolOperation = $vDswitchJsonItem.LinkDiscoveryProtocolOperation
                    Version                        = $vDswitchJsonItem.Version
                    Mtu                            = $vDswitchJsonItem.Mtu
                    Confirm                        = $false
                    ErrorAction                    = "SilentlyContinue"
                }
                $NewVdSwitch = new-vdswitch @vDswitchParam              
            }
            else {
                $message = "vDswitch " + $vDswitchJsonItem.Name + " already exists."
                write-statusoutput -Message $message -type warning
                $NewVdSwitch = get-vdswitch -name $vDswitchJsonItem.name -location (Get-Datacenter -name $vDswitchJsonItem.datacenter) -ErrorAction SilentlyContinue
            }

            if ((get-vdswitch -name $vDswitchJsonItem.name -location (Get-Datacenter -name $vDswitchJsonItem.datacenter) -ErrorAction SilentlyContinue | Get-VDPortgroup | Where-Object { $_.isuplink -eq $true }).name -ne ("DU" + ($vDswitchJsonItem.name).substring(2))) {
                get-vdswitch -name $vDswitchJsonItem.name -location (Get-Datacenter -name $vDswitchJsonItem.datacenter) -ErrorAction SilentlyContinue | Get-VDPortgroup | Where-Object { $_.isuplink -eq $true } | set-vdportgroup -name ("DU" + ($vDswitchJsonItem.name).substring(2)) -ErrorAction SilentlyContinue > $null
            } 

            $message = "Starting vDportgroup creation on " + $vDswitchJsonItem.name
            write-statusoutput -Message $message -type Success

            # handling vLAN ranges, Enumerating all vLANs for creation
            $vDswitchJsonItem.vlangroups | ForEach-Object {
                $AddvDPortgroupsParams = @{
                    VDSwitch            = $NewVdSwitch
                    Name                = $_.name
                    LoadBalancingPolicy = $_.LoadBalancingPolicy
                    SwitchConfig        = $vDswitchJsonItem
                }
                $vlans = @()
                $_.vlans.split(",") | ForEach-Object {
                    if ( $_ -like "*-*") {
                        # converting vLAN range to individual vLANs
                        $tempVlans = $_.split("-")
                        for ($i = [int]$tempVlans[0]; $i -lt [int]$tempVlans[1]; $i++) {
                            $vlans += $i
                        }
                    }
                    else {
                        $vLANs += $_
                    }
                }
                $AddvDPortgroupsParams.vlans = $vlans
                Add-vDPortgroups @AddvDPortgroupsParams
            }
            $message = "Finished vDportgroup creation on " + $vDswitchJsonItem.name
            write-statusoutput -Message $message -type Success
        }
    }

    end {
        write-statusoutput -Message "Finished vDswitch creation." -type Success
    }
} 
function Add-vDPortgroups {
    # .SYNOPSIS
    #   Function to create the vDPortgroups
    # .DESCRIPTION
    # 
    param (
        [Parameter(mandatory = $true)]
        [ValidateNotNullOrEmpty()] 
        $VDSwitch,
        [Parameter(mandatory = $true)]
        [ValidateNotNullOrEmpty()] 
        $Name,
        [Parameter(mandatory = $true)]
        [ValidateNotNullOrEmpty()] 
        $vLANs,
        [Parameter(mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        $LoadBalancingPolicy,
        [Parameter(mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        $SwitchConfig        
    )

    begin {
    }

    process {
        $vlans | ForEach-Object {
            [int]$vlanID = $_
            $newPortgroupParams = @{
                Name          = $Name + "-" + $vlanID.tostring("0000")
                vDswitch      = $VDSwitch
                vlanid        = $_
                Confirm       = $false
                RunAsync      = $false
                ErrorAction   = "SilentlyContinue"
                ErrorVariable = "+ErrorLog"
            }
            if (!(get-vdportgroup -name $newPortgroupParams.name -ErrorAction SilentlyContinue)) {
                $message = "Creating portgroup " + $newPortgroupParams.name + " on " + $VDSwitch.name + "."
                Write-StatusOutput -Message $message -Type info
                new-vdportgroup @newPortgroupParams > $null
                $message = "Configuring Loadbalancing on " + $newPortgroupParams.name + " on " + $VDSwitch.name + "."
                Write-StatusOutput -Message $message -Type info
                get-vdportgroup -name $newPortgroupParams.name | Get-VDUplinkTeamingPolicy | Set-VDUplinkTeamingPolicy -LoadBalancingPolicy $LoadBalancingPolicy -Confirm:$false > $null
                
            }
            else { 
                $message = "vDportgroup " + $newPortgroupParams.name + " already exists on " + $vdswitch.name + "."
                write-statusoutput -Message $message -type warning
                # Verifying TeamingPolicy
                if (!((get-vdportgroup -name $newPortgroupParams.name | Get-VDUplinkTeamingPolicy).LoadBalancingPolicy -eq $LoadBalancingPolicy) ) {
                    $message = "Configuring Loadbalancing on " + $newPortgroupParams.name + " on " + $VDSwitch.name + "."
                    Write-StatusOutput -Message $message -Type info
                    get-vdportgroup -name $newPortgroupParams.name | Get-VDUplinkTeamingPolicy | Set-VDUplinkTeamingPolicy -LoadBalancingPolicy $LoadBalancingPolicy -ErrorAction SilentlyContinue > $null
                }
                else {
                    $message = "Loadbalancing Policy already configured on " + $newPortgroupParams.name
                    Write-StatusOutput -Message $message -type warning
                }
            }
        }
    }

    end {
    }

}

function Add-DatastoreClusters {
    # .SYNOPSIS
    #   Function to create empty datastore clusters, datastores need to be added seperately.
    # .DESCRIPTION
    # 
    param(
        [Parameter(mandatory = $true)]
        [ValidateNotNullOrEmpty()] 
        $DatastoreClusterData
    )

    begin {
        $message = "Starting datastore cluster creation"
        write-statusoutput -Message $message -type Success
    }

    process {
        $DatastoreClusterData | ForEach-Object {
            if (!(Get-Datacenter -name $_.datacenter | Get-DatastoreCluster -name $_.name -ErrorAction SilentlyContinue)) {
                $NewDatastoreClusterParam = @{
                    name          = $_.name
                    location      = Get-Datacenter -name $_.datacenter
                    Confirm       = $false
                    ErrorAction   = "SilentlyContinue"
                    ErrorVariable = "+ErrorLog"
                }
                
                $SetDatastoreClusterParam = @{
                    IOLoadBalanceEnabled = $_.IOLoadBalanceEnabled
                    SdrsAutomationLevel  = $_.SdrsAutomationLevel
                    Confirm              = $false
                    ErrorAction          = "SilentlyContinue"
                    ErrorVariable        = "+ErrorLog"
                }
                $message = "Creating datastore cluster $NewDatastoreClusterParam.name on " + $NewDatastoreClusterParam.location
                write-statusoutput -Message $message -type info
                New-DatastoreCluster @NewDatastoreClusterParam | Set-DatastoreCluster @setDatastoreClusterParam > $null
            }
            else {
                $message = "Datastore cluster " + $_.name + " already exists in " + $_.datacenter + "." 
                write-statusoutput -Message $message -type warning
            }
        }
    }

    end {
        write-statusoutput -Message "Finished datastore cluster creation." -type Success
    }    
}

function Configure-UpdateManager {
    # .SYNOPSIS
    #     Function to configure the update manager settings and assign patch baselines. 
    # .DESCRIPTION
    #     PowerCLI currently has only verry limited support for update manager thus only the patch baselines are assigned.
    # .NOTES
    # VMware.VUMAutomation module is currently not supported on powershell core (201903)
    begin {
        write-statusoutput -Message "Starting Update Manager configuration." -type Success
    }

    process {
        Get-Baseline -Name "*critical*" | Attach-Baseline -Entity (Get-Folder -Name "datacenters")
    }

    end {
        write-statusoutput -Message "Finished Update Manager configuration." -type Success
    }
}

function Get-Hostname {
    # .SYNOPSIS
    #     Function to retrieve the hostname part of a FQDN
    # .DESCRIPTION
    #     Function to retrieve the hostname part of a FQDN

    param (
        [parameter(mandatory = $true)]
        [ValidateNotNullOrEmpty()] 
        [string] $serverFQDN
    )
    $hostname = $serverFQDN.split(".")[0]
    return $hostname
}

function Write-StatusOutput {
    # .SYNOPSIS
    #     Function handling the script output
    # .DESCRIPTION
    #

    Param (
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()] 
        $Message,
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()] 
        [String] $Type
    )

    $msg = @(
        "$((Get-Date).ToString())",
        "$Message"
    )

    switch ($Type) {
        Error { 
            Write-Host ($msg -join "`t") -foregroundcolor Red
        }
        Warning { 
            Write-Host ($msg -join "`t") -foregroundcolor yellow
        }
        Success { 
            Write-Host ($msg -join "`t") -foregroundcolor green
        }
        info {
            Write-Host ($msg -join "`t") -foregroundcolor Blue
        }
    }
}
#endregion

#region main script body
# Disconnecting any open vCenter connections
try {
    Disconnect-VIServer -Server * -Confirm:$false 
}
catch {
    
}

# Handling custom JSON file if supplied during script call.
if ($CustomJsonPath -eq "") {
    Write-statusoutput -message "Using default JSON file" -type Info
}
else {
    Write-statusoutput -message "Using custom JSON file $CustomJsonPath" -type Info
    $JsonPath = $CustomJsonPath
}

if (Test-Path -path $JsonPath) {
    Write-statusoutput -message "Importing JSON" -type Info
    $Json = import-Json -jsonPath $jsonPath
    Write-statusoutput -message "Validating JSON" -type Info
    $json | Test-Json
}
else {
    write-statusoutput -message "JSON file does not exist. Make sure the specified path is correct." -type info
    break
}

# Verifying vCenter availability and connection to vCenter, if ok start vCenter configuration
if ($vCenter -ne "") {
    if ( Test-Connection -ComputerName $vCenter -Quiet ) {
                if (connect-viserver -Server $vCenter -Credential (get-credential) -AllLinked:$false -ErrorAction SilentlyContinue) {
                        write-statusOutput -message "Configuring vCenter $vcenter based on JSON file $JsonPath." -type info
                        Configure-vCenter -JSON $Json -vCenterServer $vCenter
                }
                else { 
                    write-statusOutput -message "Failed to connect to vCenter $vcenter due to invalid credentials." -type error
                    return 
                }
             }
            else {
                write-statusOutput -message "vCenter $vCenter not available on the network. Aborting." -type error
                return
            }
    }
    else {
        write-statusOutput -message "vCenter server needs to be specified. Aborting." -type error
        break
    }

    Disconnect-VIServer $vCenterServer -Confirm:$false | Out-Null
#endregion




