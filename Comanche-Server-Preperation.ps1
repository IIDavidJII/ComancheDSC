Configuration ATIServerPrep 
{
  Param
    ( [String]
      $TimeZone = 'Central Standard Time',

      [String]
      $OasisUser = 'comanche\svcOasis',

      [String]
      $LoyaltyUser = 'comanche\svcLoyalty',
      
      [String]
      $timeStamp = (Get-Date).tostring()
    )

Import-DscResource -ModuleName 'PSDesiredStateConfiguration','NetworkingDSC' , 'xSystemSecurity', 'cDTC', 'ComputerManagementDsc', 'SqlServerDsc'

Node $AllNodes.NodeName {

#remote Desktop
 WindowsFeature RemoteAccess {
   Ensure = "Present"
   Name = "RemoteAccess"
 }

 WindowsFeature RemoteAccessDesktop {
   Ensure = "Present"
   Name = "Remote-Desktop-Services"
 }

#Disable Firewall
  Service MpsSvc
  {
    Name = "MpsSvc"
    StartupType = "Manual"
    State = "Running"
  }

  Script DisableFirewalls
     {
       GetScript = {(Get-NetFirewallProfile -All -ErrorAction SilentlyContinue).Enabled}

       TestScript = {
                       IF((Get-NetFirewallProfile -all -ErrorAction SilentlyContinue).Enabled) 
                            {return $true} 
                       ELSE {return $false} 
                    }
       SetScript = {Set-NetFIrewallProfile -all -Enabled False}
     }
#allow DTC through firewall

  Script AllowDTCappfirewall
    {
       GetScript = {Get-NetFirewallRule -DisplayGroup "Distributed Transaction Coordinator" }

       Testscript = {
                      IF ((Get-NetFirewallRule -DisplayGroup "Distributed Transaction Coordinator").Enabled -eq $true)
                           {Return $true}
                      Else {Return $false}
                    }

       SetScript =  {
                      Set-NetFirewallRule -DisplayGroup "Distributed Transaction Coordinator" -Enabled True 
                    }
    }
    
#TimeZone
    TimeZone SetTimeZone
     {
       IsSingleInstance = 'Yes'
       TimeZone = $TimeZone
     }


#install required windows features

    WindowsFeature MessageQueuing 
     {
      Name = "MSMQ"
      Ensure = "Present"
     }
    WindowsFeature MessageQueuingService 
     {
      Name = "MSMQ-Services"
      Ensure = "Present"
     }

    WindowsFeature MessageQueingServer
     {
      Name = "MSMQ-Server"
      Ensure = "Present"
     }

    WindowsFeature net35Framework
     {
      Name = "NET-Framework-Core"
      Ensure = "Present"
      Source = "\\CNC-TEST-SQL\sxs"
     }

#User Account Control    
    xUac DisableUAC 
     {
      Setting ='NeverNotifyAndDisableAll'
     }

#Distributed Transactions     
     cDTCNetworkSetting DistributedTrans 
     {
       DtcName = "Local"
       RemoteClientAccessEnabled = $true
       RemoteAdministrationAccessEnabled = $true
       InboundTransactionsEnabled = $true
       OutboundTransactionsEnabled = $true
       XATransactionsEnabled = $true
       LUTransactionsEnabled = $true
       AuthenticationLevel = "NoAuth"
     }

#Power Plan
     PowerPlan SetPlanHighPerformance
        {
          IsSingleInstance = 'Yes'
          Name             = 'High performance'
        }


#IPV4 disable nic Power Management
     Script DisablePowerManagement
       {
         TestScript = {
                        $adapterPower = Get-NetAdapterPowerManagement                     
                        IF($adapterPower.ArpOffload -ne "Enabled" -and $adapterPower.NSOffload -ne "Enabled" -and $adapterPower.RsnRekeyOffload -ne "Enabled" -and $adapterPower.D0PacketCoalescing -ne "Enabled" -and $adapterPower.DeviceSleepOnDisconnect -ne "Enabled" -and $adapterPower.WakeOnMagicPacket -ne "Enabled" -and $adapterPower.WakeOnPattern -ne "Enabled" )
                        {return $true} 
                        ELSE {return $false}
                      }

         SetScript = { $AdapterPower1 = Get-NetAdapterPowerManagement
                       FOREACH($adapter1 in $AdapterPower1)
                         {Disable-NetAdapterPowerManagement -Name $adapter1.name -NoRestart}
                     }

         GetScript = {Get-NetAdapterPowerManagement}
       }

#Registry edit for HTTP2
   Registry HTTP2Disable1  {
     Ensure = "Present"
     Key = "HKEY_LOCAL_MACHINE\System\CurrentControlSet\Services\HTTP\Parameters"
     ValueName = "EnableHttp2Tls"
     ValueData = "0"
     ValueType = "Dword"
   }

   Registry HTTP2Disable2 {
     Ensure = "Present"
     Key = "HKEY_LOCAL_MACHINE\System\CurrentControlSet\Services\HTTP\Parameters"
     ValueName = "EnableHttp2Cleartext"
     ValueData = "0"
     ValueType = "Dword"
   }
   
   #Disable IPv6
   Script IPV6Disable {
   TestScript = {$AdapterIVP6 = Get-NetAdapterBinding -name * -ComponentID 'MS_TCPIP6'
                 IF((Get-NetAdapterBinding  -Name * -ComponentID ms_tcpip6).Enabled-eq $false) {return $true} Else {return $false}
                 }
   SetScript = {$AdapterIVP6_1 = Get-NetAdapterBinding -name * -ComponentID 'MS_TCPIP6'
                FOREACH ($Adapter_1 in $AdapterIVP6_1)
                {Disable-NetAdapterBinding -Name $Adapter_1.Name -ComponentID 'MS_TCPIP6'}
               }
   GetScript ={Get-NetAdapterBinding -ComponentID 'MS_TCPIP6'} 
   }
      
  }

  Node $AllNodes.Where{$_.Role -eq "Oasis"}.NodeName
  {
    #add Oasis EXISTING account to local admin   
    Group Administrators 
     {
       GroupName="Administrators"
       MembersToInclude=$OasisUser
     }
  }

  

  Node $AllNodes.Where{$_.Role -eq "Loyalty"}.NodeName
  {
    #add Loyalty EXISTING account to local admin
     Group Administrators 
     {
       GroupName = "Administrators"
       MembersToInclude = $LoyaltyUser
     }

  }

  Node $AllNodes.Where{$_.Role -eq "nconnect"}.NodeName
  {
    WindowsFeature NetworkLoadBalancer {
      Name = "NLB"
      Ensure = "Present"
    }

    File TempFolder {
         Ensure = "Present"
         Type = "Directory"
         DestinationPath = "c:\Temp"
      }

  }

  Node $AllNodes.Where{$_.Role -eq "SQLServer"}.NodeName
  {
    File CopySQLConfigScript {
         Ensure = "Present"
         Type = "Directory"
         DestinationPath = "t:\Temp"
      }

    File SQLConfigScript1 {
         Ensure = "Present"
         Type = "Directory"
         DestinationPath = "S:\DBE_Scripts"
      }



    File SQLConfigScript2 {
         Ensure = "Present"
         Type = "File"
         SourcePath = 'C:\DSC_Configuration\0.SQL Server Configuration.SQL'
         DestinationPath = "s:\DBE_Scripts\0.SQL Server Configuration.SQL"
         DependsOn = "[File]SQLConfigScript1"
      }

    
    File SQLConfigScript3 {
         Ensure = "Present"
         Type = "Directory"
         DestinationPath = "S:\Install"
      }

    SmbShare InstallShare {
        Name = "Install$"
        Path = "S:\Install"
        FullAccess = @('Everyone')
      }

   File ATSFolder {
         Ensure = "Present"
         Type = "Directory"
         DestinationPath = "S:\Install\_ATS"
      }

    File SQLConfigScript4 {
         Ensure = "Present"
         Type = "Directory"
         DestinationPath = "S:\Reports"
      }

    SmbShare ReportsShare {
         Name = "Reports$"
         Path = "S:\Reports"
         FullAccess = @("Everyone")
      }
 
    File SQLConfigScript5 {
         Ensure = "Present"
         Type = "Directory"
         DestinationPath = "S:\Omniview"
      }
    
    SmbShare OmniviewShare {
         Name = "Omniview$"
         Path = "S:\Omniview"
         FullAccess = @("Everyone")
      }

    File SQLConfigScript6 {
         Ensure = "Present"
         Type = "Directory"
         DestinationPath = "S:\Bills"
      }

    SmbShare BillsShare {
         Name = "Bills$"
         Path = "S:\Bills"
         FullAccess = @("Everyone")
      }
      
    File SQLConfigScript7 {
         Ensure = "Present"
         Type = "Directory"
         DestinationPath = "S:\Tickets"
      }

    SmbShare TicketsShare {
         Name = "Tickets$"
         Path = "S:\Tickets"
         FullAccess = @("Everyone")
      }

    File SQLConfigScript8 {
         Ensure = "Present"
         Type = "Directory"
         DestinationPath = "L:\Log"
      }


  }
}


#Only allowed one node name change as needed

$cd = @{
    AllNodes = @(

        @{
            NodeName = "Spur-ATI-SQL01"
            Role = "SQLServer"
         }

        @{  
            NodeName = "CNC-ATI-SQL01"
            Role = "SQLServer"
         }
        
        @{  NodeName = "CNE-LOY-SQL01"
            Role = "LoyaltySQLServer"
         }
        @{  NodeName = "CNE-LOY-SQL02"
            Role = "LoyaltySQLServer"
         }

        @{  NodeName = "CNC-Test-SQL"
            Role = "SQLServer"
         }

        @{  NodeName = "CNC-Test-Loysql"
            Role = "LoyaltySQLServer"
         }

        @{  NodeName = "STAR-ATI-SQL01"
            Role = "SQLServer"
         }

        @{  NodeName = "TRV-ATI-SQL01"
            Role = "SQLServer"
         }

        @{  NodeName = "CRRC-ATI-SQL01"
            Role = "SQLServer"
         }
         
        @{
            NodeName = "spur-nConn01"
            Role = "nConnect"
         }         
        @{
            NodeName = "cnc-test-nConn"
            Role = "nConnect"
         }

        @{
            NodeName = "spur-nconn02"
            Role = "nConnect"
         }

        @{
            NodeName = "cnc-nconnect01"
            Role = "nConnect"
         }

        @{
            NodeName = "cnc-nconnect02"
            Role = "nConnect"
         }

        @{
            NodeName = "TRV-nconnect01"
            Role = "nConnect"
         }

        @{
            NodeName = "TRV-nconnect02"
            Role = "nConnect"
         }

        @{
            NodeName = "Star-nconnect01"
            Role = "nConnect"
         }

        @{
            NodeName = "Star-nconnect02"
            Role = "nConnect"
         }

        @{
            NodeName = "CRRC-nconnect01"
            Role = "nConnect"
         }

        @{
            NodeName = "CRRC-nconnect02"
            Role = "nConnect"
         }

        @{NodeName = "spur-prime01"
            Role =  "Oasis" 
         }

        @{NodeName = "spur-prime02"
          Role = "Oasis"
         }

        @{NodeName = "spur-prime03"
          Role = "Oasis"
         }

        @{NodeName = "spur-prime04"
          Role =  "Oasis"
         }

        @{NodeName = "spur-prime05"
          Role =  "Oasis"
         }

        @{NodeName = "spur-prime06"
          Role = "Oasis"
         }

        @{NodeName = "spur-prime07"
          Role =  "Oasis"
         }

        @{NodeName = "spur-prime08"
          Role = "Oasis"
         }

        @{NodeName = "spur-prime09"
          Role  = "Oasis"
         }

        @{NodeName = "spur-prime10"
          Role = "Oasis"
         }

        @{NodeName = "Spur-Poller01"
          Role = "Oasis"
         }

        @{NodeName = "Spur-SMCache01"
          Role = "Oasis"}

        @{NodeName = "CNC-Prime01"
          Role = "Oasis"
         }

        @{NodeName = "CNC-Prime02"
          Role =  "Oasis"
         }

        @{NodeName = "CNC-Prime03"
          Role = "Oasis"
         }

        @{NodeName = "CNC-Prime04"
          Role =  "Oasis"
         }

        @{NodeName = "CNC-Prime05"
          Role  = "Oasis"
         }

        @{NodeName = "CNC-Prime06"
          Role = "Oasis"
         }

        @{NodeName = "CNC-Prime07"
          Role =  "Oasis"
         }

        @{NodeName = "CNC-Prime08"
          Role = "Oasis"
         }

        @{NodeName = "CNC-Prime09"
          Role = "Oasis"
         }

        @{NodeName = "CNC-Prime10"
          Role = "Oasis"
         }

        @{NodeName = "CNC-Prime11"
          Role = "Oasis"
         }

        @{NodeName = "CNC-Poller01"
          Role = "Oasis"
         }

        @{NodeName = "CNC-Poller02"
          Role =  "Oasis"
         }

        @{NodeName = "CNC-Poller03"
          Role = "Oasis"
         }

        @{NodeName = "CNC-SMCACHE01"
          Role = "Oasis"
         }

        @{NodeName = "CNC-SMCACHE02"
          Role =  "Oasis"
         }

        @{NodeName = "CNE-LOY-WEB01"
          Role = "Loyalty"
         }

        @{NodeName = "CNE-LOY-WEB02"
          Role = "Loyalty"
         }

        @{NodeName = "CNE-LOY-APP01"
          Role = "Loyalty"
         }

        @{NodeName = "CNE-LOY-APP02"
          Role = "Loyalty"
         }

        @{NodeName = "CNE-LOY-GW01" 
          Role =  "Loyalty"
         }

        @{NodeName = "CNC-Test-Prime1"
          Role = "Oasis"
         }

        @{NodeName = "CNC-Test-Prime2"
          Role = "Oasis"
         }

        @{NodeName = "CNC-Test-Prime3"
          Role =  "Oasis"
         }
        @{NodeName = "CNC-Test-Loyweb"
          Role = "Loyalty"
         }

        @{NodeName = "CNC-Test-Loyapp"
          Role = "Loyalty"
         }

        @{NodeName = "CNC-TrackIT-DB"
          Role = "Oasis"
         }

        @{NodeName = "CNC-Trackit-Web"
          Role = "Oasis"
         }
     
        @{NodeName = "TRV-PRIME01"
          Role  = "Oasis"
         }

        @{NodeName = "TRV-PRIME02"
          Role = "Oasis"
         }

        @{NodeName = "TRV-PRIME03"
          Role = "Oasis"
         }

        @{NodeName = "TRV-PRIME04"
          Role = "Oasis"
         }

        @{NodeName = "TRV-PRIME05"
          Role = "Oasis"
         }

        @{NodeName = "TRV-PRIME06"
          Role = "Oasis"
         }

        @{NodeName = "TRV-PRIME07"
          Role = "Oasis"
         }

        @{NodeName = "TRV-PRIME08"
          Role = "Oasis"
         }

        @{NodeName = "TRV-PRIME09"
          Role = "Oasis"
         }
        
        @{NodeName = "TRV-Poller01"
          Role = "Oasis"
         }
        
        @{NodeName = "TRV-SMCache01"
          Role = "Oasis"
         }

        @{NodeName = "Star-Prime01"
          Role = "Oasis"
         }

        @{NodeName = "Star-Prime02"
          Role = "Oasis"
         }

        @{NodeName = "Star-Prime03"
          Role = "Oasis"
         }

        @{NodeName = "Star-Prime04"
          Role = "Oasis"
         }

        @{NodeName = "Star-Prime05"
          Role = "Oasis"
         }

        @{NodeName = "Star-Prime06"
          Role = "Oasis"
         }

        @{NodeName = "Star-Prime07"
          Role = "Oasis"
         }

        @{NodeName = "Star-Prime08"
          Role = "Oasis"
         }

        @{NodeName = "Star-Prime09"
          Role = "Oasis"
         }

        @{NodeName = "Star-Poller01"
          Role =  "Oasis"
         }

        @{NodeName = "Star-SMCache01"
          Role =  "Oasis"
         }

        @{NodeName = "CRRC-Prime01"
          Role = "Oasis"
         }

        @{NodeName = "CRRC-Prime02"
          Role = "Oasis"
         }

        @{NodeName = "CRRC-Prime03"
          Role = "Oasis"
         }

        @{NodeName = "CRRC-Prime04"
          Role = "Oasis"
         }

        @{NodeName = "CRRC-Prime05"
          Role = "Oasis" 
         }

        @{NodeName = "CRRC-Prime06"
          Role = "Oasis"
         }

        @{NodeName = "CRRC-Prime07"
          Role = "Oasis"
         }

        @{NodeName = "CRRC-Prime08"
          Role = "Oasis"
         }

        @{NodeName = "CRRC-Prime09"
          Role = "Oasis"
         }

        @{NodeName = "CRRC-Prime10"
          Role =  "Oasis"
         }

        @{NodeName = "CRRC-Prime11"
          Role =  "Oasis"
         }

        @{NodeName = "CRRC-Poller01"
          Role =  "Oasis"
         }

        @{NodeName = "CRRC-Poller02"
          Role = "Oasis"
         }

        @{NodeName = "CRRC-Poller03"
          Role = "Oasis"
         }

        @{NodeName = "CRRC-Smcache01"
          Role = "Oasis"
         }

        @{NodeName = "CRRC-SMcache02"
          Role = "Oasis"
         }

        @{NodeName = "CRRC-Trackit-DB"
          Role = "Oasis"}

                 )
}
ATIServerPrep -ConfigurationData $cd -OutputPath C:\DSC_Configuration

#SQL Machines
Start-DscConfiguration -Path C:\DSC_Configuration -ComputerName "CNC-Test-Loysql","CNC-Test-SQL","CNE-LOY-SQL01", "SPUR-ATI-SQL01", "TRV-ATI-SQL01", "Star-ATI-SQL01", "Crrc-ATI-SQL01" -Wait -Verbose -Force

#Spur
Start-DscConfiguration -Path C:\DSC_Configuration -ComputerName "SPUR-ATI-SQL01","SPUR-nConn01", "SPUR-nConn02","SPUR-Prime01","SPUR-Prime02","SPUR-Prime03","SPUR-Prime04","SPUR-Prime05","SPUR-Prime06","SPUR-Prime07","SPUR-Prime08","SPUR-Prime09","Spur-Poller01","Spur-SMCache01" -wait -Force -verbose 4> "C:\DSC_Configuration\spurPush $(Get-Date -Format MM-dd-yyyy).txt"

#Comanche Nation Casinos
Start-DscConfiguration -Path C:\DSC_Configuration -ComputerName "cnc-nconnect01", "cnc-nconnect02","CNC-Prime01","CNC-Prime02","CNC-Prime03","CNC-Prime04","CNC-Prime05","CNC-Prime06","CNC-Prime07","CNC-Prime08","CNC-Prime09", "CNC-Prime10","CNC-Prime11", "CNC-Poller01", "CNC-Poller02","CNC-Poller03", "CNC-SMCACHE01","CNC-SMCACHE02" -wait -Force -verbose 4> "C:\DSC_Configuration\CNC $(get-date -Format MM-dd-yyyy).txt"

#CNE
Start-DscConfiguration -Path C:\DSC_Configuration -ComputerName "CNE-LOY-WEB01","CNE-LOY-WEB02","CNE-LOY-APP01","CNE-LOY-GW01" -Wait -Force -Verbose 4> "C:\DSC_Configuration\CNE $(get-date -format MM-dd-yyyy) push.txt"

#Travel
Start-DscConfiguration -Path C:\DSC_Configuration -ComputerName "TRV-ATI-SQL01","TRV-nConnect01","TRV-nConnect02", "TRV-Prime01","TRV-Prime02", "TRV-Prime03", "TRV-Prime04", "TRV-Prime05", "TRV-Prime06","TRV-Prime07", "TRV-Prime08","TRV-Prime09", "TRV-Poller01", "TRV-SMCACHE01" -Wait -Force -Verbose 4> "C:\DSC_Configuration\TRV PUSH $(get-date -format MM-dd-yyyy).txt"

#Star
Start-DscConfiguration -Path C:\DSC_Configuration -ComputerName "STAR-nConnect01","STAR-nConnect02", "STAR-Prime01","STAR-Prime02", "STAR-Prime03", "STAR-Prime04", "STAR-Prime05", "STAR-Prime06","STAR-Prime07", "STAR-Prime08","STAR-Prime09", "Star-poller01", "Star-SMCache01" -Wait -Force -Verbose 4> "C:\DSC_Configuration\STAR PUSH $(get-date -format MM-dd-yyyy).txt"

#Red River
Start-DscConfiguration -Path C:\DSC_Configuration -ComputerName "CRRC-ATI-SQL01","cnc-nconnect01", "cnc-nconnect02","CRRC-Prime01","CRRC-Prime02","CRRC-Prime03","CRRC-Prime04","CRRC-Prime05","CRRC-Prime06","CRRC-Prime07","CRRC-Prime08","CRRC-Prime09", "CRRC-Prime10","CRRC-Prime11", "CRRC-Poller01", "CRRC-Poller02","CRRC-Poller03", "CRRC-SMCACHE01","CRRC-SMCACHE02" -wait -Force -verbose 4>"C:\DSC_Configuration\CRRC PUSH $(get-date -format MM-dd-yyyy).txt"

#TRACK IT
Start-DscConfiguration -Path C:\DSC_Configuration -ComputerName CNC-Trackit-DB -Wait -Verbose -Force 4> "C:\DSC_Configuration\CNC-TRACKIT-DB $(Get-Date -Format MM-dd-yyyy).txt"
Start-DscConfiguration -Path C:\DSC_Configuration -ComputerName CRRC-Trackit-DB -Wait -Verbose -Force 4> "C:\DSC_Configuration\CRRC-TRACKIT-DB $(Get-Date -Format MM-dd-yyyy).txt"
