#!/bin/sh
# linbo.sh - Start Linbo GUI (with optional debug shell before)
# This is a busybox 1.1.3 script
# (C) Klaus Knopper 2007
# License: GPL V2
# thomas@linuxmuster.net
# 20240720
#

# Reset fb color mode
RESET="]R"
# Clear and reset Screen
CLEAR="c"

# get environment
source /usr/share/linbo/shell_functions

# plymouth
if [ -x "/sbin/plymouthd" -a -n "$SPLASH" ]; then
  if ! plymouth --ping &> /dev/null; then
    plymouthd --mode=boot --tty="/dev/tty2" --attach-to-session
    plymouth show-splash message --text="$LINBOFULLVER"
  fi
fi

# send clients hwinfo
[ -s /tmp/hwinfo.gz ] && sendlog /tmp/hwinfo.gz

# update & extract linbo_gui, disabled since there is no compatible version for 22.04
linbo_update_gui | tee -a /tmp/linbo.log
sendlog

# DEBUG mode
if [ -n "$DEBUG" ]; then
  plymouth quit
  for item in /tmp/linbo_gui.*.log; do
    if [ -s "$item" ]; then
      echo "There is a logfile from a previous start of linbo_gui in $item:"
      cat "$item"
      echo -n "Press enter key to continue."
      read dummy
      rm -f "$item"
    fi
  done
  echo "Starting DEBUG shell, leave with 'exit'."
  ash >/dev/tty1 2>&1 < /dev/tty1
fi

# Start LINBO GUI
if [ -s /usr/bin/linbo_gui ]; then

  plymouth quit &> /dev/null
  export XKB_DEFAULT_LAYOUT=de
  /usr/bin/linbo_gui -platform linuxfb
  sendlog

else # handle missing gui problem

  plymouth quit
  if [ -n "$DEBUG" ]; then
    echo "Starting DEBUG shell." | tee -a /tmp/linbo.log
    ash >/dev/tty1 2>&1 < /dev/tty1
  else
    export myname="| Name: $HOSTNAME"
    source /.profile
    echo "Console boot menue of group $HOSTGROUP" | tee -a /tmp/linbo.log
    echo "----------------------------------------" | tee -a /tmp/linbo.log
    count=0
    for item in /conf/os.*; do
      [ -s "$item" ] || continue
      name=""
      source "$item"
      [ -z "$name" ] && continue
      count=$(( count + 1 ))
      echo "[$count] Start $name" | tee -a /tmp/linbo.log
      count=$(( count + 1 ))
      echo "[$count] Sync & start $name" | tee -a /tmp/linbo.log
    done
    echo "----------------------------------------" | tee -a /tmp/linbo.log
    echo "[R] Reboot" | tee -a /tmp/linbo.log
    echo "[S] Shutdown" | tee -a /tmp/linbo.log
    echo
    sendlog
    while true; do
      answer=$(stty -icanon -echo; dd ibs=1 count=1 2>/dev/null)
      case "$answer" in
        r|R) /sbin/reboot ;;
        s|S) /sbin/poweroff ;;
        *)
          isinteger $answer || continue
          osnr=$(($answer-$(($answer/2))))
          if iseven $answer; then linbo_syncstart $osnr; else linbo_start $osnr; fi
          ;;
      esac
    done
  fi
fi
