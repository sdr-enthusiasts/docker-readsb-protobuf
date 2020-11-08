#!/usr/bin/env bash

# This script is designed to test /scripts/autogain.sh.
#
# It achieves this by running the autogain script against collected protobuf data,
# in rapid succession, by fudging the timestamp.
#
# If there is any output to stderr that is not listed in ALLOWED_STDERR, the test fails.
# 

# Colors
NOCOLOR='\033[0m'
CYAN='\033[0;36m'
LIGHTRED='\033[1;31m'
LIGHTGREEN='\033[1;32m'
YELLOW='\033[1;33m'
LIGHTBLUE='\033[1;34m'

# Define valid gain levels
gain_levels=()
gain_levels+=(0.0)
gain_levels+=(0.9)
gain_levels+=(1.4)
gain_levels+=(2.7)
gain_levels+=(3.7)
gain_levels+=(7.7)
gain_levels+=(8.7)
gain_levels+=(12.5)
gain_levels+=(14.4)
gain_levels+=(15.7)
gain_levels+=(16.6)
gain_levels+=(19.7)
gain_levels+=(20.7)
gain_levels+=(22.9)
gain_levels+=(25.4)
gain_levels+=(28.0)
gain_levels+=(29.7)
gain_levels+=(32.8)
gain_levels+=(33.8)
gain_levels+=(36.4)
gain_levels+=(37.2)
gain_levels+=(38.6)
gain_levels+=(40.2)
gain_levels+=(42.1)
gain_levels+=(43.4)
gain_levels+=(43.9)
gain_levels+=(44.5)
gain_levels+=(48.0)
gain_levels+=(49.6)

# Define allowed stderr output
ALLOWED_STDERR=()
for i in "${gain_levels[@]}"; do
    ALLOWED_STDERR+=("Insufficient messages received for accurate measurement, extending runtime of gain $i dB.")
    ALLOWED_STDERR+=("Reducing gain to: $i dB")
    ALLOWED_STDERR+=("Insufficient data available, extending runtime of gain $i dB.")
    ALLOWED_STDERR+=("Container restart detected, resuming auto-gain state 'init' with gain $i dB")
    ALLOWED_STDERR+=("Auto-gain stage 'init' complete. Best gain figure appears to be: $i dB.")
    ALLOWED_STDERR+=("Container restart detected, resuming auto-gain state 'finetune' with gain $i dB")
    ALLOWED_STDERR+=("Auto-gain stage 'finetune' complete. Best gain figure appears to be: $i dB.")
done
ALLOWED_STDERR+=("Entering auto-gain stage: init")
ALLOWED_STDERR+=("Entering auto-gain stage: finetune")
ALLOWED_STDERR+=("Entering auto-gain stage: finished")

set -eo pipefail

# set up environment
echo -e "${LIGHTBLUE}==== SETTING UP TEST ENVIRONMENT ====${NOCOLOR}"

# pretend user wants autogain  & initialise gain script has been run
READSB_GAIN="autogain"
export READSB_GAIN
echo "49.6" > "$AUTOGAIN_CURRENT_VALUE_FILE"
RUNCOUNT=0

# Reduce msgs accepted to speed up testing
AUTOGAIN_INITIAL_MSGS_ACCEPTED=500000
export AUTOGAIN_INITIAL_MSGS_ACCEPTED
AUTOGAIN_FINETUNE_MSGS_ACCEPTED=1000000
export AUTOGAIN_FINETUNE_MSGS_ACCEPTED

# prepare testing timestamp variable
AUTOGAIN_TESTING_TIMESTAMP=$(date +%s)
export AUTOGAIN_TESTING_TIMESTAMP

echo ""

# test loop
while true; do
    for testdatafile in /autogain_test_data/*.pb.*; do

        echo -e "${LIGHTBLUE}==== TESTING TIMESTAMP $AUTOGAIN_TESTING_TIMESTAMP ====${NOCOLOR}"
        echo -n "$(cat /run/autogain/autogain_current_timestamp 2> /dev/null) "
        echo -n "$(cat /run/autogain/autogain_current_value 2> /dev/null) "
        echo -n "$(cat /run/autogain/autogain_max_value 2> /dev/null) "
        echo -n "$(cat /run/autogain/autogain_min_value 2> /dev/null) "
        echo -n "$(cat /run/autogain/autogain_review_timestamp 2> /dev/null) "
        echo -n "$(cat /run/autogain/autogain_review_timestamp 2> /dev/null) "
        echo -n "$(cat /run/autogain/state 2> /dev/null) "
        echo ""

        rm /tmp/test_* > /dev/null 2>&1 || true

        # copy test data file
        cp "$testdatafile" "$READSB_STATS_PB_FILE" > /dev/null

        # run test
        if bash -xo pipefail /scripts/autogain.sh > /tmp/test_stdout 2> /tmp/test_stderr; then
            :
        else
            echo ""
            echo -e "${LIGHTRED}==== FULL STDERR ====${NOCOLOR}"
            # shellcheck disable=SC2094
            cat /tmp/test_stderr
            echo ""
            echo -e "${LIGHTRED}=====================${NOCOLOR}"
            echo ""
            echo -e "${LIGHTRED}FAIL - non zero exit code${NOCOLOR}"
            exit 1
        fi

        if [[ -s /tmp/test_stdout ]]; then
            echo -e "${CYAN}stdout:${NOCOLOR}"
            cat /tmp/test_stdout
        fi

        if [[ -s /tmp/test_stderr ]]; then
            echo -e "${CYAN}stderr:${NOCOLOR}"

            # shellcheck disable=SC2094
            while read -r line; do
                if echo "$line" | grep -P '^\++ ' > /dev/null 2>&1; then
                    # output from set -x, ignore this
                    :
                else
                    unset KNOWN_STDERR
                    for i in "${ALLOWED_STDERR[@]}"; do
                        if [[ "$line" == "$i" ]]; then
                            KNOWN_STDERR=1
                        fi
                    done
                    if [[ -z "$KNOWN_STDERR" ]]; then
                        echo ""
                        echo -e "${LIGHTRED}==== FULL STDERR ====${NOCOLOR}"
                        # shellcheck disable=SC2094
                        cat /tmp/test_stderr
                        echo ""
                        echo -e "${LIGHTRED}=====================${NOCOLOR}"
                        echo ""
                        echo -e "${YELLOW}$line${NOCOLOR}"
                        echo -e "${LIGHTRED}FAIL - unknown stderr${NOCOLOR}"
                        echo ""
                        exit 1
                    else
                        echo "$line"
                    fi
                fi
            done < /tmp/test_stderr
            echo ""
        fi

        # If we're here, tests passed
        echo -e "${LIGHTGREEN}PASS${NOCOLOR}"
        echo ""

        # advance clock
        if [[ "$(cat "$AUTOGAIN_STATE_FILE")" == "finished" ]]; then
            RUNCOUNT=$((RUNCOUNT + 1))
            AUTOGAIN_TESTING_TIMESTAMP=$((AUTOGAIN_TESTING_TIMESTAMP + 86400))
        else
            AUTOGAIN_TESTING_TIMESTAMP=$((AUTOGAIN_TESTING_TIMESTAMP + 900))
        fi

        if [[ "$RUNCOUNT" -ge "1" ]]; then
            echo ""
            echo -e "${LIGHTGREEN}Simulated $RUNCOUNT full run(s). All tests passed.${NOCOLOR}"
            echo ""
            exit 0
        fi

    done

    rm "$AUTOGAIN_RUNNING_FILE"

done
