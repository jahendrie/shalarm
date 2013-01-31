#!/bin/bash
################################################################################
#   shalarm.sh      |   version 1.1     |   FreeBSD License   |   2013.01.30
#   James Hendrie   |   hendrie dot james at gmail dot com
################################################################################

##  Set these to whatever works for you; alternately, don't touch them and just
##  make sure that 'findMediaPlayer' and 'findSoundFile' are both set to 1
soundFile="ring.wav"                    #   Sound file used as your alarm tone
mediaPlayer="play"                      #   Default media player to play sound
defaultPrefix="/usr"                    #   Default prefix
debugMode=0                             #   If 1, print a few variables and exit


##  Variables used later in the script
findMediaPlayer=1               #   If 1, search for media players to use
findSoundFile=1                 #   If 1, search for the sound file
ringTheAlarm=0                  #   If 1, ring the alarm (it's set to 1 later)
testAlarm=0                     #   If 1, set the alarm to current time +5 secs
checkInterval=1                 #   Interval to check alarm, in seconds
useConfig=1                     #   Whether or not to use a config file
createUserConfig=1              #   Whether or not to copy the config file to
                                #   ~/.config/shalarm/shalarm.cfg if that file
                                #   doesn't already exist
##  Just for funsies
printAlarmMessage=1             #   Print a message when the alarm is ringing
alarmMessage="WAKE UP!"         #   The message to print


##  This function goes through an array of commonly installed media players, and
##  if it finds one, sets that as the media player to use.  If it can't find
##  any, then it errors out.
function find_media_player
{
    mediaPlayer=0

    ##  The size of the array we're checking
    arraySize=3

    ##  An array of commonly installed media players
    commonMediaPlayers=('mplayer' 'play' 'aplay')

    ##  Prefixes of directories in which we'll check
    prefix1="/usr/bin"
    prefix2="/usr/local/bin"

    ##  Check the directories for the possibly installed programs
    for ((i = 0; i < $arraySize; ++i)); do
        p1="$prefix1/${commonMediaPlayers[${i}]}"
        p2="$prefix2/${commonMediaPlayers[${i}]}"

        ##  If we find one, set the system call and break out of the loop
        if [ -e $p1 ]; then
            mediaPlayer=$p1
            break
        elif [ -e $p2 ]; then
            mediaPlayer=$p2
            break
        fi
    done

    ##  If we don't find one, tell the user and exit the program
    if [ $mediaPlayer == 0 ]; then
        echo "Error:  Can't find a media player to use" 1>&2
        echo "Try installing 'play', 'aplay' or 'mplayer'" 1>&2
        exit
    fi
}


##  This function checks two directories for the file 'ring.wav':  The current
##  directory, and /usr/local/share/shalarm.  If it finds it in either, it sets
##  the soundfile to that.  Otherwise, it errors out.
function find_sound_file
{
    soundFile=0

    ##  Look in the default install directory for ring.wav.  Failing that,
    ##  check the present working directory using 'ls'
    if [ ! -e "$defaultPrefix/share/shalarm/ring.wav" ]; then
        for f in $( ls ); do
            if [ $f == "ring.wav" ]; then
                soundFile=$(readlink -f $f)
            fi
        done
    else
        soundFile="$defaultPrefix/share/shalarm/ring.wav"
    fi

    ##  If we can't find a sound file, tell the user and exit the program
    if [ $soundFile == 0 ]; then
        echo "Error:  Cannot find file 'ring.wav'" 1>&2
        exit
    fi
}


##  This function tells the program what to do if it catches a SIGINT
function control_c
{
    exit $?
}


##  This function gets the current time using 'date', and cuts it into the
##  proper variables
function get_current_time
{
    ##  Get the current time
    currentTime=$(date +'%-H %-M %-S')

    ##  Cut it up and send it to its proper variables
    currentHour=$(echo $currentTime | cut -f1 -d' ')
    currentMinute=$(echo $currentTime | cut -f2 -d' ')
    currentSecond=$(echo $currentTime | cut -f3 -d' ')

}


##  Generic function to print an "I don't understand that time string" message
function print_time_error
{
    echo "Error:  Improper time format" 1>&2
    echo "Use 'shalarm --help' for more info" 1>&2
}


##  Get rid of all the crap in the time string (colons, periods, whatever) and
##  then check to make sure it wasn't just a bunch of characters or whatever
function parse_alarm_string
{

    ##  Echo the argument passed, pipe it to 'tr' a bunch of times and delete
    ##  the characters we don't want
    alarmString=$(echo $1 | tr -d ':' | tr -d '.' | tr -d '-' | tr -d '/')
    alarmString=$(echo $alarmString | tr -d '[:alpha:]')

    ##  We purposely remove all numeric digits from the time string and send it
    ##  to this 'check' variable.  Juuuust to be safe.
    alarmStringCheck=$(echo $alarmString | tr -d '[:digit:]' | wc -c)

    ##  If there was anything left over in the check variable, that means there
    ##  were superfluous characters that didn't get cleaned up
    if [ $alarmStringCheck -ne 1 ]; then
        print_time_error
        exit
    fi
}


##  We set the alarm time, and also check to make sure that the time string was
##  of the proper length.  After that, we double-check the other alarm time
##  variables to ensure that those, too, are of proper length
function set_alarm_time
{
    ##  Count the characters in the string that was passed.  Remember that wc -c
    ##  will result in one character more than there 'actually' are, and I'm too
    ##  lazy to just subtract one from charCount, so... always add one mentally
    charCount=$(echo $1 | wc -c)

    if [ $charCount == 3 ]; then                ##  Only hour
        alarmHour=$1
        alarmMinute="00"
        alarmSecond="00"
    elif [ $charCount == 5 ]; then              ##  Hour and minute
        alarmHour=$(echo $1 | cut -b1,2)
        alarmMinute=$(echo $1 | cut -b3,4)
        alarmSecond="00"
    elif [ $charCount == 7 ]; then              ##  Hour, minute and second
        alarmHour=$(echo $1 | cut -b1,2)
        alarmMinute=$(echo $1 | cut -b3,4)
        alarmSecond=$(echo $1 | cut -b5,6)
    else
        print_time_error
        exit
    fi

    ##  Check to make sure that the hour, minute and second values are all
    ##  within acceptable boundaries
    ### Alarm value
    if [ $alarmHour -gt 23 ]; then
        echo "Error:  Hour value too high ($alarmHour):  Maximum is 23" 1>&2
        exit
    elif [ $alarmHour -lt 0 ]; then
        echo "Error:  Hour value too low ($alarmHour):  Minimum is 00" 1>&2
    fi

    ### Minute value
    if [ $alarmMinute -gt 59 ]; then
        echo "Error:  Minute value too high ($alarmMinute):  Maximum is 59" 1>&2
        exit
    elif [ $alarmMinute -lt 0 ]; then
        echo "Error:  Minute value too low ($alarmMinute):  Minimum is 00" 1>&2
    fi

    ### Second value
    if [ $alarmSecond -gt 59 ]; then
        echo "Error:  Second value too high ($alarmSecond):  Maximum is 59" 1>&2
        exit
    elif [ $alarmSecond -lt 0 ]; then
        echo "Error:  Second value too low ($alarmSecond):  Minimum is 00" 1>&2
    fi


    ##  Make sure all of the time digits are of a proper length
    if [ $(echo $alarmHour | wc -c) -lt 3 ]; then
        alarmHour="0$alarmHour"
    fi

    if [ $(echo $alarmMinute | wc -c) -lt 3 ]; then
        alarmMinute="0$alarmMinute"
    fi

    if [ $(echo $alarmSecond | wc -c) -lt 3 ]; then
        alarmSecond="0$alarmSecond"
    fi

}


##  This function just sets the alarm to five seconds past whatever the current
##  system time (as taken from 'date') is
function set_test_alarm
{
    ##  Get the current time
    get_current_time
    
    ##  Set the alarm time to five seconds past whatever the current time is
    alarmHour=$currentHour
    alarmMinute=$currentMinute
    alarmSecond=$[ $currentSecond + 5 ]

    ##  See if the time went over
    if [ $alarmSecond -gt 59 ]; then
        let alarmSecond-=59
        let alarmMinute+=1
    fi
    if [ $alarmMinute -gt 59 ]; then
        let alarmMinute-=59
        let alarmHour+=1
    fi
    if [ $alarmHour == "24" ]; then
        alarmHour="00"
    fi


    ##  Make sure all of the time digits are of a proper length
    if [ $(echo $alarmHour | wc -c) -lt 3 ]; then
        alarmHour="0$alarmHour"
    fi

    if [ $(echo $alarmMinute | wc -c) -lt 3 ]; then
        alarmMinute="0$alarmMinute"
    fi

    if [ $(echo $alarmSecond | wc -c) -lt 3 ]; then
        alarmSecond="0$alarmSecond"
    fi

}


##  This function uses the system call to 'ring the alarm' -- in other words,
##  use the media player to play the sound file over and over
function ring_alarm
{
    ##  If we're printing a message, then... print it
    if [ $printAlarmMessage == 1 ]; then
        echo -e "$alarmMessage"
    fi

    ##  Issue the system call, sending all output to /dev/null to keep things
    ##  nice and clean
    $mediaPlayer "$soundFile" &> /dev/null
}


##  Every second, we check to see if the alarm time is equal to the current time
##  and if it is, we ring the alarm
function alarm_check
{
    ##  Fetch the current system time
    get_current_time

    ##  We're going to check the current second and current second + 1 against
    ##  the 'alarm second', just to be safe
    cs1=$currentSecond
    cs2=$[ $currentSecond + 1 ]

    ##  Make sure that cs1 and cs2 don't roll over past 59
    if [ $cs1 -gt 59 ]; then
        cs1=0
    fi

    if [ $cs2 -gt 59 ]; then
        cs2=0
    fi


    ##  Check the lengths, again
    if [ $(echo $alarmHour | wc -c) -lt 3 ]; then
        alarmHour="0$alarmHour"
    fi

    if [ $(echo $alarmMinute | wc -c) -lt 3 ]; then
        alarmMinute="0$alarmMinute"
    fi

    if [ $(echo $alarmSecond | wc -c) -lt 3 ]; then
        alarmSecond="0$alarmSecond"
    fi


    ##  Check the current alarm time lengths
    if [ $(echo $currentHour | wc -c) -lt 3 ]; then
        currentHour="0$currentHour"
    fi

    if [ $(echo $currentMinute | wc -c) -lt 3 ]; then
        currentMinute="0$currentMinute"
    fi

    if [ $(echo $currentSecond | wc -c) -lt 3 ]; then
        currentSecond="0$currentSecond"
    fi


    ##  Check the lengths of cs1 and cs2
    if [ $(echo $cs1 | wc -c) -lt 3 ]; then
        cs1="0$cs1"
    fi

    if [ $(echo $cs2 | wc -c) -lt 3 ]; then
        cs2="0$cs2"
    fi


    ##  If the current time is equal to the alarm time, set the alarm to ring
    if [ $alarmHour -eq $currentHour ]; then
        if [ $alarmMinute == $currentMinute ]; then
            if [ $alarmSecond == $cs1 ] || [ $alarmSecond == $cs2 ]; then
                ringTheAlarm=1
            fi
        fi
    fi

    ##  If the ringTheAlarm variable is set to 1, ring the alarm
    if [ $ringTheAlarm == 1 ]; then
        ring_alarm
    fi
}


##  Function to print the help information
function print_help
{
    echo -e "Usage:  shalarm TIME\n"
    echo -e "TIME is a 24-hr formatted time string."
    echo -e "For example, ten PM may be formatted as follows:\n"
    echo -e "   22:00:00"
    echo -e "   22:00"
    echo -e "   22"
    echo -e "   22.00.00"
    echo -e "   2200"
    echo -e "   220000\n"
    echo -e "As an aside, formatting it as '10:00' will get you ten AM, and"
    echo -e "'10 pm' won't work.\n"
    echo -e "Arguments:"
    echo -e "   -h or --help:      Print this help screen"
    echo -e "   -v or --version:   Print version and author info"
    echo -e "   -t or --test:      Test alarm set to 5 seconds in the future"
    echo -e "   -d or --debug:     Check out what's going wrong (or right)"
}

##  Function to print program and author information
function print_version
{
    echo -e "shalarm version 1.1, written by James Hendrie"
    echo -e "Licensed under the GPLv3 (GNU General Public License, version 3)"
}


##  This is just a function to print out some stuff that might be of interest
##  to people having trouble getting this to work.
function print_debug_info
{

    ##  Echo the values of a few key variables, formatted in a fancy way because
    ##  I am an asshole who does that kind of thing
    echo -e "\n\n###############################################"
    echo -e "                DEBUG INFO                     "
    echo -e "###############################################"
    echo -e "\nMedia player:                      $mediaPlayer"
    echo -e "Sound file:                        $soundFile"
    echo -e "PrintAlarmMessage:                 $printAlarmMessage"
    echo -e "Message:                           $alarmMessage"
    
    ##  Check for the existence of /etc/shalarm.cfg and report
    echo -n "/etc/shalarm.cfg:  "
    if [ -e "/etc/shalarm.cfg" ]; then
        echo -e "                DOES exist"
    else
        echo -e "                DOES NOT exist"
    fi

    ##  Check for the existence of ~/.config/shalarm/shalarm.cfg and report
    echo -n "~/.config/shalarm/shalarm.cfg:  "
    if [ -e "$(readlink -f ~/.config/shalarm/shalarm.cfg)" ]; then
        echo -e "   DOES exist"
    else
        echo -e "   DOES NOT exist"
    fi

    ##  Just to create some space at the bottom of the screen
    echo -e ""

}


##  This function will copy the config file from /etc to ~/.config/shalarm
function copy_user_config
{
    ##  Check to make sure the default config exists
    if [ ! -e "/etc/shalarm.cfg" ]; then
        echo "Error:  File does not exist (/etc/shalarm.cfg)" 1>&2
        echo "        Cannot copy it to ~/.config/shalarm/shalarm.cfg" 1>&2
    ##  And that it can be read from
    elif [ ! -r "/etc/shalarm.cfg" ]; then
        echo "Error:  Cannot read from /etc/shalarm.cfg" 1>&2
    ##  If it passes both tests, we begin the copying process
    else
        ##  Check to make sure we can write to the ~/.config directory
        if [ ! -w "$(readlink -f ~/.config)" ]; then
            echo "Error:  Cannot write to ~/.config/shalarm/shalarm.cfg" 1>&2
        else
            ##  Make the directory if need be
            if [ ! -e "$(readlink -f ~/.config/shalarm)" ]; then
                mkdir -p "$(readlink -f ~/.config/shalarm)"
            fi
            ##  Finally, copy the file to the user's ~/.config/shalarm directory
            cp "/etc/shalarm.cfg" "$(readlink -f ~/.config/shalarm/shalarm.cfg)"
        fi
    fi
}


##  This function sets the options according to the config file that's read
function set_options
{
    ##  We see if we're creating a user config, assuming it doesn't exist
    if [ $createUserConfig == 1 ]; then
        if [ ! -e "$(readlink -f ~/.config/shalarm/shalarm.cfg)" ]; then
            copy_user_config
        fi
    fi

    ##  Copy the values in the original variables, since we may revert back
    oldMediaPlayer=$mediaPlayer
    oldSoundFile=$soundFile
    oldAlarmMessage=$alarmMessage
    oldPrintAlarmMessage=$printAlarmMessage

    ##  If we can read from the user's config, then use that
    if [ -e "$(readlink -f ~/.config/shalarm/shalarm.cfg)" ]; then
        source "$(readlink -f ~/.config/shalarm/shalarm.cfg)"

    ##  Otherwise, use the default config
    elif [ -e "/etc/shalarm.cfg" ]; then
        source "/etc/shalarm.cfg"
    fi

    ##  And now, we check a bunch of values to make sure they aren't set to
    ##  'DEFAULT'.  If they are, we restore them to their previous values
    if [ "$mediaPlayer" == "DEFAULT" ]; then
        mediaPlayer=$oldMediaPlayer
    fi

    if [ "$soundFile" == "DEFAULT" ]; then
        soundFile=$oldSoundFile
    fi

    if [ "$printAlarmMessage" == "DEFAULT" ]; then
        printAlarmMessage=$oldPrintAlarmMessage
    fi

    if [ "$alarmMessage" == "DEFAULT" ]; then
        alarmMessage=$oldAlarmMessage
    fi

}


################################################################################


##  Check the number of arguments, exit if incorrect
if [ $# -gt 1 ]; then
    echo "Error:  Too many arguments" 1>&2
    echo "  Usage:  shalarm TIME" 1>&2
    echo -e "\nUse 'shalarm --help' for more info" 1>&2
    exit
elif [ $# -lt 1 ]; then
    echo "Error:  Too few arguments" 1>&2
    echo "  Usage:  shalarm TIME" 1>&2
    echo -e "\nUse 'shalarm --help' for more info" 1>&2
    exit
fi

##  Check the arguments
if [ $1 == '-h' ] || [ $1 == '--help' ]; then
    print_help
    exit
elif [ $1 == '-v' ] || [ $1 == '--version' ]; then
    print_version
    exit
elif [ $1 == '-t' ] || [ $1 == '--test' ]; then
    testAlarm=1
elif [ $1 == '-d' ] || [ $1 == '--debug' ]; then
    debugMode=1
fi


##  If appropriate, find the sound file
if [ $findSoundFile == 1 ]; then
    find_sound_file
fi

##  If appropriate, find the media player
if [ $findMediaPlayer == 1 ]; then
    find_media_player
fi

##  If we're looking for a config file, set options according to that
if [ $useConfig == 1 ]; then
    set_options
fi

##  If this is a test, use the test function.  Otherwise, operate as normal.
if [ $testAlarm == 1 ]; then
    set_test_alarm
else
    if [ $debugMode == 1 ]; then
        print_debug_info
        exit
    else
        parse_alarm_string $1
        set_alarm_time $alarmString
    fi
fi


########################################        MAIN LOOP

##  We double-check to make sure that $mediaPlayer and $soundFile exist
if [ ! -e "$soundFile" ]; then
    echo "Error:  Cannot find sound file $soundFile" 1>&2
    exit
elif [ ! -r "$soundFile" ]; then
    echo "Error:  Cannot read from file $soundFile" 1>&2
    exit
fi

if [ ! -e "$mediaPlayer" ]; then
    echo "Error:  Cannot find media player $mediaPlayer" 1>&2
    exit
elif [ ! -x "$mediaPlayer" ]; then
    echo "Error:  Lack execution permission for media player $mediaPlayer" 1>&2
    exit
fi


##  Tell the user what's up
if [ $testAlarm == 1 ]; then
    echo -e "\nTest alarm is ACTIVE ($alarmHour:$alarmMinute:$alarmSecond)"
else
    echo -e "\nAlarm is ACTIVE and set to $alarmHour:$alarmMinute:$alarmSecond"
fi

echo -e "   Use CTRL-C to quit\n"

##  We trap SIGINT (ctrl-c) and execute 'control_c' function if it's issued
trap control_c SIGINT

##  Do an alarm check every $checkInterval seconds (1 by default)
while true; do
    alarm_check
    sleep $checkInterval
done
