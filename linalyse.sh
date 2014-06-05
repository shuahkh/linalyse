#!/bin/bash
# # linalyse
#
# This tool can be used to check if Linux platform has the required
# KABI and KAPI to support the user-space. This tool checks if files
# (sysfs, dev, proc etc.) specified in the input file exist on the
# system and validates the data in those files against the specified
# data in the input file.
#
# Further more, it can be used to check if the system has the required
# packages and libraries are installed on the system. These options take
# input file that lists the required packages/libraries.
#
# Author: Shuah Khan <shuah.kh@samsung.com>
# Copyright (C) 2014 Samsung Electronics Co., Ltd.
#
# This software may be freely redistributed under the terms of the GNU
# General Public License (GPLv2).

VERSION=1.0

EXIT_CODE_0=0
EXIT_CODE_1=1
Verbose=0
verbose_info="Please use -V | --verbose option for more information."

# main
main()
{

if [ "$#" -eq 0 ]
then
	usage $EXIT_CODE_1
fi

# Parse args
args=`getopt -q -n "$0" -o Vvhc:p:l: --long verbose,version,help,check-files:,check-pkgs:,check-libs: -- "$@"`

# Check for input and print usage
if [ $? -ne 0 ]; then
	usage $EXIT_CODE_1
fi

eval set -- "$args"

while true; 
do
    case "$1" in
	-c|--check-files)
	if [ -n "$2" ]; then
		if [[ ! -e $2 ]]; then
			usage $EXIT_CODE_1
		else
			check_platform $2
			exit 0
		fi
	else
		usage $EXIT_CODE_1
	fi
	;;

	-p|--check-pkgs)
	if [ -n "$2" ]; then
		if [[ ! -e $2 ]]; then
			usage $EXIT_CODE_1
		else
			check_pkgs $2
			exit 0
		fi
	else
		usage $EXIT_CODE_1
	fi
	;;

	-l|--check-libs)
	if [ -n "$2" ]; then
		if [[ ! -e $2 ]]; then
			usage $EXIT_CODE_1
		else
			check_libs $2
			exit 0
		fi
	else
		usage $EXIT_CODE_1
	fi
	;;

	-h|--help) usage $EXIT_CODE_0
	;;
	-v|--version)
		echo $0 "Version:" $VERSION
		exit 0;
	;;

	-V|--verbose)
		Verbose=1
	shift;;	

	*)
	usage $EXIT_CODE_1
	break;;
    esac
done

exit 0
}

usage ()
{

echo "Usage: $0 -[c,p,h,v,V] <platform.txt>"
echo -e "\t -c | --check-files platform.txt"
echo -e "\t \t check if files in platform.txt are present on the system"
echo -e "\t \t and validate the data in those files against the specified"
echo -e "\t -p | --check-pkgs pkgs.txt"
echo -e "\t \t check if specified packages are present on the system"
echo -e "\t -l | --check-libs libs"
echo -e "\t \t check if specified libraries are present on the system"
echo -e "\t -h | --help Print help message and exit"
echo -e "\t -v | --version Print version and exit"
echo -e "\t -V | --verbose Print messages per failure and summary results"

exit $1

}

check_platform()
{

fail=0
no_data=0
match_fail=0
matched=0
rfk="Required kernel file"
ms_files=()
nd_files=()
mf_files=()

# split line into fields: filename,[val1],[val2]
while IFS=, read -r -a input; do

	# account for wildcard in filename
	flines=`echo ${input[0]}`
	val1=`echo ${input[1]}`
	val2=`echo ${input[2]}`

	for line in $flines ; do
		if [[ ! -e $line ]]; then
			if [[ $Verbose -eq 1 ]]; then
			echo -e "\t $rfk $line is missing."
			fi
			ms_files+=($line)
			fail=1
		elif [[ -f $line ]]; then
			val=`cat $line`
			if [ -n "`echo $val | sed 's/[0-9]//g'`" ]; then
				if [[ "a$val1" = "a" ]] ; then
					if [[ $Verbose -eq 1 ]]; then
					echo -e "\t $rfk $line has data: $val - Data to compare is unspecified in $1"
					fi
					no_data=1
					nd_files+=($line)
				elif [[ ! "$val" = "$val1" ]]; then
					if [[ $Verbose -eq 1 ]]; then
					echo -e "\t $rfk $line has data: $val - doesn't match the expected: $val1"
					fi
					match_fail=1
					mf_files+=($line)
				fi
			else
				if [[ "a$val1" = "a" ]] && [[ "a$val2" = "a" ]]; then
					if [[ $Verbose -eq 1 ]]; then
					echo -e "\t $rfk $line has data: $val - Data to compare is unspecified in $1"
					fi
					no_data=1
					nd_files+=($line)
				elif [[ "a$val1" = "a" ]]; then
					if [[ ! $val = $val2 ]]; then
						if [[ $Verbose -eq 1 ]]; then
						echo -e "\t $rfk $line has data: $val - doesn't match the expected: $val2"
						fi
						match_fail=1
						mf_files+=($line)
					fi
				elif [[ "a$val2" = "a" ]]; then
					if [[ ! $val = $val1 ]]; then
						if [[ $Verbose -eq 1 ]]; then
						echo -e "\t $rfk $line has data: "$val" - doesn't match the expected: $val1"
						fi
						match_fail=1
						mf_files+=($line)
					fi
				elif [[ $val -ge $val1 ]] && [[ $val -le $val2 ]]; then
					matched=1
				else
					if [[ $Verbose -eq 1 ]]; then
					echo -e "\t $rfk $line data: $val is not within the specified range: $val1 - $val2"
					fi
					match_fail=1
					mf_files+=($line)
				fi
			fi
		fi
	done
done < $1

echo -e "Check Platform Results:"
if [ $fail -ne 0 ]; then
	echo -e "System is missing required kernel files specified in $1"
	printf -- '\t%s\n' "${ms_files[@]}"
else
	echo -e "System has the required kernel files specified in $1"
fi
if [ $no_data -ne 0 ]; then
	echo -e "Some required kernel files in $1 don't have data to check"
	if [[ $Verbose -eq 1 ]]; then
		printf -- '\t%s\n' "${nd_files[@]}"
	else
		echo -e $verbose_info
	fi
fi
if [ $match_fail -ne 0 ]; then
	echo -e "Some required kernel files specified in $1 have invalid data"
	printf -- '\t%s\n' "${mf_files[@]}"
fi

}

check_pkgs()
{

flines=`cat $1`
fail=0
bad_format=0
req_fail=0
rms_pkgs=()
ms_fail=0
ms_pkgs=()
bad_pkgs=()
echo "$0: Start packages check ...."
for line in $flines ; do
	if [[ "$line" =~ "/" ]]  && [[ "$line" =~ "," ]]; then
		if [[ $Verbose -eq 1 ]]; then
		echo -e "Incorrect format for package names in $1"
		fi
		fail=1
		bad_format=1
		bad_pkgs+=($line)
	else
		result=`pkg-config --cflags $line 2>&1 > /dev/null`
		if [[ "$result" =~ "not" ]]; then
			if [[ "$result" =~ "required" ]]; then
				if [[ $Verbose -eq 1 ]]; then
				echo -e "\t $result"
				fi
				fail=1
				req_fail=1
				rms_pkgs+=($line)
			else
				if [[ $Verbose -eq 1 ]]; then
				echo -e "\t Required package $line is missing."
				fi
				fail=1
				ms_fail=1
				ms_pkgs+=($line)
			fi
		fi
	fi
done

if [ $fail -ne 0 ]; then
	if [ $ms_fail -ne 0 ]; then
		echo -e "System is missing required pkgs specified in $1"
		printf -- '\t%s\n' "${ms_pkgs[@]}"
	fi
	if [ $bad_format -ne 0 ]; then
		echo -e "Incorrect format for package names in $1"
		if [[ $Verbose -eq 1 ]]; then
			printf -- '\t%s\n' "${bad_pkgs[@]}"
		else
			echo -e $verbose_info
		fi
	fi
	if [ $req_fail -ne 0 ]; then
		echo -e "System is missing required pkg's depencies specified in $1"
		printf -- '\t%s\n' "${rms_pkgs[@]}"
		echo -e $verbose_info
	fi
else
	echo -e "System has the required pkgs specified in $1"
fi

}

check_libs()
{

flines=`cat $1`
fail=0
bad_format=0
ms_libs=()
bad_libs=()
echo "$0: Start libraries check /usr/lib and /lib ...."
for line in $flines ; do
	if [[ "$line" =~ ".so" ]]; then
		if [ $(find /usr/lib -name $line | wc -l) -eq 0 ]; then
			if [ $(find /lib -name $line | wc -l) -eq 0 ]; then
				fail=1
				if [[ $Verbose -eq 1 ]]; then
				echo -e "\t Required library $line is missing"
				fi
				ms_libs+=($line)
			fi
		fi
	else
		if [[ $Verbose -eq 1 ]]; then
		echo -e "\t Skipping non-library $line"
		fi
		bad_libs+=($line)
		bad_format=1
	fi
done

if [ $fail -ne 0 ]; then
	echo -e "System is missing required libraries specified in $1"
	printf -- '\t%s\n' "${ms_libs[@]}"
else
	if [ $bad_format -ne 0 ]; then
		echo -e "Non-libraries specified in $1"
		if [[ $Verbose -eq 1 ]]; then
			printf -- '\t%s\n' "${bad_libs[@]}"
		else
			echo -e $verbose_info
		fi
	else
		echo -e "System has the required libraries specified in $1"
	fi
fi
}

main "$@"
