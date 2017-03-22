#!/bin/bash
#
# This script converts Sysbench IO output file into csv format.
# Author: Srikanth Myakam
# Email	: v-srm@microsoft.com
####

syslog_file_name=$1

if [ "$#" -ne 1 ]; then
  echo "Usage: $0 <sysbench-output.log>" >&2
  exit 1
fi

if [ ! -f $syslog_file_name ]; then
    echo "$1: File not found!"
	exit 1
fi

csv_file=`echo $syslog_file_name | sed s/\.log\.txt//`
csv_file=$csv_file.csv
echo $csv_file

res_AvgLatency=(`cat $syslog_file_name | grep "avg:" | awk '{print $2}' | sed s/ms//`)
res_BlockSize=(`cat $syslog_file_name | grep "Block size "| sed "s/Block size //"`)
res_FileSize=(`cat $syslog_file_name | grep "total file size"| sed "s/ total file size//"`)
res_IOMode=(`cat $syslog_file_name | grep "Using .* I/O mode" | sed 's/Using \(.*\) I\/O mode/\1/'`)
res_Iteration=(`cat $syslog_file_name | grep "iteration "| awk '{print $3}'`)
res_MaxLatency=(`cat $syslog_file_name | grep "max:" | awk '{print $2}' | sed s/ms//`)
res_MinLatency=(`cat $syslog_file_name | grep "min:" | awk '{print $2}' | sed s/ms//`)
res_OtherOperations=(`cat $syslog_file_name | grep "Operations performed:"| awk  '{print $7}'`)
if [ x$res_OtherOperations == "x" ]; then
  res_OtherOperations=(`cat $syslog_file_name | grep "fsyncs/s: "| awk '{print $2}'`)
fi

res_PercentileLatency=(`cat $syslog_file_name | grep "approx.  95 percentile:" | awk '{print $4}' | sed s/ms//`)
if [ x$res_PercentileLatency == "x" ]; then
  res_PercentileLatency=(`cat $syslog_file_name | grep "95th percentile: " |awk '{print $3}'`)
fi

res_ReadBytes=(`cat $syslog_file_name | grep "Read "| awk '{print $2}'`)
if [ x$res_ReadBytes == "x" ]; then
  res_ReadBytes=(`cat $syslog_file_name | grep "read, MiB/s:"| awk '{print $3}' `)
fi

res_ReadOperations=(`cat $syslog_file_name | grep "Operations performed:"| awk  '{print $3}'`)
if [ x$res_ReadOperations == "x" ]; then
  res_ReadOperations=(`cat $syslog_file_name | grep "reads/s: "| awk '{print $2}'`)
fi

res_StartTime=(`cat $syslog_file_name | grep "iteration "| awk '{print $12 ":" $13 ":" $14}'`)
res_TestType=(`cat $syslog_file_name | grep "iteration"| awk  '{print $5}'| sed s/,//`)
res_Throughput=(`cat $syslog_file_name | grep "Read " | awk '{print $8}' | sed s/\(//| sed s/\)//`)
res_TotalEvents=(`cat $syslog_file_name | grep "total number of events:"  | awk '{print $5}'`)
res_TotalOperations=(`cat $syslog_file_name | grep "Operations performed:"| awk  '{print $10}'`)

res_TotalTime=(`cat $syslog_file_name | grep "total time: " | awk '{print $3}'| sed s/s//`)
res_WriteBytes=(`cat $syslog_file_name | grep "Read "| awk '{print $4}'`)
if [ x$res_WriteBytes == "x" ]; then
  res_WriteBytes=(`cat $syslog_file_name | grep "written, MiB/s:"| awk '{print $3}' `)
fi

res_WriteOperations=(`cat $syslog_file_name | grep "Operations performed:"| awk  '{print $5}'`)
if [ x$res_WriteOperations == "x" ]; then
  res_WriteOperations=(`cat $syslog_file_name | grep "writes/s: "| awk '{print $2}'`)
fi
res_threads=(`cat $syslog_file_name | grep "Number of threads:" | sed "s/Number of threads: //"`)
res_TotalBytes=(`cat $syslog_file_name | grep "Read "| awk '{print $7}'`)
res_IOPS=(`cat $syslog_file_name | grep "Requests/sec executed"| awk '{print $1}'`)

res_kernel_version=(`cat $syslog_file_name | grep "Linux.*x86_64.*GNU"| awk '{print $3}'`)
res_total_cpu_cores=(`cat $syslog_file_name| grep "Number of CPU cores" | awk '{print $5}'`)
res_LIS_version=(`cat $syslog_file_name| grep "^version:"| awk '{print $2}'`)
res_Host_version=(`cat $syslog_file_name| grep "Host Build Version" | awk '{print $4}'`)
res_total_memory=(`cat $syslog_file_name |grep "^Memory" | awk '{print $2}'`)
res_total_disks=(`cat $syslog_file_name |grep "^Data disks attached" | awk '{print $4}'`)

if [ "x$res_LIS_version" == "x" ]
then
	res_LIS_version="Default LIS Version"
fi

echo "" > $csv_file-tmp
echo ",VM Properties," >> $csv_file-tmp
echo ",Kernel version,"$res_kernel_version >> $csv_file-tmp
echo ",Total CPU cores,"$res_total_cpu_cores >> $csv_file-tmp
echo ",Memory,"$res_total_memory >> $csv_file-tmp
echo ",Disks,"$res_total_disks >> $csv_file-tmp
echo ",LIS Version,"$res_LIS_version >> $csv_file-tmp
echo ",Host Version,"$res_Host_version >> $csv_file-tmp
echo "" >> $csv_file-tmp

echo "Iteration,StartTime,Threads,FileSize,BlockSize,IOMode,TestType,ReadOperations,WriteOperations,OtherOperations,TotalOperations,ReadBytes,WriteBytes,TotalBytes,Throughput,IOPS,TotalTime(s),TotalEvents,MinLatency(ms),AvgLatency(ms),MaxLatency(ms), 95% PercentileLatency(ms)" > $csv_file

count=0

while [ "x${res_Iteration[$count]}" != "x" ]
do
    IOPS=${res_IOPS[$count]}
    if [ x$IOPS == "x" ]; then
        IOPS=$( python -c "print ${res_ReadOperations[$count]} + ${res_WriteOperations[$count]} + ${res_OtherOperations[$count]}" )
    fi

    TotalOperations=${res_TotalOperations[$count]}
    if [ x$TotalOperations == "x" ]; then
        TotalOperations=$( python -c "print ${res_ReadOperations[$count]} + ${res_WriteOperations[$count]} + ${res_OtherOperations[$count]}" )
    fi

    TotalBytes=${res_TotalBytes[$count]}
    if [ x$TotalBytes == "x" ]; then
        TotalBytes=$( python -c "print ${res_ReadBytes[$count]} + ${res_WriteBytes[$count]}" )
    fi

    Throughput=${res_Throughput[$count]}
    if [ x$Throughput == "x" ]; then
        Throughput=$( python -c "print ${res_ReadBytes[$count]} + ${res_WriteBytes[$count]}" )
    fi

	echo "${res_Iteration[$count]}, ${res_StartTime[$count]}, ${res_threads[$count]}, ${res_FileSize[$count]}, ${res_BlockSize[$count]}, ${res_IOMode[$count]},  ${res_TestType[$count]}, ${res_ReadOperations[$count]}, ${res_WriteOperations[$count]}, ${res_OtherOperations[$count]}, $TotalOperations, ${res_ReadBytes[$count]}, ${res_WriteBytes[$count]}, $TotalBytes, $Throughput, $IOPS, ${res_TotalTime[$count]}, ${res_TotalEvents[$count]}, ${res_MinLatency[$count]}, ${res_AvgLatency[$count]}, ${res_MaxLatency[$count]}, ${res_PercentileLatency[$count]}, "  >> $csv_file
	((count++))
done

echo ",Max IOPS of each mode," >> $csv_file-tmp
echo ",Test Mode Max IOPS," >> $csv_file-tmp
modes='rndrd rndwr rndrw seqrd seqwr seqrewr'
for testmode in $modes
do
	max_iops=`cat $csv_file | grep $testmode | sed 's/.*\/sec,//'| sed  's/,.*$//'| sed "s/\\..*//"| sort -g|tail -1`
	if  [ "x$max_iops" != "x" ]
	then
		echo ",$testmode,$max_iops," >> $csv_file-tmp
	fi
done

echo "" >> $csv_file-tmp
echo ",Max IOPS of each BlockSize," >> $csv_file-tmp
modes='rndrd rndwr rndrw seqrd seqwr seqrewr'
block_sizes='1K 2K 4K 8K 16K 32K'
echo ",Test Mode,Block Size,Max IOPS," >> $csv_file-tmp
for testmode in $modes
do
	for block in $block_sizes
	do
		max_iops=`cat $csv_file | grep $testmode | grep " $block" | sed 's/.*\/sec,//'| sed  's/,.*$//'| sed "s/\\..*//"| sort -g|tail -1`
		if  [ "x$max_iops" != "x" ]
		then
			echo ",$testmode,$block,$max_iops," >> $csv_file-tmp
		fi
	done
done

echo "" >> $csv_file-tmp
cat $csv_file >> $csv_file-tmp
mv $csv_file-tmp $csv_file

sed -i  -e  "s/rndrd/Random Read/" $csv_file
sed -i  -e  "s/rndrw/Random Read Write/" $csv_file
sed -i  -e  "s/rndwr/Random Write/" $csv_file
sed -i  -e  "s/seqrd/Sequential Read/" $csv_file
sed -i  -e  "s/seqrewr/Sequential Read Write/" $csv_file
sed -i  -e  "s/seqwr/Sequential Write/" $csv_file

echo "Output csv file: $csv_file created successfully." >> $syslog_file_name
echo "LOGPARSER COMPLETED." >> $syslog_file_name
