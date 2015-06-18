hdd-fan-control
=================

Software to control Fans depending on the temperature of a hdd.


### Parameters:
$ hdd-fan-control.sh [command] [logfile]

    --run -r: Runs the program with the config whitch is saved in /etc/hdd-fan-control/hdd-fan-control.config
    --config -c: Create a new configuration.
    --help -h: Display this help.

### Requirements:
This software requires the folowing packages:
* hdparm
* hddtemp

### Run Program
To run the program you need to start it with:

    $ /etc/hdd-fan-control/hdd-fan-control.sh -r

If you wish that the program logs the controlling you must enter a logfile like this:

    $ /etc/hdd-fan-control/hdd-fan-control.sh -r /var/log/hdd-fan-control.sh

If no logfile is given the program throw the logs out at /dev/null.

### Configuration:
1. Enter the HDD to control Fan (/dev/sdx) or pess l to list:

    This HDD will be used to get the temperature of the drive. IF you type l all possible drives will be listed. The drive must be look like this:
    
    * /dev/sdx
    * /dev/hdx

2. Do you want to declare a reference HDD for standby? Ohterwise the hdd won't go to sleep. (y/n):

    If you want to be able to use the standby function of your drive you must type in a reference HDD. If this HDD goes to sleep, the control HDD will do this as well.

3. Enter the HDD to handle standby (/dev/sdx) or press l to list:

    Here you must enter the reference HDD. The format must be the same as the Control HDD. Here you are also able to list the possible HDDs. If you list them you will fall back to point 2.

4. Enter the minimum temperature:

    This is the lowest temperature to control the fan. Under this temperature the fan will be set to the lowest value which is set in point 7.

5. Enter the maximum temperature (grather than xy°C):

    This is the maximum allowed temperature. Above this temperature the fan will set to the highest value which is set in point 9.

6. Enter PWM device or press l to list:

    Here you must enter the path to the pwm device which will control the fan. You can press l to get all possible devices. After entering the device it will be checked.

7. Enter the PWM value for lowest RPM (0-255) or press t to test:

    This is the lowest PWM value for the fan. This value must be between 0 and 255. You can use t to test the fan to get the lowest possible value. It will be set automaticly.

8. Enter the PWM value to start fan (x-255) or press t to test:

    This is the value which is needed to start the fan. It must be between the PWM for the lowest RPM which was set in point 7 and 255. You can use t to test the fan to get the lowest possible value. It will be set automaticly.

9. Enter the PWM value for highest RPM (x-255):

    This is the highest value for the fan. 255 means means full speed. It must be between the PWM for the lowest RPM which was set in point 7 and 255.

10. Enter the PWM value when temperature is under xy°C (0-x):

    This is the PWM value which is used when the temperature is under the value which is set in point 4 or if the HDD is in standby. It must be between 0 and the PWM for the lowest RPM which was set in point 7.

11. Do you want to add another device? (y|n):

    You can add another Fan which will be controlled or end the setup by entering n.
