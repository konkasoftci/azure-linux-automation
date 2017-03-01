#!/bin/bash

#######################################################################
#
# Linux on Hyper-V and Azure Test Code, ver. 1.0.0
# Copyright (c) Microsoft Corporation
#
# All rights reserved. 
# Licensed under the Apache License, Version 2.0 (the ""License"");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#     http://www.apache.org/licenses/LICENSE-2.0  
#
# THIS CODE IS PROVIDED *AS IS* BASIS, WITHOUT WARRANTIES OR CONDITIONS
# OF ANY KIND, EITHER EXPRESS OR IMPLIED, INCLUDING WITHOUT LIMITATION
# ANY IMPLIED WARRANTIES OR CONDITIONS OF TITLE, FITNESS FOR A PARTICULAR
# PURPOSE, MERCHANTABLITY OR NON-INFRINGEMENT.
#
# See the Apache Version 2.0 License for specific language governing
# permissions and limitations under the License.
# 
#######################################################################

#######################################################################
#
# perf_IPERF3.sh
# Author : SHITAL SAVEKAR <v-shisav@microsoft.com>
#
# Description:
#    Download and run IPERF3 network performance tests.
#    This script needs to be run on client VM.
#
# Supported Distros:
#    Ubuntu 16.04
#######################################################################

CONSTANTS_FILE="./constants.sh"
ICA_TESTRUNNING="TestRunning"      # The test is running
ICA_TESTCOMPLETED="TestCompleted"  # The test completed successfully
ICA_TESTABORTED="TestAborted"      # Error during the setup of the test
ICA_TESTFAILED="TestFailed"        # Error occurred during the test
touch ./IPERF3Test.log

DisableFirewallsIpatables()
{
	if [ ${2} == "CentOS7" ]; then
		LogMsg "Disabling Firewall & Iptables in ${2} ${1} for IPERF3 test..."
		ssh ${1} "iptables -nL; systemctl stop iptables.service; systemctl disable iptables.service; systemctl mask firewalld; systemctl stop firewalld.service; systemctl disable firewalld.service; iptables -nL"
		LogMsg "Disabling Firewall & Iptables in ${2} ${1} for IPERF3 test...DONE"
	elif [ ${2} == "CentOS6" ]; then
		LogMsg "Disabling Firewall & Iptables in ${2} ${1} for IPERF3 test..."
		ssh ${1} "iptables -nL; service iptables save; service iptables stop; chkconfig iptables off; service ip6tables save; service ip6tables stop; chkconfig ip6tables off"; iptables -nL 
		LogMsg "Disabling Firewall & Iptables in ${2} ${1} for IPERF3 test...DONE"
	elif [ ${2} == "Ubuntu" ]; then
		LogMsg "Disabling Firewall & Iptables in ${2} ${1} for IPERF3 test..."
		ssh ${1} "iptables -nL; ufw disable; iptables -nL" 
		LogMsg "Disabling Firewall & Iptables in ${2} ${1} for IPERF3 test...DONE"
	fi
}

ConfigureIperf3Ubuntu()
{
	LogMsg "Configuring ${1} for IPERF3 test..."
	ssh ${1} "apt-get update"
	ssh ${1} "apt-get -y install iperf3 sysstat bc "
	if [ $IPversion -eq 6 ]; then	
		scp ConfigureUbuntu1604IPv6.sh ${1}:
		ssh ${1} "chmod +x ConfigureUbuntu1604IPv6.sh"
		ssh ${1} "./ConfigureUbuntu1604IPv6.sh"
	fi
	DisableFirewallsIpatables ${1} "Ubuntu"
	LogMsg "Configuring ${1} for IPERF3 test...Done"
}

ConfigureIperf3CentOS7()
{			
	LogMsg "Configuring ${1} for IPERF3 test..."
	iperf3CentOS7pkg="iperf3-3.1.6-1.el7.x86_64.rpm"
	ssh ${1} "yum install -y wget sysstat bc psmisc"
	
	installed=`ssh ${1} which iperf3`
	if [ ! $installed ]; then
        	LogMsg "INFO: Installing iperf3"

		iperf3lPkg=$(ssh ${1} "ls | grep ${iperf3CentOS7pkg}")
		if [ -z "$iperf3lPkg" ]; then
			ssh ${1} "wget https://konkasoftpackages.blob.core.windows.net/linuxbinaries/${iperf3CentOS7pkg}"
		fi
		ssh ${1} "yum install -y ${iperf3CentOS7pkg}"
		if [ $? -ne 0 ]; then
			LogMsg "Error: Unable to install iperf3"
			exit 1
		fi

	fi	
	LogMsg "Disabling Firewall & Iptables in ${1} for IPERF3 test..."
	DisableFirewallsIpatables ${1} "CentOS7"
	LogMsg "Configuring ${1} for IPERF3 test...Done"
}

ConfigureIperf3CentOS6()
{			
	iperf3CentOS6pkg="iperf3-3.0.12-1.el6.x86_64.rpm"
	LogMsg "INFO: CentOS6: installing required packages"
	ssh ${1} "yum install -y wget sysstat bc psmisc"
	
	installed=`ssh ${1} which iperf3`
	if [ ! $installed ]; then
		LogMsg "INFO: Installing iperf3"

		iperf3lPkg=$(ssh ${1} "ls | grep ${iperf3CentOS6pkg}")
		if [ -z "$iperf3lPkg" ]; then			
			ssh ${1} "wget https://konkasoftpackages.blob.core.windows.net/linuxbinaries/${iperf3CentOS6pkg}"
		fi
		ssh ${1} yum install -y ${iperf3CentOS6pkg}
		if [ $? -ne 0 ]; then
			LogMsg "Error: Unable to install iperf3"
			exit 1
		fi
	fi
	DisableFirewallsIpatables ${1} "CentOS6"
	LogMsg "Configuring ${1} for IPERF3 test...Done"	
}


LogMsg()
{
    echo `date "+%b %d %Y %T"` : "${1}"    # Add the time stamp to the log message
    echo "${1}" >> ./IPERF3Test.log
}

UpdateTestState()
{
    echo "${1}" > ./state.txt
}

if [ -e ${CONSTANTS_FILE} ]; then
    source ${CONSTANTS_FILE}
else
    errMsg="Error: missing ${CONSTANTS_FILE} file"
    LogMsg "${errMsg}"
    UpdateTestState $ICA_TESTABORTED
    exit 10
fi

if [ ! ${server} ]; then
	errMsg="Please add/provide value for server in constants.sh. server=<server ip>"
	LogMsg "${errMsg}"
	echo "${errMsg}" >> ./summary.log
	UpdateTestState $ICA_TESTABORTED
	exit 1
fi
if [ ! ${client} ]; then
	errMsg="Please add/provide value for client in constants.sh. client=<client ip>"
	LogMsg "${errMsg}"
	echo "${errMsg}" >> ./summary.log
	UpdateTestState $ICA_TESTABORTED
	exit 1
fi

if [ ! ${testDuration} ]; then
	errMsg="Please add/provide value for testDuration in constants.sh. testDuration=60"
	LogMsg "${errMsg}"
	echo "${errMsg}" >> ./summary.log
	UpdateTestState $ICA_TESTABORTED
	exit 1
fi

if [ ! ${testType} ]; then
        errMsg="Please add/provide value for testType in constants.sh. testType=tcp/udp"
        LogMsg "${errMsg}"
        echo "${errMsg}" >> ./summary.log
        UpdateTestState $ICA_TESTABORTED
        exit 1
fi

if [ ! ${max_parallel_connections_per_instance} ]; then
        errMsg="Please add/provide value for max_parallel_connections_per_instance in constants.sh. max_parallel_connections_per_instance=60"
        LogMsg "${errMsg}"
        echo "${errMsg}" >> ./summary.log
        UpdateTestState $ICA_TESTABORTED
        exit 1
fi

if [ ! ${connections} ]; then
        errMsg="Please add/provide value for connections in constants.sh. connections=(1 2 4 8 ....)"
        LogMsg "${errMsg}"
        echo "${errMsg}" >> ./summary.log
        UpdateTestState $ICA_TESTABORTED
        exit 1
fi

if [ ! ${bufferLenghs} ]; then
        errMsg="Please add/provide value for bufferLenghs in constants.sh. bufferLenghs=(1 8). Note buffer lenghs are in KB"
        LogMsg "${errMsg}"
        echo "${errMsg}" >> ./summary.log
        UpdateTestState $ICA_TESTABORTED
        exit 1
fi

if [ ! ${IPversion} ]; then
        errMsg="Please add/provide value for IPversion in constants.sh. IPversion=4/6."
        LogMsg "${errMsg}"
        echo "${errMsg}" >> ./summary.log
        UpdateTestState $ICA_TESTABORTED
        exit 1
fi

if [ $IPversion -eq 6 ]; then
	if [ ! ${serverIpv6} ]; then
        	errMsg="Please add/provide value for serverIpv6 in constants.sh"
	        LogMsg "${errMsg}"
	        echo "${errMsg}" >> ./summary.log
	        UpdateTestState $ICA_TESTABORTED
	        exit 1
	fi
        if [ ! ${clientIpv6} ]; then
                errMsg="Please add/provide value for clientIpv6 in constants.sh."
                LogMsg "${errMsg}"
                echo "${errMsg}" >> ./summary.log
                UpdateTestState $ICA_TESTABORTED
                exit 1
        fi
	
fi


#connections=(64 128)
#BufferLenghts are in K
#max_parallel_connections_per_instance=64
#Make & build IPERF3 on client and server Machine

DISTRO=`grep -ihs "Ubuntu\|Suse\|Fedora\|Debian\|CentOS\|Red Hat Enterprise Linux" /etc/{issue,*release,*version}`
echo "###############$DISTRO########################"
case $DISTRO in
	Ubuntu*)
		echo "UBUNTU"
		LogMsg "Configuring client ${client}..."
		ConfigureIperf3Ubuntu ${client}

		LogMsg "Configuring server ${server}..."
		ConfigureIperf3Ubuntu ${server}
		;;
	Fedora*)
		echo "FEDORA";;
	*release*7.*)
		case $DISTRO in 
			Red*Hat*)
				echo "RHEL 7.*"
				;;
			*CentOS*)
				echo "CENTOS 7.*"
				;;
		esac
		LogMsg "Configuring client ${client}..."
		ConfigureIperf3CentOS7 ${client}

		LogMsg "Configuring server ${server}..."
		ConfigureIperf3CentOS7 ${server}
		;;
	*release*6.*)
		case $DISTRO in 
			Red*Hat*)
				echo "RHEL 6.*"
				;;
			*CentOS*)
				echo "CENTOS 6.*"
				;;
		esac
		LogMsg "Configuring client ${client}..."
		ConfigureIperf3CentOS6 ${client}

		LogMsg "Configuring server ${server}..."
		ConfigureIperf3CentOS6 ${server}
		;;
	*SUSE*)
		echo "SLES"
		ConfigSLES
		;;
	Debian*)
		echo "DEBIAN";;
esac


ssh ${server} "rm -rf iperf-server-*"
ssh ${client} "rm -rf iperf-client-*"
ssh ${client} "rm -rf iperf-server-*"


#connections=(1 2 4 8 16 32 64 128 256 512 1024)
#BufferLenghts are in K
#bufferLenghs=(1 8)

for current_buffer in "${bufferLenghs[@]}"
        do
        for current_test_connections in "${connections[@]}"
        do
		if [ $current_test_connections -lt $max_parallel_connections_per_instance ]
		then
			num_threads_P=$current_test_connections
			num_threads_n=1
		else
			num_threads_P=$max_parallel_connections_per_instance
			num_threads_n=$(($current_test_connections / $num_threads_P))
		fi
		
		ssh ${server} "killall iperf3"
		ssh ${client} "killall iperf3"
		LogMsg "Starting $num_threads_n iperf3 server instances on $server.."
		startPort=750
		currentPort=$startPort
		currentIperfInstanses=0
		while [ $currentIperfInstanses -lt $num_threads_n ]
		do
			currentIperfInstanses=$(($currentIperfInstanses+1))
			serverCommand="iperf3 -s -1 -J -i10 -f g -p ${currentPort} > iperf-server-${testType}-IPv${IPversion}-buffer-${current_buffer}K-conn-$current_test_connections-instance-${currentIperfInstanses}.txt 2>&1"
			ssh ${server} $serverCommand &
			LogMsg "Executed: $serverCommand"
			currentPort=$(($currentPort+1))
			sleep 0.1
		done

		LogMsg "$num_threads_n iperf server instances started on $server.."
		sleep 5
		LogMsg "Starting client.."
		startPort=750
		currentPort=$startPort
		currentIperfInstanses=0
		if [ $IPversion -eq 4 ]; then
				testServer=$server
		else
				testServer=$serverIpv6
		fi
		#ssh ${client} "./sar-top.sh ${testDuration} $current_test_connections root" &
		#ssh ${server} "./sar-top.sh ${testDuration} $current_test_connections root" &
		while [ $currentIperfInstanses -lt $num_threads_n ]
		do
			currentIperfInstanses=$(($currentIperfInstanses+1))

			if [[ "$testType" == "udp" ]];
			then
				clientCommand="iperf3 -c $testServer -u -b 0 -J -f g -i10 -l ${current_buffer}K -t ${testDuration} -p ${currentPort} -P $num_threads_P -${IPversion} > iperf-client-${testType}-IPv${IPversion}-buffer-${current_buffer}K-conn-$current_test_connections-instance-${currentIperfInstanses}.txt 2>&1"
			fi
                        if [[ "$testType" == "tcp" ]];
                        then
                                clientCommand="iperf3 -c $testServer -b 0 -J -f g -i10 -w ${current_buffer}K -t ${testDuration} -p ${currentPort} -P $num_threads_P -${IPversion} > iperf-client-${testType}-IPv${IPversion}-buffer-${current_buffer}K-conn-$current_test_connections-instance-${currentIperfInstanses}.txt 2>&1"
                        fi
			
			ssh ${client} $clientCommand &
			LogMsg "Executed: $clientCommand"
			currentPort=$(($currentPort+1))
			sleep 0.1
		done
		LogMsg "Iperf3 running buffer ${current_buffer}K $num_threads_P X $num_threads_n ..."
		sleep ${testDuration}
		sleep 5
		var=`ps -C "iperf3 -c" --no-headers | wc -l`
		while [ $var -gt 0 ]
		do
			sleep 1
			var=`ps -C "iperf3 -c" --no-headers | wc -l`
			LogMsg "Iperf3 running buffer ${current_buffer}K $num_threads_P X $num_threads_n. Waiting to finish $var instances."
		done
		#Sleep extra 5 seconds.
		sleep 1
		LogMsg "Iperf3 Finished buffer ${current_buffer}K  $num_threads_P X $num_threads_n ..."
	done
done
scp ${server}:iperf-server-* ./
UpdateTestState ICA_TESTCOMPLETED
