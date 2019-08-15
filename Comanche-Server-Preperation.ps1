Configuration ATIServerPrep 
{
  Param
    ( [String]
      $TimeZone = 'Central Standard Time'
    )

Import-DscResource -ModuleName 'PSDesiredStateConfiguration','NetworkingDSC' , 'xSystemSecurity', 'cDTC', 'ComputerManagementDsc'

Node $AllNodes.NodeName {

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
       AuthenticationLevel = "NoAuth"
     }

#Power Plan
     PowerPlan SetPlanHighPerformance
        {
          IsSingleInstance = 'Yes'
          Name             = 'High performance'
        }

#IP6 Disable
     NetAdapterBinding DisableIPv6
        {
            InterfaceAlias = 'Ethernet0'
            ComponentId    = 'ms_tcpip6'
            State          = 'Disabled'
        }

#IPV4 disable nic Power Management
     Script DisablePowerManagement
       {
         TestScript = {
                        $adapterPower = Get-NetAdapterPowerManagement
                        
                        If (
                             $adapterPower.ArpOffload -eq "Unsupported"  -and $adapterPower.NSOffload -eq "Unsupported" -and $adapterPower.RsnRekeyOffload -eq "Unsupported" -and $adapterPower.D0PacketCoalescing-eq "Unsupported" -and $adapterPower.SelectiveSuspend -eq "Unsupported" -and $adapterPower.DeviceSleepOnDisconnect -eq "Unsupported" -and $adapterPower.WakeOnMagicPacket -eq "Unsupported" -and $adapterPower.WakeOnPattern -eq "Unsupported"
                           ){return $true}
                             
                       Else {return $false}
                      }

         SetScript = {Disable-NetAdapterPowerManagement -Name 'Ethernet0' -NoRestart}

         GetScript = {Get-NetAdapterPowerManagement}
       }

#Registry edit for HTTP2
   Registry HTTP2Disable1  {
     Ensure = "Present"
     Key = "HKEY_LOCAL_MACHINE\System\CurrentControlSet\Services\HTTP\Parameters"
     ValueName = "EnableHttp2Tls"
     ValueData = "0"
   }

   Registry HTTP2Disable2 {
     Ensure = "Present"
     Key = "HKEY_LOCAL_MACHINE\System\CurrentControlSet\Services\HTTP\Parameters"
     ValueName = "EnableHttp2Cleartext"
     ValueData = "0"
   }
      
  }

}
#Only allowed one node name change as needed

$cd = @{
    AllNodes = @(

        @{
            NodeName = "CNC-ATI-SQL01"
            Role = "OASISSQL"
         }
        
        @{NodeName = "CNC-Prime01"}
        @{NodeName = "CNC-Prime02"}
        @{NodeName = "CNC-Prime03"}
        @{NodeName = "CNC-Prime04"}
        @{NodeName = "CNC-Prime05"}
        @{NodeName = "CNC-Prime06"}
        @{NodeName = "CNC-Prime07"}
        @{NodeName = "CNC-Prime08"}
        @{NodeName = "CNC-Prime09"}
        @{NodeName = "CNC-Prime10"}
        @{NodeName = "CNC-Prime11"}
        @{NodeName = "CNC-Poller01"}
        @{NodeName = "CNC-Poller02"}
        @{NodeName = "CNC-Poller03"}
        @{NodeName = "CNE-LOY-SQL01"}
        @{NodeName = "CNE-LOY-WEB01"}
        @{NodeName = "CNE-LOY-WEB02"}
        @{NodeName = "CNE-LOY-APP01"}
        @{NodeName = "CNE-LOY-APP02"}
        @{NodeName = "CNE-LOY-GW01" }

                 )
}
ATIServerPrep -ConfigurationData $cd -OutputPath C:\DSC_Configuration

#Start-DscConfiguration -Path C:\DSC_Configuration\ -ComputerName "CNC-PRIME01" -Wait -Force -Verbose

#Start-DscConfiguration -Path C:\DSC_Configuration\ -ComputerName "CNC-PRIME02" -Wait -Force -Verbose
#Start-DscConfiguration -Path C:\DSC_Configuration\ -ComputerName "CNC-PRIME03" -Wait -Force -Verbose
#Start-DscConfiguration -Path C:\DSC_Configuration\ -ComputerName "CNC-PRIME04" -Wait -Force -Verbose
#Start-DscConfiguration -Path C:\DSC_Configuration\ -ComputerName "CNC-PRIME05" -Wait -Force -Verbose
#Start-DscConfiguration -Path C:\DSC_Configuration\ -ComputerName "CNC-PRIME06" -Wait -Force -Verbose
#Start-DscConfiguration -Path C:\DSC_Configuration\ -ComputerName "CNC-PRIME07" -Wait -Force -Verbose
Start-DscConfiguration -Path C:\DSC_Configuration\ -ComputerName "CNC-PRIME08" -Wait -Force -Verbose
#Start-DscConfiguration -Path C:\DSC_Configuration\ -ComputerName "CNC-PRIME09" -Wait -Force -Verbose
#Start-DscConfiguration -Path C:\DSC_Configuration\ -ComputerName "CNC-PRIME10" -Wait -Force -Verbose
Start-DscConfiguration -Path C:\DSC_Configuration\ -ComputerName "CNC-PRIME11" -Wait -Force -Verbose
Start-DscConfiguration -Path C:\DSC_Configuration\ -ComputerName "CNC-Poller01" -Wait -Force -Verbose
Start-DscConfiguration -Path C:\DSC_Configuration\ -ComputerName "CNC-Poller02" -Wait -Force -Verbose
Start-DscConfiguration -Path C:\DSC_Configuration\ -ComputerName "CNC-Poller03" -Wait -Force -Verbose
Start-DscConfiguration -Path C:\DSC_Configuration\ -ComputerName "CNE-LOY-SQL01" -Wait -Force -Verbose
Start-DscConfiguration -Path C:\DSC_Configuration\ -ComputerName "CNE-LOY-WEB01" -Wait -Force -Verbose
Start-DscConfiguration -Path C:\DSC_Configuration\ -ComputerName "CNE-LOY-WEB02" -Wait -Force -Verbose
Start-DscConfiguration -Path C:\DSC_Configuration\ -ComputerName "CNE-LOY-APP01" -Wait -Force -Verbose
Start-DscConfiguration -Path C:\DSC_Configuration\ -ComputerName "CNE-LOY-APP02" -Wait -Force -Verbose
Start-DscConfiguration -Path C:\DSC_Configuration\ -ComputerName "CNE-LOY-GW01" -Wait -Force -Verbose
