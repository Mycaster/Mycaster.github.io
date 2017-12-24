#!/bin/bash

function usage()
{
	echo -e "\033[31m theme $theme not exists, try:\033[0m"
	ls themes/	
}

if [ "$#" == "0" ];then
	usage	
	exit
fi

theme=$1
configfile="_config.yml"

if [ ! -d "themes/$theme" ];then
	usage
	exit
fi

if [ ! -f "$configfile" ];then
	echo -e "\033[31m $configfile not exists \033[0m"
	exit
fi

sed -i "" "/^theme/s/ .*/ $theme/" $configfile

echo "change success ! new theme:"
grep "^theme" $configfile
