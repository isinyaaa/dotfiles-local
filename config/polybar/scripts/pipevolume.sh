#!/bin/bash

# finds the active sink for pulse audio and increments the volume. useful when you have multiple audio outputs and have a key bound to vol-up and down

osd='no'
inc='5'
capvol='no'
maxvol='200'
autosync='no'

active_sink=""
limit=$((100 - inc))
maxlimit=$((maxvol - inc))

reloadSink() {
    active_sink=$(grep 'RUNNING' <(pactl list sinks short) | cut -d'	' -f1)
    [ -n $active_sink ] || active_sink='@DEFAULT_SINK@'
}

function getCurVol {
    curVol=$(sed -n '/Sink \#'$active_sink'/,/\s*Volume:/p' <(pactl list sinks) | tail -n1 \
        | sed -e 's/.* \([0-9]*\)%.*/\1/')
}

function volUp {

    getCurVol

    if [ "$capvol" = 'yes' ]
    then
        if [ "$curVol" -le 100 ] && [ "$curVol" -ge "$limit" ]
        then
            pactl set-sink-volume "$active_sink" 100%
        elif [ "$curVol" -lt "$limit" ]
        then
            pactl set-sink-volume "$active_sink" "+$inc%"
        fi
    elif [ "$curVol" -le "$maxvol" ] && [ "$curVol" -ge "$maxlimit" ]
    then
        pactl set-sink-volume "$active_sink" "$maxvol%"
    elif [ "$curVol" -lt "$maxlimit" ]
    then
        pactl set-sink-volume "$active_sink" "+$inc%"
    fi

    #getCurVol

    #if [ ${osd} = 'yes' ]
    #then
    #    qdbus org.kde.kded /modules/kosd showVolume "$curVol" 0
    #fi

    if [ ${autosync} = 'yes' ]
    then
        volSync
    fi
}

function volDown {

    pactl set-sink-volume "$active_sink" "-$inc%"
    getCurVol

    #if [ ${osd} = 'yes' ]
    #then
    #    qdbus org.kde.kded /modules/kosd showVolume "$curVol" 0
    #fi

    #if [ ${autosync} = 'yes' ]
    #then
    #    volSync
    #fi

}

function getSinkInputs {
    input_array=$(pactl list sink-inputs | grep -B 4 "sink: $1 " | awk '/index:/{print $2}')
}

function volSync {
    getSinkInputs "$active_sink"
    getCurVol

    for each in $input_array
    do
        pactl set-sink-input-volume "$each" "$curVol%"
    done
}

function volMute {
    case "$1" in
        mute)
            pactl set-sink-mute "$active_sink" 1
            curVol=0
            #status=1
            ;;
        unmute)
            pactl set-sink-mute "$active_sink" 0
            getCurVol
            #status=0
            ;;
        toggle)
            pactl set-sink-mute "$active_sink" toggle
            getCurVol
            #status=0
            ;;
    esac

    #if [ ${osd} = 'yes' ]
    #then
    #    qdbus org.kde.kded /modules/kosd showVolume ${curVol} ${status}
    #fi

}

function volMuteStatus {
    curStatus=$(pactl list sinks | grep -A 15 "index: $active_sink$" | awk '/muted/{ print $2}')
}

# Prints output for bar
# Listens for events for fast update speed
function listen {
    firstrun=0

    pactl subscribe 2>/dev/null | {
        while true; do
            {
                # If this is the first time just continue
                # and print the current state
                # Otherwise wait for events
                # This is to prevent the module being empty until
                # an event occurs
                if [ $firstrun -eq 0 ]
                then
                    firstrun=1
                else
                    read -r event || break
                    if ! echo "$event" | grep -e "on card" -e "on sink"
                    then
                        # Avoid double events
                        continue
                    fi
                fi
            } &>/dev/null
            output
        done
    }
}

function output() {
    reloadSink
    getCurVol
    volMuteStatus
    if [ "${curStatus}" = 'yes' ]
    then
        echo "ﱝ mute"
    else
        if [ $curVol -gt 70 ]; then
            echo "墳 $curVol%"
        elif [ $curVol -gt 30 ]; then
          echo "奔 $curVol%"
        else
          echo "奄 $curVol%"
        fi
    fi
} #}}}

reloadSink
case "$1" in
    --up)
        volUp
        ;;
    --down)
        volDown
        ;;
    --togmute)
        volMute toggle
        ;;
    --mute)
        volMute mute
        ;;
    --unmute)
        volMute unmute
        ;;
    --sync)
        volSync
        ;;
    --listen)
        # Listen for changes and immediately create new output for the bar
        # This is faster than having the script on an interval
        listen
        ;;
    *)
        # By default print output for bar
        output
        ;;
esac
