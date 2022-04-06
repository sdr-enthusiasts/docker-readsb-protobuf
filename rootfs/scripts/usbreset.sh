#!/usr/bin/with-contenv bash
# shellcheck shell=bash

if [[ "$READSB_DEVICE_TYPE" == "rtlsdr" ]]; then
    if [[ -n "$READSB_USBRESET" ]]; then
      sleep 30
      USBNAME=RTL2838
      LSUSB=$(lsusb | grep --ignore-case $USBNAME)
      DEVICE=$(echo $LSUSB | cut --delimiter=' ' --fields='2')"/"$(echo $LSUSB | cut --delimiter=' ' --fields='4' | tr --delete ":")
      usbreset $DEVICE
    fi
fi
