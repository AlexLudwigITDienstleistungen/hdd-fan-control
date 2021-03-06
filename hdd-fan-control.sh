#!/bin/bash
version=1.1.0.0
Config=/etc/hdd-fan-control/hdd-fan-control.config
ConfigRun=/etc/hdd-fan-control/hdd-fan-control.config
ConfigCurrent="empty"
LogDir="/dev/null"
Hdparm="/sbin/hdparm"
Hddtemp="/usr/sbin/hddtemp"
Bc="/usr/bin/bc"

control()
{
	echo "$(date +"%x %X") Config imported" >> $LogDir
	printf "%s Checking if pwm control is enabled: " "$(date +"%x %X")" >> $LogDir
	PwmDevEnabled=$(cat < $PwmDev'_enable')
	if [ $PwmDevEnabled -eq 1 ];
	then
		echo "OK." >> $LogDir
	elif [ $PwmDevEnabled -eq 0 ];
	then	echo "OK." >> $LogDir
	else
		echo "Error. Control is in state $PwmDevEnabled." >> $LogDir
		printf "%s Trying to activate pwm control: " "$(date +"%x %X")" >> $LogDir
		$(echo 1 > $PwmDev'_enable')
		$(echo 255 > $PwmDev)
		PwmValue=$(cat < $PwmDev)
		if [ $PwmValue -eq 255 ];
		then
			echo "OK." >> $LogDir
		else
			echo "Error. Pwm control couldn't be activated. Exiting now." >> $LogDir
			break
		fi
	fi
	if [ "$HddRefOpt" = "y" ];
	then
		if $Hdparm -C $HddRef | grep -q "$StandbyValue";
		then
				HddState=$($Hdparm -C $Hdd)
				if $Hdparm -C $Hdd | grep -q "$StandbyValue";
				then
						PwmState=$(cat < $PwmDev)
						if [ $PwmState -eq $PwmLow ] 2>/dev/null;
						then
							echo "$(date +"%x %X") Harddisk is already in standby. Nothing to do." >> $LogDir
						else
							echo "$(date +"%x %X") Harddisk is in standby but PWM signal is wrong." >> $LogDir
							printf "%s Setting Fan now to $PwmLow:" "$(date +"%x %X")" >> $LogDir
							PwmResult=$(echo $PwmLow > $PwmDev)
							if [ "$PwmResult" = "" ];
							then
								echo "Ok." >> $LogDir
							else
								echo "$PwmResult" >> $LogDir
							fi
						fi
						break
				else
						echo "$(date +"%x %X") Reference Harddisk is in standby." >> $LogDir
						printf "%s Go to standby now:" "$(date +"%x %X")" >> $LogDir
						echo $($Hdparm -y $Hdd) >> $LogDir
						printf "%s Setting Fan now to $PwmLow:" "$(date +"%x %X")" >> $LogDir
						PwmResult=$(echo $PwmLow > $PwmDev)
						if [ "$PwmResult" = "" ];
						then
							echo "Ok." >> $LogDir
						else
							echo "$PwmResult" >> $LogDir
						fi
						break
				fi
		else
				echo "$(date +"%x %X") Reference Harddisk is active. Continue controlling." >> $LogDir
		fi
	else
		echo "$(date +"%x %X") Reference Harddisk is not configured. Continue without standby support." >> $LogDir
	fi
	if $Hdparm -C $Hdd | grep -q "$StandbyValue";
	then
		echo "$(date +"%x %X") Drive $Hdd is in Standby. Setting to $PwmLow." >> $LogDir
		printf "%s" "$(date +"%x %X")" >> $LogDir
		StandbyReturn="$(echo $PwmLow >> $PwmDev)" >> $LogDir
		if [ "$StandbyReturn" = "" ];
		then
			echo " Fan has been set to $PwmLow" >> $LogDir
		else
			echo " $StandbyReturn" >> $LogDir
		fi
	else
		HddTemp=$($Hddtemp -n -w -q $Hdd)
		if [ $HddTemp -lt $TempMin ];
		then
			printf "%s Temperature is to cold. Setting to $PwmLow" "$(date +"%x %X")" >> $LogDir
			echo "$(echo $PwmLow >> $PwmDev)" >> $LogDir
		else
			if [ $HddTemp -ge $TempMin ];
			then
				if [ $HddTemp -gt $TempMax ];
				then
					printf "%s Temperature is to high ($HddTemo). Setting to $PwmMax" "$(date +"%x %X")" >> $LogDir
					echo "$(echo $PwmMax >> $PwmDev)" >> $LogDir
				else
					PwmBand=$(echo "$PwmMax - $PwmMin" | bc)
					TempBand=$(echo "$TempMax - $TempMin" | bc)
					PwmCount=$(echo "$PwmBand / $TempBand" | bc)
					TempCommand=$(echo "$HddTemp - $TempMin" | bc)
					TempDist=$(echo "$TempCommand * $PwmCount" | bc)
					PwmCommand=$(echo "$TempDist + $PwmMin" | bc)
					PwmCurrent=$(cat < $PwmDev)
					if [ $PwmCurrent -eq $PwmLow ];
					then
						if [ $PwmCommand -ge $PwmStart ];
						then
							printf "%s Fan was in standby. Setting to $PwmCommand:" "$(date +"%x %X")" >> $LogDir
							PwmResult=$(echo $PwmCommand >> $PwmDev)
							if [ "$PwmResult" = "" ];
							then
								echo "OK." >> $LogDir
							else
								echo "$PwmResult" >> $LogDir
							fi
						else
							printf "%s Fan was in standby. Wakeup with $PwmStart:" "$(date +"%x %X")" >> $LogDir
							PwmResult=$(echo $PwmStart >> $PwmDev)
							if [ "$PwmResult" = "" ];
							then
								echo "OK." >> $LogDir
							else
								echo "$PwmResult" >> $LogDir
							fi
							echo "$(date +"%x %X") Waiting 5 seconds." >> $LogDir
							$(sleep 4s)
							printf "%s Fan is now running. Setting to $PwmCommand:" "$(date +"%x %X")" >> $LogDir
							PwmResult=$(echo $PwmCommand >> $PwmDev)
							if [ "$PwmResult" = "" ];
							then
								echo "OK." >> $LogDir
							else
								echo "$PwmResult" >> $LogDir
							fi
						fi
					else
						printf "%s Temperature is $HddTemp so setting PWM to " "$(date +"%x %X")" >> $LogDir
						printf "$PwmCommand" >> $LogDir
						printf ":" >> $LogDir
						PwmResult=$(echo $PwmCommand >> $PwmDev)
						if [ "$PwmResult" = "" ];
						then
							echo "OK." >> $LogDir
						else
							echo "$PwmResult" >> $LogDir
						fi
					fi
				fi
			fi
		fi
	fi
}


if [ "$2" = "" ];
then
	LogDir="/dev/null"
else
	LogDir=$2
fi
case $1 in
	--config|-c)
		while true; do
			while true; do
				printf 'Enter the HDD to control Fan (/dev/sdx) or pess l to list:'
				read Hdd
				case $Hdd in
					L|l)
						HddList=$(ls --format=single-column /dev/disk/by-id/* | grep -v part)
						echo -e "$HddList"
					;;
					*)
						HddPath=$(echo "$Hdd" | cut -c -7)
						if [ -n "$(echo $Hdd | grep \"/dev/sd\")" ];
						then
							if [ -e $Hdd ];
							then	
								if [ "$ConfigCurrent" = "empty" ];
								then
									ConfigCurrent="[Device]\nHarddisk=$Hdd"
								else
									ConfigCurrent="$ConfigCurrent\n[Device]\nHarddisk=$Hdd"
								fi
								break
							else
								echo "You must select a HDD device not a volume."
							fi
						elif [ -n "$(echo $Hdd | grep \"/dev/hd\")" ];
						then
							if [ -e $Hdd ];
							then
								if [ "$ConfigCurrent" = "empty" ];
								then
									ConfigCurrent="[Device]\nHarddisk=$Hdd"
								else
									ConfigCurrent="$ConfigCurrent\n[Device]\nHarddisk=$Hdd"
								fi
								break
							else
								echo "You must select a HDD device not a volume."
							fi
						elif [ -n "$(echo $Hdd | grep \"/dev/disk/\")" ];
						then
							if [ -e $Hdd ];
							then
								if [ "$ConfigCurrent" = "empty" ];
								then
									ConfigCurrent="[Device]\nHarddisk=$Hdd"
								else
									ConfigCurrent="$ConfigCurrent\n[Device]\nHarddisk=$Hdd"
								fi
                                                        	break
							else
								echo "You must select a HDD device not a volume."
							fi
						else
							echo "You must enter a HDD device from /dev"
						fi
					;;
				esac
			done

			while true; do
				printf "Do you want to declare a reference HDD for standby? Ohterwise the hdd won\'t go to sleep. (y/n):"
				read HddRefOpt
				case $HddRefOpt in
					Y|y)
						ConfigCurrent="$ConfigCurrent\nHarddisk Reference Option=y"
						printf "Enter the HDD to handle standby (/dev/sdx) or press l to list:"
						read HddRef
						case $HddRef in
							L|l)
								HddList=$(ls --format=single-column /dev/sd?)
								echo -e "$HddList"
							;;
							*)
								HddRefPath=$(echo "$HddRef" | cut -c -7)
								if [ "$HddRefPath" =  "/dev/sd" ];
								then
									if [ -e $HddRef ];
									then
										ConfigCurrent="$ConfigCurrent\nHarddisk Reference=$HddRef"
										break
									else
										echo "You must select a HDD device not a volume."
									fi
								else
									if [ "$HdRefdPath" = "/dev/hd" ];
									then
										if [ -e $HddRef ];
										then
											ConfigCurrent="$ConfigCurrent\nHarddisk Reference=$HddRef"
											break
										else
											echo "You must select a HDD device not a volume."
										fi
									else
										echo "You must enter a HDD device from /dev"
									fi
								fi
							;;
						esac
					;;
					N|n)
						ConfigCurrent="$ConfigCurrent\nHarddisk Reference Option=n"
						break
					;;
					*)
						echo "Please Enter y or n."
					;;
				esac
			done
			while true;do
				printf "Enter the value when the hard disk is in standby mode, or press EXC to continue with default value (standby):"
				while read -r -s -n1 choice; do
					case "$choice" in
						$'\e')
            						StandbyValue="standby"
							break
						;;
						"")
							break
						;;
						*)
							StandbyValue+=$choice
						;;
					esac
				done
				if [ $StandbyValue -ne "" ] 2>/dev/null;
				then
					ConfigCurrent="$ConfigCurrent\nStandby Value=$StandbyValue"
					break
				else
					echo "Your input could not be processed. Please try again."
				fi
			done
			while true; do
				printf "Enter the minimum temperature:"
				read TempMin
				if [ $TempMin -eq $TempMin ] 2>/dev/null;
				then
					ConfigCurrent="$ConfigCurrent\nMinimum Temperature=$TempMin"
					break	
				else
					echo "You must enter a number";
				fi
			done

			while true; do
				printf "Enter the maximum temperature (grather than $TempMinÂ°C):"
				read TempMax
				if [ $TempMax -eq $TempMax ] 2>/dev/null;
				then
					if [ $TempMax -gt $TempMin ];
					then
						ConfigCurrent="$ConfigCurrent\nMaximum Temperature=$TempMax"
						break
					else
						echo "The maximum temperature must be grather than $TempMinÂ°C"
					fi
				else
					echo "You must enter a number";
				fi
			done

			while true; do
				printf "Enter PWM device or press l to list:"
				read PwmDev
				case $PwmDev in
					L|l)
						PwmList=$(ls --format=single-column /sys/class/hwmon/*/pwm?)
						echo -e "$PwmList"
					;;
					*)
						if [ -e $PwmDev ];
						then
							printf "Checking if pwm control is enabled: "
							PwmDevEnabled=$(cat < $PwmDev'_enable')
							if [ $PwmDevEnabled -eq 1 ];
							then
								echo "OK."
								ConfigCurrent="$ConfigCurrent\nPWM Device=$PwmDev"
								break
							else
								echo "Error. Control is in state $PwmDevEnabled."
								printf "Trying to activate pwm control: "
								$(echo 1 > $PwmDev'_enable')
								PwmDevEnabled=$(cat < $PwmDev'_enable')
								if [ $PwmDevEnabled -eq 1 ];
								then
									echo "OK."
									ConfigCurrent="$ConfigCurrent\nPWM Device=$PwmDev"
									break
								else
									echo "Error. Pwm control couldn't be activated."
								fi
							fi
						else
							echo "The PWM device $PwmDev do\'nt exist";
						fi
					;;
				esac
			done
			while true; do
				printf 'Enter the PWM value for lowest RPM (0-255) or press t to test:'
				read PwmMin
				case $PwmMin in
					T|t)
						printf "Warning this will stop the fan for 5 seconds. Press any key to continue or CTRL + C to abort:"
						read Continue
						PwmFans=( $(ls --format=single-column /sys/class/hwmon/*/fan?_input) )
						$(echo 0 > $PwmDev)
						echo "Trying to stop fan now..."
						$(sleep 5)
						PwmFansCounter=0
						while [ $PwmFansCounter -lt ${#PwmFans[@]} ]; do
							PwmFansSpeedStop[$PwmFansCounter]=$(cat < ${PwmFans[$PwmFansCounter]})
							#echo ${PwmFansSpeedStop[$PwmFansCounter]}
							PwmFansCounter=$(expr $PwmFansCounter + 1)
						done
						echo "Trying to set full speed for fan now..."
						$(echo 255 > $PwmDev)
						$(sleep 5)
						PwmFansCounter=0
						PwmFan="empty"
						while [ $PwmFansCounter -lt ${#PwmFans[@]} ]; do
							PwmFansSpeedFull[$PwmFansCounter]=$(cat < ${PwmFans[$PwmFansCounter]})
							PwmFansCounter=$(expr $PwmFansCounter + 1)
						done
						$(sleep 5)
						PwmFansCounter=0
						while [ $PwmFansCounter -lt ${#PwmFans[@]} ]; do
							if [ ${PwmFansSpeedStop[$PwmFansCounter]} -eq 0 ];
							then
								if [ ${PwmFansSpeedFull[$PwmFansCounter]} -gt 0 ];
								then
									echo "It seems that the folowing Fan is controlled by $PwmDev:"
									echo ${PwmFans[$PwmFansCounter]}
									PwmFan=${PwmFans[$PwmFansCounter]}
									break
								fi
							fi
							PwmFansCounter=$(expr $PwmFansCounter + 1)
						done
						if [ $PwmFan = "empty" ];
						then
							echo "This PWM device don't control a fan."
						else
							echo "Now trying to get lowest fan speed..."
							SetSpeed=250
							while true; do
								$(echo $SetSpeed > $PwmDev)
								printf "Set PWM to	$SetSpeed	...	"
								$(sleep 5)
								CurrentFanSpeed=$(cat < $PwmFan)
								echo "$CurrentFanSpeed"
								if [ $CurrentFanSpeed -eq 0 ];
								then
									SetSpeed=$(expr $SetSpeed + 10)
									echo "The lowest fan speed is:$SetSpeed"
									PwmMin=$SetSpeed
									$(echo 255 > $PwmDev)
									break
								fi
								if [ $SetSpeed -ge 0 ];
								then
									SetSpeed=$(expr $SetSpeed - 10)
								else
									echo "Could not get lowest fan speed."
									break
								fi
							done
							if [ "$PwmMin" != "" ];
							then
								ConfigCurrent="$ConfigCurrent\nMinimum PWM=$PwmMin"
								break
							fi
						fi
					;;
					*)
						if [ $PwmMin -lt 0 ];
						then
							echo "The value must be grather or equal than 0"
						else
							if [ $PwmMin -gt 255 ];
							then
								echo "The value must be lower than 256"
							else
								ConfigCurrent="$ConfigCurrent\nMinimum PWM=$PwmMin"
								break
							fi
						fi
					;;
				esac
			done
			while true; do
				printf "Enter the PWM value to start fan ($PwmMin-255) or press t to test:"
				read PwmStart
				case $PwmStart in
					T|t)
						printf "Warning this will stop your fan until the PWM value is high enuge to start. This can cause damage on your hardware. Press any key to continue or press CTRL + C to abort:"
						read Continue
						PwmFans=( $(ls --format=single-column /sys/class/hwmon/*/fan?_input) )
						$(echo 0 > $PwmDev)
						echo "Trying to stop fan now..."
						$(sleep 5)
						PwmFansCounter=0
						while [ $PwmFansCounter -lt ${#PwmFans[@]} ]; do
							PwmFansSpeedStop[$PwmFansCounter]=$(cat < ${PwmFans[$PwmFansCounter]})
							PwmFansCounter=$(expr $PwmFansCounter + 1)
						done
						echo "Trying to set full speed for fan now..."
						$(echo 255 > $PwmDev)
						$(sleep 5)
						PwmFansCounter=0
						PwmFan="empty"
						while [ $PwmFansCounter -lt ${#PwmFans[@]} ]; do
							PwmFansSpeedFull[$PwmFansCounter]=$(cat < ${PwmFans[$PwmFansCounter]})
							PwmFansCounter=$(expr $PwmFansCounter + 1)
						done
						$(sleep 5)
						PwmFansCounter=0
						while [ $PwmFansCounter -lt ${#PwmFans[@]} ]; do
							if [ ${PwmFansSpeedStop[$PwmFansCounter]} -eq 0 ];
							then
								if [ ${PwmFansSpeedFull[$PwmFansCounter]} -gt 0 ];
								then
									echo "It seems that the folowing Fan is controlled by $PwmDev:"
									echo ${PwmFans[$PwmFansCounter]}
									PwmFan=${PwmFans[$PwmFansCounter]}
									break
								fi
							fi
							PwmFansCounter=$(expr $PwmFansCounter + 1)
						done
						if [ $PwmFan = "empty" ];
						then
							echo "This PWM device don't control a fan."
						else
							echo "Stopping fan again..."
							$(echo 0 > $PwmDev)
							$(sleep 5)
							echo "Now trying to get start fan speed..."
							SetSpeed=$PwmMin
							while true; do
								$(echo $SetSpeed > $PwmDev)
								printf "Set PWM to	  $SetSpeed	   ...	 "
								$(sleep 5)
								CurrentFanSpeed=$(cat < $PwmFan)
								echo "$CurrentFanSpeed"
								if [ $CurrentFanSpeed -gt 0 ];
								then
									if [ $SetSpeed -gt $PwmMin ];
									then
										SetSpeed=$(expr $SetSpeed - 5)
									fi
									echo "The start fan speed is:$SetSpeed"
									PwmStart=$SetSpeed
									$(echo 255 > $PwmDev)
									break
								fi
								if [ $SetSpeed -lt 256 ];
								then
									SetSpeed=$(expr $SetSpeed + 5)
								else
									echo "Could not get start fan speed."
									break
								fi
							done
							if [ "$PwmStart" != "" ];
							then
								ConfigCurrent="$ConfigCurrent\nFan Start PWM=$PwmStart"
								break
							fi
						fi
					;;
					*)
						if [ $PwmStart -gt $PwmMin ];
						then
							echo "The value must be grather or equal than $PwmMin"
						else
							if [ $PwmStart -gt 255 ];
							then
								echo "The value must be lower than 256"
							else
								ConfigCurrent="$ConfigCurrent\nFan Start PWM=$PwmStart"
								break
							fi
						fi
					;;
				esac
			done

			while   true; do
				printf "Enter the PWM value for highest RPM ($PwmMin-255):"
				read PwmMax
				if [ $PwmMax -le $PwmMin ];
				then
					echo "The value must be grather than $PwmMin"
				else
					if [ $PwmMax -gt 255 ];
					then
						echo "The value must be lower than 256"
					else
						ConfigCurrent="$ConfigCurrent\nMaximum PWM=$PwmMax"
						break
					fi
				fi
			done
			while   true; do
				printf "Enter the PWM value when temperature is under $TempMin (0-$PwmMin):"
				read PwmLow
				if [ $PwmLow -lt 0 ];
				then
					echo "The value must be grather or equal than 0"
				else
					if [ $PwmLow -ge $PwmMin ];
					then
						echo "The value must be lower than $PwmMin"
					else
						ConfigCurrent="$ConfigCurrent\nCold PWM=$PwmLow"
						break
					fi
				fi
			done
			Finish="no"
			while true; do
				printf 'Do you want to add another device? (y|n)'
				read LastDevice
				case $LastDevice in
					Y|y)
					   break 
					;;
					N|n)
						Finish="yes"
						break
					;;
				esac
			done
			if [ "$Finish" = "yes" ];
			then
				echo -e "$ConfigCurrent" > $Config
				echo -e "$ConfigCurrent" > $ConfigRun
				break
			fi
		done
	;;
	--run|-r)
		if [ -e $Hdparm ];
		then
			if [ -e $Hddtemp ];
			then
				if [ -e $Bc ];
				then
					echo "$(date +"%x %X") Requirements ok." >> $LogDir
				else
					echo "$(date +"%x %X") $Bc was not found. Exit now." >> $LogDir
					exit 1
				fi
			else
				echo "$(date +"%x %X") $Hddtemp was not found. Exit now." >> $LogDir
				exit 1
			fi
			else
				echo "$(date +"%x %X") $Hdparm was not found. Exit now." >> $LogDir
				exit 1
			fi
			if [ -e $ConfigRun ];
			then
				echo "$(date +"%x %X") Config exists in /run. Run now." >> $LogDir
			else
				if [ -e $Config ];
				then
					echo "$(date +"%x %X") Config exists. Copy now to /run" >> $LogDir
					printf "%s Copy...:" "$(date +"%x %X")" >> $LogDir
					echo "$(cp $Config $ConfigRun)" >> $LogDir
					echo "$(date +"%x %X") Run now." >> $LogDir
				else
					echo "$(date +"%x %X") Config must be configurated fist with \"hdd-fan-control --config\"" >> $LogDir
					exit 2
				fi
			fi
			while read Line; do
				NewDevice=true
				if [ "$Line" != "[Device]" ];
				then
					NewDevice=false
					CaseNameInt=$(echo "$Line" "=" | awk '{print index($Line,"=")}')
					CaseNameInt=$(expr $CaseNameInt - 1)
					case $(echo $Line | cut -c -$CaseNameInt) in
						"Harddisk")
						HddInt=$(echo "$Line" "=" | awk '{print index($Line,"=")}')
						HddInt=$(expr $HddInt + 1)
						Hdd=$(echo $Line | cut -c $HddInt-)
						echo "$(date +"%x %X") HDD to control: $Hdd" >> $LogDir
					;;
					"Harddisk Reference Option")
						HddRefOptInt=$(echo "$Line" "=" | awk '{print index($Line,"=")}')
						HddRefOptInt=$(expr $HddRefOptInt + 1)
						HddRefOpt=$(echo $Line | cut -c $HddRefOptInt-)
						echo "$(date +"%x %X") Enable standby monitoring: $HddRefOpt" >> $LogDir
					;;
					"Harddisk Reference")
						HddRefInt=$(echo "$Line" "=" | awk '{print index($Line,"=")}')
						HddRefInt=$(expr $HddRefInt + 1)
						HddRef=$(echo $Line | cut -c $HddRefInt-)
						echo "$(date +"%x %X") Reference HDD: $HddRef" >> $LogDir
					;;
					"Standby Value")
						StandbyValueInt=$(echo "$Line" "=" | awk '{print index($Line,"=")}')
						StandbyValueInt=$(expr $StandbyValueInt + 1)
						StandbyValue=$(echo $Line | cut -c $StandbyValueInt-)
						echo "$(date +"%x %X") Standby Value: $StandbyValue" >> $LogDir
					;;
					"Minimum Temperature")
						TempMinInt=$(echo "$Line" "=" | awk '{print index($Line,"=")}')
						TempMinInt=$(expr $TempMinInt + 1)
						TempMin=$(echo $Line | cut -c $TempMinInt-)
						echo "$(date +"%x %X") Minimum Temperature: $TempMin" >> $LogDir
					;;
					"Maximum Temperature")
						TempMaxInt=$(echo "$Line" "=" | awk '{print index($Line,"=")}')
						TempMaxInt=$(expr $TempMaxInt + 1)
						TempMax=$(echo $Line | cut -c $TempMaxInt-)
						echo "$(date +"%x %X") Maximaum Temperature: $TempMax" >> $LogDir
					;;	
					"PWM Device")
						PwmDevInt=$(echo "$Line" "=" | awk '{print index($Line,"=")}')
						PwmDevInt=$(expr $PwmDevInt + 1)
						PwmDev=$(echo $Line | cut -c $PwmDevInt-)
						echo "$(date +"%x %X") Device to control: $PwmDev" >> $LogDir
					;;
					"Minimum PWM")
						PwmMinInt=$(echo "$Line" "=" | awk '{print index($Line,"=")}')
						PwmMinInt=$(expr $PwmMinInt + 1)
						PwmMin=$(echo $Line | cut -c $PwmMinInt-)
						echo "$(date +"%x %X") Minimum PWM Signal: $PwmMin" >> $LogDir
					;;
					"Fan Start PWM")
						PwmStartInt=$(echo "$Line" "=" | awk '{print index($Line,"=")}')
						PwmStartInt=$(expr $PwmStartInt + 1)
						PwmStart=$(echo $Line | cut -c $PwmStartInt-)
						echo "$(date +"%x %X") PWM Signal to start fan: $PwmStart" >> $LogDir
					;;
					"Maximum PWM")
						PwmMaxInt=$(echo "$Line" "=" | awk '{print index($Line,"=")}')
						PwmMaxInt=$(expr $PwmMaxInt + 1)
						PwmMax=$(echo $Line | cut -c $PwmMaxInt-)
						echo "$(date +"%x %X") Maximum PWM Signal: $PwmMax" >> $LogDir
					;;
					"Cold PWM")
						PwmLowInt=$(echo "$Line" "=" | awk '{print index($Line,"=")}')
						PwmLowInt=$(expr $PwmLowInt + 1)
						PwmLow=$(echo $Line | cut -c $PwmLowInt-)
						echo "$(date +"%x %X") PWM Signal if Temperature is to low: $PwmLow" >> $LogDir
					;;
					*)
						echo "$(date +"%x %X") Illegal Line:$Line" >> $LogDir
					;;
				esac
				if [ "$Hdd" != "" ];
				then
					if [ "$TempMin" != "" ];
					then
						if [ "$TempMax" != "" ];
						then
							if [ "$PwmDev" != "" ];
							then
								if [ "$PwmMin" != "" ];
								then
									if [ "$PwmStart" != "" ];
									then
										if [ "$PwmMax" != "" ];
										then
											if [ "$PwmLow" != "" ];
											then
												if [ "$HddRefOpt" = "y" ];
												then
													if [ "$HddRef" != "" ];
													then
														if [ "$StandbyValue" != "" ];
														then
															control
														fi
													fi
												elif [ "$HddRefOpt" = "n" ];
												then
													control
												fi
											fi
										fi
									fi
								fi
							fi
						fi
					fi
				fi
			else
				NewDevice=true
			fi
		done < $ConfigRun
	;;
	*)
		echo "hdd-fan-control version $version"
		echo "Usage: hdd-fan-control.sh [command] [logfile]"
		echo "--run -r: Runs the program with the config whitch is saved in /etc/hdd-fan-control/hdd-fan-control.config"
		echo "--config -c: Create a new configuration."
		echo "--help -h: Display this help."
	;;
esac
