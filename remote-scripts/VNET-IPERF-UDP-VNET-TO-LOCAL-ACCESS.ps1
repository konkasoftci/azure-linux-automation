﻿<#-------------Create Deployment Start------------------#>
Import-Module .\TestLibs\RDFELibs.psm1 -Force
$Subtests= $currentTestData.SubtestValues
$SubtestValues = $Subtests.Split(",") 
$result = ""
$testResult = ""
$resultArr = @()
$isDeployed = DeployVMS -setupType $currentTestData.setupType -Distro $Distro -xmlConfig $xmlConfig
if($isDeployed)
{
	#region EXTRACT ALL INFORMATION ABOUT DEPLOYED VMs
	$allVnetData = GetVNETDetailsFromXMLDeploymentData -deploymentType $currentTestData.setupType
	$vnetName = $allVnetData[0]
	$subnet1Range = $allVnetData[1]
	$subnet2Range = $allVnetData[2]
	$vnetDomainDBFilePath = $allVnetData[3]
	$vnetDomainRevFilePath = $allVnetData[4]
	$dnsServerIP = $allVnetData[5]

	$hs1vm1IP = $allVMData[0].InternalIP
	$hs1vm2IP = $allVMData[1].InternalIP
	$hs2vm1IP = $allVMData[2].InternalIP
	$hs2vm2IP = $allVMData[3].InternalIP

	$hs1vm1Hostname = $allVMData[0].RoleName
	$hs1vm2Hostname = $allVMData[1].RoleName
	$hs2vm1Hostname = $allVMData[2].RoleName
	$hs2vm2Hostname = $allVMData[3].RoleName

	$hs1VIP = $allVMData[0].PublicIP
	$hs2VIP = $allVMData[2].PublicIP

	$hs1ServiceUrl = $allVMData[0].URL
	$hs2ServiceUrl = $allVMData[2].URL

	$hs1vm1sshport = $allVMData[0].SSHPort
	$hs1vm2sshport = $allVMData[1].SSHPort
	$hs2vm1sshport = $allVMData[2].SSHPort
	$hs2vm2sshport = $allVMData[3].SSHPort

	$hs1vm1tcpport = $allVMData[0].TCPtestPort
	$hs1vm2tcpport = $allVMData[1].TCPtestPort
	$hs2vm1tcpport = $allVMData[2].TCPtestPort
	$hs2vm2tcpport = $allVMData[3].TCPtestPort

	$hs1vm1udpport = $allVMData[0].UDPtestPort
	$hs1vm2udpport = $allVMData[1].UDPtestPort
	$hs2vm1udpport = $allVMData[2].UDPtestPort
	$hs2vm2udpport = $allVMData[3].UDPtestPort

	$SSHDetails = ""
	$HostnameDIPDetails = ""
	foreach ($vmData in $allVMData)
	{
		if($SSHDetails)
		{
			$SSHDetails = $SSHDetails + "^$($vmData.PublicIP)" + ':' +"$($vmData.SSHPort)"
		}
		else
		{
			$SSHDetails = "$($vmData.PublicIP)" + ':' +"$($vmData.SSHPort)"
		}
		$VMhostname = $vmData.RoleName
		$VMDIP = $vmData.InternalIP
		if($HostnameDIPDetails)
		{
			$HostnameDIPDetails = $HostnameDIPDetails + "^$VMhostname" + ':' +"$VMDIP"
		}
		else
		{
			$HostnameDIPDetails = "$VMhostname" + ':' +"$VMDIP"
		}
	}	
	#endregion
	try
	{
#region CONFIGURE VNET VMS AND MAKE THEM READY FOR VNET TEST EXECUTION...
		ConfigureVNETVms -SSHDetails $SSHDetails -vnetDomainDBFilePath $vnetDomainDBFilePath -dnsServerIP $dnsServerIP			
#region DEFINE LOCAL NET VMS
		if ($UseAzureResourceManager)
		{
			$dnsServerInfo = $xmlConfig.config.Azure.Deployment.Data.ARMdnsServer
			$mysqlServerInfo = $xmlConfig.config.Azure.Deployment.Data.ARMmysqlServer
		}
		else
		{
			$dnsServerInfo = $xmlConfig.config.Azure.Deployment.Data.dnsServer
			$mysqlServerInfo = $xmlConfig.config.Azure.Deployment.Data.mysqlServer
		}
		$dnsServer = CreateVMNode -nodeIp $dnsServerInfo.IP -nodeSshPort 22 -user $dnsServerInfo.Username -password $dnsServerInfo.Password -nodeHostname $dnsServerInfo.Hostname
		$mysqlServer = CreateVMNode -nodeIp $mysqlServerInfo.IP -nodeSshPort 22 -user $mysqlServerInfo.Username -password $mysqlServerInfo.Password -nodeHostname $mysqlServerInfo.Hostname
#endregion

#region DEFINE A INTERMEDIATE VM THAT WILL BE USED FOR ALL OPERATIONS DONE ON THE LOCAL NET VMS [DNS SERVER, NFSSERVER, MYSQL SERVER]
		$intermediateVM = CreateVMNode -nodeIp $hs1VIP -nodeSshPort $hs1vm1sshport -user $user -password $password -nodeDip $hs1vm1IP -nodeHostname $hs1vm1Hostname
#endregion
		
#region Upload all files to VNET VMS.. 

		$currentWindowsfiles = $currentTestData.files
		UploadFilesToAllDeployedVMs -SSHDetails $SSHDetails -files $currentWindowsfiles 

#Make python files executable
		#RunLinuxCmdOnAllDeployedVMs -SSHDetails $SSHDetails -command "chmod +x *"
#endregion

#region Upload all files to LOCAL NET VMS.. 
		$currentLinuxFiles = ConvertFileNames -ToLinux -currentWindowsFiles $currentTestData.files -expectedLinuxPath "/home/$user"
		RemoteCopyRemoteVM -upload -intermediateVM $intermediateVM -remoteVM $dnsServer  -remoteFiles $currentLinuxFiles
		RemoteCopyRemoteVM -upload -intermediateVM $intermediateVM -remoteVM $mysqlServer  -remoteFiles $currentLinuxFiles
# Make them executable..
		RunLinuxCmdOnRemoteVM -intermediateVM $intermediateVM -remoteVM $dnsServer -remoteCommand "chmod +x /home/$user/*.py" -runAsSudo
		RunLinuxCmdOnRemoteVM -intermediateVM $intermediateVM -remoteVM $mysqlServer -remoteCommand "chmod +x /home/$user/*.py" -runAsSudo
#endregion

#region CONFIGURE DSN SERVER WITH IP ADDRESSES OF DEPLOYED VNET VMs...

		ConfigureDnsServer -intermediateVM $intermediateVM -DnsServer $dnsServer -HostnameDIPDetails $HostnameDIPDetails -vnetDomainDBFilePath $vnetDomainDBFilePath -vnetDomainREVFilePath $vnetDomainRevFilePath
#endregion
		$isAllConfigured = "True"
#endregion
	}
	catch
	{
			$isAllConfigured = "False"
			$ErrorMessage =  $_.Exception.Message
			LogErr "EXCEPTION : $ErrorMessage"   
	}
	if ($isAllConfigured -eq "True")
	{
#region TEST EXECUTION  
		$udpServer = $mysqlServer
		$udpServer.cmd = "/home/$user/start-server.py -u yes -p 990 -m yes"
		$resultArr = @()
		foreach ($Value in $SubtestValues) 
		{
			mkdir $LogDir\$Value -ErrorAction SilentlyContinue | out-null
			switch ($Value)
			{

				"HS1VM1" {
					$udpClient = CreateIperfNode -user $user -password $password -nodeIp $hs1VIP -nodeSshPort $hs1vm1sshport -nodeUdpPort $hs1vm1udpport -nodeDip $hs1vm1IP -nodeHostname $hs1vm1Hostname
				}
				"HS1VM2" {
					$udpClient = CreateIperfNode -user $user -password $password -nodeIp $hs1VIP -nodeSshPort $hs1vm2sshport -nodeUdpPort $hs1vm2udpport -nodeDip $hs1vm2IP -nodeHostname $hs1vm2Hostname
				}
				"HS2VM1" {
					$udpClient = CreateIperfNode -user $user -password $password -nodeIp $hs2VIP -nodeSshPort $hs2vm1sshport -nodeUdpPort $hs2vm1udpport -nodeDip $hs2vm1IP -nodeHostname $hs2vm1Hostname
				}
				"HS2VM2" {
					$udpClient = CreateIperfNode -user $user -password $password -nodeIp $hs2VIP -nodeSshPort $hs2vm2sshport -nodeUdpPort $hs2vm2udpport -nodeDip $hs2vm2IP -nodeHostname $hs2vm2Hostname
				}
			}
			foreach ($mode in $currentTestData.TestMode.Split(","))
			{ 
				try
				{
					$testResult = ""

					if(($mode -eq "IP") -or ($mode -eq "VIP") -or ($mode -eq "DIP"))
					{
						$udpClient.cmd  = "$python_cmd start-client.py -c $($udpServer.ip) -p 990 -t10 -u yes -l 1420"
					}

					if(($mode -eq "URL") -or ($mode -eq "Hostname"))
					{
						$udpClient.cmd  = "$python_cmd start-client.py -c $($udpServer.hostname) -p 990 -t10 -u yes -l 1420"
					}
					LogMsg "UDP Test Started for $Value in $mode mode.."

					mkdir $LogDir\$Value\$mode -ErrorAction SilentlyContinue | out-null
					$udpServer.logDir = $LogDir + "\$Value\$mode"
					$udpClient.logDir = $LogDir + "\$Value\$mode"
					$testResult = IperfVnetToLocalUdpTest -vnetAsClient $udpClient -localAsServer $udpServer

					LogMsg "Test Status for $mode mode - $testResult"
				}
				catch
				{
					$ErrorMessage =  $_.Exception.Message
					LogErr "EXCEPTION : $ErrorMessage"   
				}
				Finally
				{
					$metaData = "$Value : $mode"
					if (!$testResult)
					{
						$testResult = "Aborted"
					}
					$resultArr += $testResult
					$resultSummary +=  CreateResultSummary -testResult $testResult -metaData $metaData -checkValues "PASS,FAIL,ABORTED" -testName $currentTestData.testName# if you want to publish all result then give here all test status possibilites. if you want just failed results, then give here just "FAIL". You can use any combination of PASS FAIL ABORTED and corresponding test results will be published!
				}   
			}
		}
#endregion
	}
	else
	{
			LogErr "Test Aborted due to Configuration Failure.."
			$testResult = "Aborted"
			$resultArr += $testResult
	}
}
else
{
		$testResult = "Aborted"
		$resultArr += $testResult
}

$result = GetFinalResultHeader -resultarr $resultArr


#region Clenup the DNS server.
$dnsServer.cmd = "echo $($dnsServer.password) | sudo -S /home/$user/CleanupDnsServer.py -D $vnetDomainDBFilePath -r $vnetDomainRevFilePath"
RunLinuxCmdOnRemoteVM -intermediateVM $intermediateVM -remoteVM $dnsServer -runAsSudo -remoteCommand $dnsServer.cmd
#endregion

#Clean up the setup
DoTestCleanUp -result $result -testName $currentTestData.testName -deployedServices $isDeployed -ResourceGroups $isDeployed

#Return the result and summery to the test suite script..
return $result , $resultSummary
