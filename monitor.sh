#!/bin/bash

#Do not insert code here

#DO NOT REMOVE THE FOLLOWING TWO LINES
git add $0 >> .local.git.out
git commit -a -m "Lab 2 commit" >> .local.git.out
git push >> .local.git.out || echo

# cycles per second
hertz=$(getconf CLK_TCK)

function check_arguments {


	#If number of arguments is less than 5, exit. For part 2, the number of arguments should be greater than 7
	if [ "$1" -lt 5 ]; then
		echo "USAGE: "
		echo "$0 {process id} -cpu {utilization percentage} {maximum reports} {time interval}"
		exit
	fi

	CPU_THRESHOLD=$4

	#Extract the memory threshold (part 2 of the script)

	if [ "$1" -gt 7 ]; then
		echo "USAGE: "
		echo "$0 {process id} -cpu {cpu usage percentage} -mem {maximum memory in KB} {maximum reports} {time interval}"
		exit
	fi

  MEM_THRESHOLD=$6

}

function init
{

	#Remove reports directory
	rm -fr ./reports_dir
	mkdir ./reports_dir

	REPORTS_DIR=./reports_dir

	PID=$1 #This is the pid we are going to monitor

	TIME_INTERVAL=${@:$#} #Time interval is the last argument

	MAXIMUM_REPORTS=${@:$#-1:1} #Maximum reports is the argument before the last

}

#This function calculates the CPU usage percentage given the clock ticks in the last $TIME_INTERVAL seconds
function jiffies_to_percentage {
	
	#Get the function arguments (oldstime, oldutime, newstime, newutime)
oldstime=$1
oldutime=$2
newstime=$3
newutime=$4

	#Calculate the elpased ticks between newstime and oldstime (diff_stime), and newutime and oldutime (diff_stime)

diff_stime=$newstime-$oldstime
diff_utime=$newutime-$oldutime


	#You will use the following command to calculate the CPU usage percentage. $TIME_INTERVAL is the user-provided time_interval
	#Note how we are using the "bc" command to perform floating point division

	echo "100 * ( ($diff_stime + $diff_utime) / $hertz) / $TIME_INTERVAL" | bc -l
}


#This function takes as arguments the cpu usage and the memory usage that were last computed
function generate_report {

	
	#if ./reports_dir has more than $MAXIMUM_REPORTS reports, then, delete the oldest report to have room for the current one
  number_reports=$(ls ./reports_dir | wc -l)
  if [ $number_reports -ge $MAXIMUM_REPORTS ]; then
    oldest_report="./reports_dir/`ls -t reports_dir | tail -1`"
    echo "Deleting the oldest report: $oldest_report"
    rm "./reports_dir/`ls -t reports_dir | tail -1`"
  fi

	#Name of the report file
	file_name="$(date +'%d.%m.%Y.%H.%M.%S')"

	#Extracting process name from /proc
	process_name=$(cat /proc/$PID/stat | awk '{print $2}')

	#You may uncomment the following lines to generate the report. Make sure the first argument to this function is the CPU usage
	#and the second argument is the memory usage

	echo "PROCESS ID: $PID" > ./reports_dir/$file_name
	echo "PROCESS NAME: $process_name" >> ./reports_dir/$file_name
	echo "CPU USAGE: $1 %" >> ./reports_dir/$file_name
	echo "MEMORY USAGE: $2 kB" >> ./reports_dir/$file_name
}

#Returns a percentage representing the CPU usage
function calculate_cpu_usage {

	#CPU usage is measured over a period of time. We will use the user-provided interval_time value to calculate 
	#the CPU usage for the last interval_time seconds. For example, if interval_time is 5 seconds, then, CPU usage
	#is measured over the last 5 seconds


	#First, get the current utime and stime (oldutime and oldstime) from /proc/{pid}/stat
oldutime=$(cat /proc/$PID/stat | awk '{print $14}')
oldstime=$(cat /proc/$PID/stat | awk '{print $15}')

	#Sleep for time_interval
sleep $TIME_INTERVAL

	#Now, get the current utime and stime (newutime and newstime) /proc/{pid}/stat
newutime=$(cat /proc/$PID/stat | awk '{print $14}')
newstime=$(cat /proc/$PID/stat | awk '{print $15}')

	#The values we got so far are all in jiffier (not Hertz), we need to convert them to percentages, we will use the function
	#jiffies_to_percentage

	percentage=$(jiffies_to_percentage $oldutime $oldstime $newutime $newstime)


	#Return the usage percentage
	echo "$percentage" #return the CPU usage percentage
}

function calculate_mem_usage
{
	#Let us extract the VmRSS value from /proc/{pid}/status
  #mem_usage=$(cat /proc/$PID/status | awk 'VmRSS')
  mem_usage=$(egrep VmRSS /proc/$PID/status | awk '{print $2}')


	#Return the memory usage
	echo "$mem_usage"
}

function notify
{
	#We convert the float representating the CPU usage to an integer for convenience. We will compare $usage_int to $CPU_THRESHOLD
	cpu_usage_int=$(printf "%.f" $1)

  #Convert mem usage to an integer for convenience
  mem_usage_int=$(printf "%.f" $2)

	#Check if the process has exceeded the thresholds

	#Check if process exceeded its CPU or MEM thresholds. If that is the case, send an email to $USER containing the last report

  if [ $cpu_usage_int -gt $CPU_THRESHOLD ] || [ $mem_usage_int -gt $MEM_THRESHOLD ]; then
    # head gets the newest file in the directory
    last_report="./reports_dir/$(ls -t reports_dir | head -1)"
    #echo $last_report
    echo "Process exceeded thresholds - sending email with usage report"
    cat $last_report | mailx -s 'Newest Usage Report' $USER
  fi

}


check_arguments $# $@

init $1 $@

echo "CPU THRESHOLD: $CPU_THRESHOLD"
echo "MAXIMUM REPORTS: $MAXIMUM_REPORTS"
echo "Time interval: $TIME_INTERVAL" 

#The monitor runs forever
while [ -n "$(ls /proc/$PID)" ] #While this process is alive
do
	#part 1
	cpu_usage=$(calculate_cpu_usage)

	#part 2
	mem_usage=$(calculate_mem_usage)

	generate_report $cpu_usage $mem_usage

	#Call the notify function to send an email to $USER if the thresholds were exceeded
	notify $cpu_usage $mem_usage

done
