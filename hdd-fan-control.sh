#!/bin/bash
Config=/etc/hdd-fan-control/hdd-fan-control.config
ConfigRun=/run/hdd-fan-control.config
ConfigCurrent="empty"
LogDir="empty"


control()
{
        echo "`date +"%x %X"` Config imported" >> $LogDir
        HddState=`/sbin/hdparm -C $Hdd`
        if [ "`echo $HddState | cut -c 27-`" = "standby" ];
        then
                        echo "`date +"%x %X"` Drive $Hdd is in Standby. Setting to $PwmLow." >> $LogDir
                        printf "`date +"%x %X"`" >> $LogDir
                        echo "`echo $PwmLow >> $PwmDev`" >> $LogDir
        else
                        HddTemp=`/usr/sbin/hddtemp -n -q $Hdd`
                        if [ $HddTemp -lt $TempMin ];
                        then
                                        printf "`date +"%x %X"` Temperature is to cold. Setting to $PwmLow" >> $LogDir
                                        echo "`echo $PwmLow >> $PwmDev`" >> $LogDir
                        fi
                        if [ $HddTemp -ge $TempMin ];
                        then
                                        if [ $HddTemp -gt $TempMax ];
                                        then
                                                        printf "`date +"%x %X"` Temperature is to high. Setting to $PwmMax" >> $LogDir
                                                        echo "`echo $PwmMax >> $PwmDev`" >> $LogDir
                                        else
                                                        PwmBand=`echo "$PwmMax - $PwmMin" | bc`
                                                        TempBand=`echo "$TempMax - $TempMin" | bc`
                                                        PwmCount=`echo "$PwmBand / $TempBand" | bc`
                                                        TempCommand=`echo "$HddTemp - $TempMin" | bc`
                                                        TempDist=`echo "$TempCommand * $PwmCount" | bc`
                                                        PwmCommand=`echo "$TempDist + $PwmMin" | bc`
                                                        PwmCurrent=`cat < $PwmDev`
                                                        if [ $PwmCurrent -eq $PwmLow ];
                                                        then
                                                                        if [ $PwmCommand -ge $PwmStart ];
                                                                        then
                                                                                   printf "`date +"%x %X"` Fan was in standby. Setting to $PwmCommand:" >> $LogDir
                                                                                   PwmResult=`echo $PwmCommand >> $PwmDev`
                                                                                   if [ "$PwmResult" = "" ];
                                                                                   then
                                                                                   echo "OK." >> $LogDir
                                                                                   else
                                                                                   echo "$PwmResult" >> $LogDir
                                                                                   fi
                                                                        else
                                                                                   printf "`date +"%x %X"` Fan was in standby. Wakeup with $PwmStart:" >> $LogDir
                                                                                   PwmResult=`echo $PwmStart >> $PwmDev`
                                                                                   if [ "$PwmResult" = "" ];
                                                                                   then
                                                                                   echo "OK." >> $LogDir
                                                                                   else
                                                                                   echo "$PwmResult" >> $LogDir
                                                                                   fi
                                                                                   echo "`date +"%x %X"` Waiting 5 seconds."
                                                                                   `sleep 4s`
                                                                                   printf "`date +"%x %X"` Fan is now running. Setting to $PwmCommand:" >> $LogDir
                                                                                   PwmResult=`echo $PwmCommand >> $PwmDev`
                                                                                   if [ "$PwmResult" = "" ];
                                                                                   then
                                                                                   echo "OK." >> $LogDir
                                                                                   else
                                                                                   echo "$PwmResult" >> $LogDir
                                                                                   fi
                                                                        fi
                                                        else
                                                                        printf "`date +"%x %X"` Setting PWM to $PwmCommand:" >> $LogDir
                                                                        PwmResult=`echo $PwmCommand >> $PwmDev`
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
                                printf 'Enter the HDD to control Fan (/dev/sdx):'
                                read Hdd
				HddPath=`echo "$Hdd" | cut -c -7`
                                if [ "$HddPath" =  "/dev/sd" ];
                                then
					HddVolume=`echo "$Hdd" | cut -c 9-`
                                        if [ "$HddVolume" = "" ];
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
					if [ "$HddPath" = "/dev/hd" ];
					then
						HddVolume=`echo "$Hdd" | cut -c 9-`
						if [ "$HddVolume" = "" ];
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
                                printf "Enter the maximum temperature (grather than $TempMin°C):"
                                read TempMax
                                if [ $TempMax -eq $TempMax ] 2>/dev/null;
                                then
					if [ $TempMax -gt $TempMin ];
					then
						ConfigCurrent="$ConfigCurrent\nMaximum Temperature=$TempMax"
                                        	break
					else
						echo "The maximum temperature must be grather than $TempMin°C"
					fi
                                else
                                        echo "You must enter a number";
                                fi
                        done


                        while true; do
                                printf "Enter PWM device:"
                                read PwmDev
                                if [ -e $PwmDev ];
                                then
					ConfigCurrent="$ConfigCurrent\nPWM Device=$PwmDev"
                                        break
                                else
                                        echo "The PWM device $PwmDev do\'nt exist";
                                fi
                        done

			while true; do
				printf 'Enter the PWM value for lowest RPM (0-255):'
				read PwmMin
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
			done

                        while true; do
                                printf "Enter the PWM value to start fan ($PwmMin-255):"
                                read PwmStart
                                if [ $PwmStart -le $PwmMin ];
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
		if [ -e $ConfigRun ];
		then
			echo "`date +"%x %X"` Config exists in /run. Run now." >> $LogDir
		else
			if [ -e $Config ];
			then
				echo "`date +"%x %X"` Config exists. Copy now to /run" >> $LogDir
				printf "`date +"%x %X"` Copy...:" >> $LogDir
				echo "`cp $Config $ConfigRun`" >> $LogDir
				echo "`date +"%x %X"` Run now." >> $LogDir
			else
				echo "`date +"%x %X"` Config must be configurated fist with \"hdd-fan-control --config\"" >> $LogDir
				exit 2
			fi
		fi
		while read Line; do
			NewDevice=true
			if [ "$Line" != "[Device]" ];
			then
				NewDevice=false
				CaseNameInt=`echo "$Line" "=" | awk '{print index($Line,"=")}'`
				CaseNameInt=`expr $CaseNameInt - 1`
				case `echo $Line | cut -c -$CaseNameInt` in
					"Harddisk")
						HddInt=`echo "$Line" "=" | awk '{print index($Line,"=")}'`
						HddInt=`expr $HddInt + 1`
						Hdd=`echo $Line | cut -c $HddInt-`
					;;
					"Minimum Temperature")
                                                TempMinInt=`echo "$Line" "=" | awk '{print index($Line,"=")}'`
                                                TempMinInt=`expr $TempMinInt + 1`
                                                TempMin=`echo $Line | cut -c $TempMinInt-`
                                                LineCount=`expr $LineCount + 1`
					;;
					"Maximum Temperature")
                                                TempMaxInt=`echo "$Line" "=" | awk '{print index($Line,"=")}'`
                                                TempMaxInt=`expr $TempMaxInt + 1`
                                                TempMax=`echo $Line | cut -c $TempMaxInt-`
					;;	
					"PWM Device")
                                                PwmDevInt=`echo "$Line" "=" | awk '{print index($Line,"=")}'`
                                                PwmDevInt=`expr $PwmDevInt + 1`
                                                PwmDev=`echo $Line | cut -c $PwmDevInt-`
					;;
					"Minimum PWM")
                                                PwmMinInt=`echo "$Line" "=" | awk '{print index($Line,"=")}'`
                                                PwmMinInt=`expr $PwmMinInt + 1`
                                                PwmMin=`echo $Line | cut -c $PwmMinInt-`
					;;
					"Fan Start PWM")
                                                PwmStartInt=`echo "$Line" "=" | awk '{print index($Line,"=")}'`
                                                PwmStartInt=`expr $PwmStartInt + 1`
                                                PwmStart=`echo $Line | cut -c $PwmStartInt-`
					;;
					"Maximum PWM")
                                                PwmMaxInt=`echo "$Line" "=" | awk '{print index($Line,"=")}'`
                                                PwmMaxInt=`expr $PwmMaxInt + 1`
                                                PwmMax=`echo $Line | cut -c $PwmMaxInt-`
					;;
					"Cold PWM")
                                                PwmLowInt=`echo "$Line" "=" | awk '{print index($Line,"=")}'`
                                                PwmLowInt=`expr $PwmLowInt + 1`
                                                PwmLow=`echo $Line | cut -c $PwmLowInt-`
					;;
					*)
						echo "`date +"%x %X"` Illegal Line:$Line" >> $LogDir
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
												control
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
esac