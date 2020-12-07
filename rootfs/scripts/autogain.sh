#!/usr/bin/with-contenv bash
# shellcheck shell=bash

# If troubleshooting:
if [[ -n "$DEBUG_LOGGING" ]]; then
    set -x
    VERBOSE_LOGGING=true
fi

# Define globals

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

# Files containing variables to persist between runs of this script
AUTOGAIN_LOGFILE="/run/autogain/autogain_log"
echo "" >> "$AUTOGAIN_LOGFILE"
# longest range (max_distance_in_metres)
AUTOGAIN_STATS_MAX_DISTANCE_FILE="/run/autogain/autogain_stats.max_distance"
# percentage strong messages (local_strong_signals/local_accepted)
AUTOGAIN_STATS_PERCENT_STRONG_MSGS_FILE="/run/autogain/autogain_stats.pct_strong_msgs"
# largest number of received messages (local_accepted)
AUTOGAIN_STATS_TOTAL_ACCEPTED_MSGS_FILE="/run/autogain/autogain_stats.total_accepted_msgs"
# best SNR (local_signal - local_noise)
AUTOGAIN_STATS_SNR_FILE="/run/autogain/autogain_stats.snr"
# number of tracks with position
AUTOGAIN_STATS_TRACKS_NEW_FILE="/run/autogain/autogain_stats.tracks_new"
# update interval
AUTOGAIN_INTERVAL_FILE="/run/autogain/autogain_interval"
# results for init stage
AUTOGAIN_RESULTS_FILE="/run/autogain/autogain_results"
# previos stats files - allows stats to persist through container restart 
AUTOGAIN_STATS_PREVIOUS_MAX_DISTANCE_FILE="/run/autogain/autogain_stats_current.max_distance"
AUTOGAIN_STATS_PREVIOUS_LOCAL_STRONG_MSGS_FILE="/run/autogain/autogain_stats_current.local_strong_msgs"
AUTOGAIN_STATS_PREVIOUS_LOCAL_ACCEPTED_MSGS_FILE="/run/autogain/autogain_stats_current.local_accepted"
AUTOGAIN_STATS_PREVIOUS_LOCAL_SIGNAL_FILE="/run/autogain/autogain_stats_current.local_signal"
AUTOGAIN_STATS_PREVIOUS_LOCAL_NOISE_FILE="/run/autogain/autogain_stats_current.local_noise"
AUTOGAIN_STATS_PREVIOUS_TRACKS_NEW_FILE="/run/autogain/autogain_stats_current.tracks_new"
AUTOGAIN_STATS_PREVIOUS_TIMESTAMP_FILE="/run/autogain/autogain_stats_current.timestamp"
# offset stats files - allows stats prior to container restarts to be added to results
AUTOGAIN_STATS_OFFSET_MAX_DISTANCE_FILE="/run/autogain/autogain_stats_offset.max_distance"
AUTOGAIN_STATS_OFFSET_TOTAL_STRONG_MSGS_FILE="/run/autogain/autogain_stats_offset.local_strong_msgs"
AUTOGAIN_STATS_OFFSET_TOTAL_ACCEPTED_MSGS_FILE="/run/autogain/autogain_stats_offset.local_accepted"
AUTOGAIN_STATS_OFFSET_TRACKS_NEW_FILE="/run/autogain/autogain_stats_offset.tracks_new"

# Define functions

function logger() {
    # Log to the console
    # $1 = log message
    # -----
    #shellcheck disable=SC2016
    >&2 echo "$1" | stdbuf -o0 awk '{print "[autogain] " strftime("%Y/%m/%d %H:%M:%S", systime()) " " $0}'
    echo "$(date --rfc-3339=s) $1" >> "$AUTOGAIN_LOGFILE"
}

function logger_verbose() {
    # Log to the console only if VERBOSE_LOGGING is set
    # $1 = log message
    # -----
    if [[ -n "$VERBOSE_LOGGING" ]]; then
        #shellcheck disable=SC2016
        >&2 echo "[$(cat "$AUTOGAIN_STATE_FILE")] $1" | stdbuf -o0 awk '{print "[autogain] " strftime("%Y/%m/%d %H:%M:%S", systime()) " " $0}'
    fi
    echo "$(date --rfc-3339=s) [$(cat "$AUTOGAIN_STATE_FILE")] $1" >> "$AUTOGAIN_LOGFILE"
}

function logger_debug() {
    # Log to the log file only
    # $1 = log message
    # -----
    echo "$(date --rfc-3339=s) [$(cat "$AUTOGAIN_STATE_FILE")] DEBUG: $1" >> "$AUTOGAIN_LOGFILE"
}

function get_current_timestamp() {
    # Return current timestamp. If testing, return a timestamp defined by $AUTOGAIN_TESTING_TIMESTAMP
    #-----
    logger_debug "Entering: get_current_timestamp"
    if [[ -z "$AUTOGAIN_TESTING_TIMESTAMP" ]]; then
        date +%s
    else
        echo "$AUTOGAIN_TESTING_TIMESTAMP"
    fi
    logger_debug "Exiting: get_current_timestamp"
}

function increase_review_timestamp() {
    # Set review time to now + seconds
    # $1 = number of seconds (optional)
    #-----

    logger_debug "Entering: increase_review_timestamp"

    if [[ -n "$1" ]]; then
        num_seconds="$1"
    else
        num_seconds=3600
    fi
    
    local new_timestamp
    new_timestamp="$(($(get_current_timestamp) + num_seconds))"
    logger_debug "Setting review timestamp to: $new_timestamp"
    echo "$new_timestamp" > "$AUTOGAIN_REVIEW_TIMESTAMP_FILE"

    logger_debug "Exiting: increase_review_timestamp"
}

function increase_review_timestamp_after_container_restart() {
    # Set review time to what it was + number of seconds since last stats store
    #-----

    logger_debug "Entering: increase_review_timestamp_after_container_restart"

    if [[ -e "$AUTOGAIN_STATS_PREVIOUS_TIMESTAMP_FILE" ]]; then

        time_delta="$(($(get_current_timestamp) - $(cat "$AUTOGAIN_STATS_PREVIOUS_TIMESTAMP_FILE")))"
        logger_debug "time_delta: $time_delta"
        new_timestamp="$(($(cat "$AUTOGAIN_REVIEW_TIMESTAMP_FILE") + time_delta))"
        logger_debug "Setting review timestamp to: $new_timestamp"
        echo "$new_timestamp" > "$AUTOGAIN_REVIEW_TIMESTAMP_FILE"

    else
        increase_review_timestamp 900
    fi

    logger_debug "Exiting: increase_review_timestamp_after_container_restart"

}

function review_is_due() {
    logger_debug "Entering: review_is_due"
    # Check if it is time to review
    if [[ "$(get_current_timestamp)" -ge "$(cat "$AUTOGAIN_REVIEW_TIMESTAMP_FILE")" ]]; then
        logger_debug "Review is due"
    else
        logger_debug "Review is not yet due"
        return 1
    fi
}

function sufficient_local_accepted() {
    logger_debug "Entering: sufficient_local_accepted"
    # Check if sufficient local_accepted
    # $1 = number of local_accepted we should have
    # -----
    if [[ "$(get_local_accepted)" -ge "$1" ]]; then
        logger_debug "Sufficient local_accepted"
    else
        logger_debug "Insufficient local_accepted"
        return 1
    fi
}

function get_gain_number() {
    # Get the array element number of a gain value
    # $1 = gain figure (a value in gain_levels)
    # -----
    logger_debug "Entering: get_gain_number"
    for ((i = 0 ; i < ${#gain_levels[@]} ; i++)); do
        if [[ "${gain_levels[$i]}" == "$1" ]]; then
            logger_verbose "DEBUG: Gain $1 dB is gain level $i"
            echo "$i"
            break
        fi
    done
    logger_debug "Exiting: get_gain_number"
}

function set_readsb_gain() {
    # Set readsb gain
    # $1 = gain figure (a value in gain_levels)
    # -----
    logger_debug "Entering: set_readsb_gain"
    # Update gain files
    logger_verbose "Setting gain to $1 dB"
    echo "$1" > "$AUTOGAIN_CURRENT_VALUE_FILE"
    cp "$AUTOGAIN_CURRENT_VALUE_FILE" "$GAIN_VALUE_FILE"

    # Restart readsb (if not testing)
    logger_verbose "Restarting readsb"
    if [[ -z "$AUTOGAIN_TESTING_TIMESTAMP" ]]; then
        pkill -ef "/usr/local/bin/readsb " > /dev/null 2>&1
    fi

    # Store timestamp gain was updated
    get_current_timestamp > "$AUTOGAIN_CURRENT_TIMESTAMP_FILE"
    logger_debug "Exiting: set_readsb_gain"
}

function get_readsb_stat() {
    # Pull a statistic from readsb's stats.pb file
    # $1 = section ('total', 'latest', 'last_1min', etc - from protobuf .proto)
    # $2 = key (from latest)
    # -----
    logger_debug "Entering: get_readsb_stat"
    # Get latest section from protobuf, get line including the key we're after:
    protoc_output=$(protoc \
            --proto_path="$READSB_PROTO_PATH" \
            --decode Statistics \
            readsb.proto < "$READSB_STATS_PB_FILE" 2> /dev/null | \
                grep -A 999 --max-count=1 "$1 {" 2> /dev/null | \
                grep -B 999 --max-count=1 '}' 2> /dev/null | \
                grep -v '{' 2> /dev/null | \
                grep -v '}' 2> /dev/null | \
                tr -d ' ' 2> /dev/null | \
                grep "$2" 2> /dev/null | \
                cut -d ':' -f 2 2> /dev/null)

    logger_debug "readsb stat $1:$2 = $protoc_output"

    if [[ -z "$protoc_output" ]]; then
        logger_verbose "Error looking up $1:$2 from readsb stats!"
        return 1
    fi

    echo "$protoc_output"
    logger_debug "Exiting: get_readsb_stat"
}

function are_required_stats_available() {
    # Ensures all required stats are available from readsb's stats.pb
    # Make sure any required stats are added and this function is called prior to interpreting any results
    # -----
    logger_debug "Entering: are_required_stats_available"
    local stats_used
    stats_used=()
    # don't need to worry about strong signals, if not available we use zero.
    #stats_used+=("total local_strong_signals")
    stats_used+=("total local_accepted")
    stats_used+=("total local_signal")
    stats_used+=("total local_noise")
    stats_used+=("total max_distance_in_metres")
    stats_used+=("total tracks_new")
    stats_used+=("last_15min local_signal")
    stats_used+=("last_15min local_noise")

    for stat_used in "${stats_used[@]}"; do

        # Word splitting is by design in the commands below, so disable the shellcheck alert
        #shellcheck disable=SC2086
        if ! get_readsb_stat $stat_used > /dev/null; then
            logger_debug "Stat $(echo $stat_used | tr ' ' ':') not yet available."
            return 1
        fi
    done
    logger_debug "Exiting: are_requird_stats_available"
}

function get_local_strong_signals() {
    # Return the number of "strong signals"
    # -----
    logger_debug "Entering: get_local_strong_signals"

    if [[ -e "$AUTOGAIN_STATS_OFFSET_TOTAL_STRONG_MSGS_FILE" ]]; then
        local_strong_signals="$(get_readsb_stat total local_strong_signals)"
        AUTOGAIN_STATS_OFFSET_TOTAL_STRONG_MSGS=$(cat "$AUTOGAIN_STATS_OFFSET_TOTAL_STRONG_MSGS_FILE")
        bc_expression="scale=4; ${local_strong_signals:-0} + ${AUTOGAIN_STATS_OFFSET_TOTAL_STRONG_MSGS:-0}"
        local_strong_signals=$(echo "$bc_expression" | bc)
    else
        local_strong_signals="$(get_readsb_stat total local_strong_signals)"
    fi

    logger_debug "local_strong_signals: ${local_strong_signals:-0}"
    echo "${local_strong_signals:-0}"

    logger_debug "Exiting: get_local_strong_signals"
}

function get_pct_strong_signals() {
    # Return the percentage of "strong signals"
    # -----
    logger_debug "Entering: get_pct_strong_signals"
    local local_strong_signals
    local local_accepted
    local pct_strong_signals
    if ! local_strong_signals=$(get_local_strong_signals); then
        logger_debug "No 'local_strong_signals' measurement! Setting to 0."
        local_strong_signals=0
    fi
    local_accepted=$(get_local_accepted)
    pct_strong_signals="$(echo "scale=4; ($local_strong_signals / $local_accepted) * 100" | bc -l)"
    logger_debug "Percentage of strong signals: $pct_strong_signals"
    echo "$pct_strong_signals"
    logger_debug "Exiting: get_pct_strong_signals"
}

function get_tracks_new() {
    # Return the number of tracks with position
    # -----
    logger_debug "Entering: get_tracks_new"
    local tracks_new
    if ! tracks_new=$(get_readsb_stat total tracks_new); then
        logger_debug "No 'tracks_new' measurement! Setting to 0."
        tracks_new=0
    fi

    if [[ -e "$AUTOGAIN_STATS_OFFSET_TRACKS_NEW_FILE" ]]; then
        AUTOGAIN_STATS_OFFSET_TRACKS_NEW=$(cat "$AUTOGAIN_STATS_OFFSET_TRACKS_NEW_FILE")
        bc_expression="scale=4; $tracks_new + ${AUTOGAIN_STATS_OFFSET_TRACKS_NEW:-0}"
        tracks_new=$(echo "$bc_expression" | bc)
    fi

    logger_debug "tracks_new: $tracks_new"
    echo "$tracks_new"
    logger_debug "Exiting: tracks_new"
}

function get_local_signal() {
    # Return the local signal
    # -----

    logger_debug "Entering: get_local_signal"

    if [[ -e "$AUTOGAIN_STATS_PREVIOUS_LOCAL_SIGNAL_FILE" ]]; then

        signal_sum=0.0
        signal_count=0
        while read -r line; do
            bc_expression="$signal_sum + $line"
            signal_sum=$(echo "$bc_expression" | bc -l)
            signal_count=$((signal_count+1))
        done < "$AUTOGAIN_STATS_PREVIOUS_LOCAL_SIGNAL_FILE"

        bc_expression="scale=8; $signal_sum / $signal_count"
        local_signal=$(echo "$bc_expression" | bc -l)

    else
        local_signal="$(get_readsb_stat total local_signal)"
    fi

    logger_debug "local_signal: $local_signal"
    echo "$local_signal"

    logger_debug "Exiting: get_local_signal"
}

function get_local_noise() {
    # Return the local noise
    # -----

    logger_debug "Entering: get_local_noise"

    if [[ -e "$AUTOGAIN_STATS_PREVIOUS_LOCAL_NOISE_FILE" ]]; then

        noise_sum=0.0
        noise_count=0
        while read -r line; do
            bc_expression="$noise_sum + $line"
            noise_sum=$(echo "$bc_expression" | bc -l)
            noise_count=$((noise_count+1))
        done < "$AUTOGAIN_STATS_PREVIOUS_LOCAL_NOISE_FILE"

        bc_expression="scale=8; $noise_sum / $noise_count"
        local_noise=$(echo "$bc_expression" | bc -l)

    else
        local_noise="$(get_readsb_stat total local_noise)"
    fi

    logger_debug "local_noise: $local_noise"
    echo "$local_noise"

    logger_debug "Exiting: get_local_noise"
}

function get_snr() {
    # Return the signal to noise ratio (local_signal - local_noise)
    # -----

    logger_debug "Entering: get_snr"
    local local_signal
    local local_noise
    local_signal=$(get_local_signal)
    local_noise=$(get_local_noise)
    local_snr=$(echo "$local_signal - $local_noise" | bc -l)
    logger_debug "local_snr: $local_snr"
    echo "$local_snr"

    logger_debug "Exiting: get_snr"
}

function get_local_accepted () {
    logger_debug "Entering: get_local_accepted"

    if [[ -e "$AUTOGAIN_STATS_OFFSET_TOTAL_ACCEPTED_MSGS_FILE" ]]; then
        AUTOGAIN_STATS_OFFSET_TOTAL_ACCEPTED_MSGS=$(cat "$AUTOGAIN_STATS_OFFSET_TOTAL_ACCEPTED_MSGS_FILE")
        bc_expression="scale=4; $(get_readsb_stat total local_accepted) + ${AUTOGAIN_STATS_OFFSET_TOTAL_ACCEPTED_MSGS:-0}"
        local_accepted=$(echo "$bc_expression" | bc -l)
    else
        local_accepted="$(get_readsb_stat total local_accepted)"
    fi

    logger_debug "local_accepted: $local_accepted"
    echo "$local_accepted"

    logger_debug "Exiting: get_local_accepted"
}

function get_max_distance_in_metres () {
    logger_debug "Entering: get_max_distance_in_metres"

    max_distance_in_metres="$(get_readsb_stat total max_distance_in_metres)"

    if [[ -e "$AUTOGAIN_STATS_OFFSET_MAX_DISTANCE_FILE" ]]; then
        AUTOGAIN_STATS_OFFSET_MAX_DISTANCE=$(cat "$AUTOGAIN_STATS_OFFSET_MAX_DISTANCE_FILE")
        bc_expression="$max_distance_in_metres > ${AUTOGAIN_STATS_OFFSET_MAX_DISTANCE:-0}"
        if [[ ! $(echo "$bc_expression" | bc) -eq 1 ]]; then
            max_distance_in_metres=$(cat "$AUTOGAIN_STATS_OFFSET_MAX_DISTANCE_FILE")
        fi
    fi

    logger_debug "max_distance_in_metres: $max_distance_in_metres"
    echo "$max_distance_in_metres"

    logger_debug "Exiting: get_max_distance_in_metres"

}

function reduce_gain() {
    # Reduce the current gain by one step
    # -----
    logger_debug "Entering: reduce_gain"
    local gain_number
    gain_number="$(get_gain_number "$(cat "$AUTOGAIN_CURRENT_VALUE_FILE")")"
    gain_number=$((gain_number - 1))
    if [[ $gain_number -lt 0 ]]; then
        gain_number=0
    fi
    logger "Reducing gain to: ${gain_levels[$gain_number]} dB"
    set_readsb_gain "${gain_levels[$gain_number]}"
    logger_debug "Exiting: reduce_gain"
}

function rm_stats_files () {
    logger_debug "Entering: rm_stats_files"
    # Remove statistics files
    rm "$AUTOGAIN_STATS_MAX_DISTANCE_FILE" > /dev/null 2>&1 || true
    rm "$AUTOGAIN_STATS_PERCENT_STRONG_MSGS_FILE" > /dev/null 2>&1 || true
    rm "$AUTOGAIN_STATS_TOTAL_ACCEPTED_MSGS_FILE" > /dev/null 2>&1 || true
    rm "$AUTOGAIN_STATS_SNR_FILE" > /dev/null 2>&1 || true
    rm "$AUTOGAIN_STATS_TRACKS_NEW_FILE" > /dev/null 2>&1 || true
    rm_previous_and_offset_stats_files

    logger_debug "Exiting: rm_stats_files"
}

function rm_previous_and_offset_stats_files () {
    logger_debug "Entering: rm_previous_and_offset_stats_files"
    # Remove statistics files
    rm "$AUTOGAIN_STATS_PREVIOUS_MAX_DISTANCE_FILE" > /dev/null 2>&1 || true
    rm "$AUTOGAIN_STATS_PREVIOUS_LOCAL_STRONG_MSGS_FILE" > /dev/null 2>&1 || true
    rm "$AUTOGAIN_STATS_PREVIOUS_LOCAL_ACCEPTED_MSGS_FILE" > /dev/null 2>&1 || true
    rm "$AUTOGAIN_STATS_PREVIOUS_LOCAL_SIGNAL_FILE" > /dev/null 2>&1 || true
    rm "$AUTOGAIN_STATS_PREVIOUS_LOCAL_NOISE_FILE" > /dev/null 2>&1 || true
    rm "$AUTOGAIN_STATS_PREVIOUS_TRACKS_NEW_FILE" > /dev/null 2>&1 || true
    rm "$AUTOGAIN_STATS_OFFSET_MAX_DISTANCE_FILE" > /dev/null 2>&1 || true
    rm "$AUTOGAIN_STATS_OFFSET_TOTAL_STRONG_MSGS_FILE" > /dev/null 2>&1 || true
    rm "$AUTOGAIN_STATS_OFFSET_TOTAL_ACCEPTED_MSGS_FILE" > /dev/null 2>&1 || true
    rm "$AUTOGAIN_STATS_OFFSET_TRACKS_NEW_FILE" > /dev/null 2>&1 || true
    rm "$AUTOGAIN_STATS_PREVIOUS_TIMESTAMP_FILE" > /dev/null 2>&1 || true

    logger_debug "Exiting: rm_previous_and_offset_stats_files"
}

function archive_stats_files () {
    logger_debug "Entering: archive_stats_files"
    cp "$AUTOGAIN_STATS_MAX_DISTANCE_FILE" "$AUTOGAIN_STATS_MAX_DISTANCE_FILE.$(cat "$AUTOGAIN_STATE_FILE")"
    cp "$AUTOGAIN_STATS_PERCENT_STRONG_MSGS_FILE" "$AUTOGAIN_STATS_PERCENT_STRONG_MSGS_FILE.$(cat "$AUTOGAIN_STATE_FILE")"
    cp "$AUTOGAIN_STATS_TOTAL_ACCEPTED_MSGS_FILE" "$AUTOGAIN_STATS_TOTAL_ACCEPTED_MSGS_FILE.$(cat "$AUTOGAIN_STATE_FILE")"
    cp "$AUTOGAIN_STATS_SNR_FILE" "$AUTOGAIN_STATS_SNR_FILE.$(cat "$AUTOGAIN_STATE_FILE")"
    cp "$AUTOGAIN_STATS_TRACKS_NEW_FILE" "$AUTOGAIN_STATS_TRACKS_NEW_FILE.$(cat "$AUTOGAIN_STATE_FILE")"
    logger_debug "Exiting: archive_stats_files"
}

function autogain_change_into_state () {
    # Initialise auto-gain state
    # $1 = state name (init)
    # $2 = seconds until next check
    # -----
    
    # Set state to $1 (state name)
    echo "$1" > "$AUTOGAIN_STATE_FILE"
    logger "Entering auto-gain stage: $1"
    logger_debug "Entering: autogain_change_into_state"

    # Create running file so we can tell if the container has been restarted and we need to resume a previous run...
    touch "$AUTOGAIN_RUNNING_FILE"

    # Set timestamp of when current gain setting was set, to now
    get_current_timestamp > "$AUTOGAIN_CURRENT_TIMESTAMP_FILE"

    # Store interval
    echo "$2" > "$AUTOGAIN_INTERVAL_FILE"

    # Set review time for now + $2 (seconds until next check)
    echo $(($(get_current_timestamp) + $2)) > "$AUTOGAIN_REVIEW_TIMESTAMP_FILE"

    # Reset files
    rm_stats_files
    if [[ ! -e "$AUTOGAIN_MAX_GAIN_VALUE_FILE" ]]; then
        echo "$AUTOGAIN_MAX_GAIN_VALUE" > "$AUTOGAIN_MAX_GAIN_VALUE_FILE"
    fi
    if [[ ! -e "$AUTOGAIN_MIN_GAIN_VALUE_FILE" ]]; then
        echo "$AUTOGAIN_MIN_GAIN_VALUE" > "$AUTOGAIN_MIN_GAIN_VALUE_FILE"
    fi

    # If state isnt finished, then set gain to max
    if [[ ! "$1" == "finished" ]]; then

        # We should already be at max gain, check to make sure (maybe user wants to re-run autogain from scratch)
        if [[ $(cat "$AUTOGAIN_CURRENT_VALUE_FILE") == $(cat "$AUTOGAIN_MAX_GAIN_VALUE_FILE") ]]; then
            logger_debug "Gain set to: $(cat "$AUTOGAIN_CURRENT_VALUE_FILE") dB"
        
        # If not at max gain, we should be, so set it
        else
            logger_debug "Setting gain to maximum $(cat "$AUTOGAIN_MAX_GAIN_VALUE_FILE") dB"
            set_readsb_gain "$(cat "$AUTOGAIN_MAX_GAIN_VALUE_FILE")"
        fi
    fi
    logger_debug "Exiting: autogain_change_into_state"
}

function update_stats_files () {
    # Gather statistics from readsb into stats files
    # -----

    logger_debug "Entering: update_stats_files"

    # Get current gain level
    current_gain_setting=$(cat "$AUTOGAIN_CURRENT_VALUE_FILE")
    logger_debug "Current gain level is $current_gain_setting"

    # Write statistics for this gain level
    # longest range (max_distance_in_metres)
    echo "$current_gain_setting $(get_max_distance_in_metres)" >> "$AUTOGAIN_STATS_MAX_DISTANCE_FILE"
    # percentage strong messages (local_strong_signals/local_samples_processed)
    echo "$current_gain_setting $(get_pct_strong_signals)" >> "$AUTOGAIN_STATS_PERCENT_STRONG_MSGS_FILE"
    # largest number of received messages (local_accepted)
    echo "$current_gain_setting $(get_local_accepted)" >> "$AUTOGAIN_STATS_TOTAL_ACCEPTED_MSGS_FILE"
    # best SNR (local_signal - local_noise)
    echo "$current_gain_setting $(get_snr)" >> "$AUTOGAIN_STATS_SNR_FILE"
    # number of tracks_new
    echo "$current_gain_setting $(get_tracks_new)" >> "$AUTOGAIN_STATS_TRACKS_NEW_FILE"

    logger_debug "Exiting: update_stats_files"   
}

function store_current_counters () {
    # Store statistics from readsb into stats files for use if container is restarted
    # -----

    logger_debug "Entering: store_current_counters"

    if are_required_stats_available; then

        # Write statistics for this gain level

        # longest range (max_distance_in_metres)
        get_max_distance_in_metres > "$AUTOGAIN_STATS_PREVIOUS_MAX_DISTANCE_FILE"
        
        # percentage strong messages (local_strong_signals/local_samples_processed)
        get_local_strong_signals > "$AUTOGAIN_STATS_PREVIOUS_LOCAL_STRONG_MSGS_FILE"

        # largest number of received messages (local_accepted)
        get_local_accepted > "$AUTOGAIN_STATS_PREVIOUS_LOCAL_ACCEPTED_MSGS_FILE"

        # local_signal
        get_readsb_stat last_15min local_signal >> "$AUTOGAIN_STATS_PREVIOUS_LOCAL_SIGNAL_FILE"

        # local_noise
        get_readsb_stat last_15min local_noise >> "$AUTOGAIN_STATS_PREVIOUS_LOCAL_NOISE_FILE"

        # number of tracks_new
        get_tracks_new > "$AUTOGAIN_STATS_PREVIOUS_TRACKS_NEW_FILE"

        # store timestamp when stats were collected
        get_current_timestamp > "$AUTOGAIN_STATS_PREVIOUS_TIMESTAMP_FILE"

    fi

    logger_debug "Exiting: store_current_counters"   
}

function update_offsets_after_container_restart () {
    # Update offsets from statistics stored from store_current_counters
    # -----

    logger_debug "Entering: update_offsets_after_container_restart"
    
    # update offset files
    if [[ -e "$AUTOGAIN_STATS_PREVIOUS_MAX_DISTANCE_FILE" ]]; then
        cp "$AUTOGAIN_STATS_PREVIOUS_MAX_DISTANCE_FILE" "$AUTOGAIN_STATS_OFFSET_MAX_DISTANCE_FILE"
        rm "$AUTOGAIN_STATS_PREVIOUS_MAX_DISTANCE_FILE"
    fi
    if [[ -e "$AUTOGAIN_STATS_PREVIOUS_LOCAL_STRONG_MSGS_FILE" ]]; then
        cp "$AUTOGAIN_STATS_PREVIOUS_LOCAL_STRONG_MSGS_FILE" "$AUTOGAIN_STATS_OFFSET_TOTAL_STRONG_MSGS_FILE"
        rm "$AUTOGAIN_STATS_PREVIOUS_LOCAL_STRONG_MSGS_FILE"
    fi
    if [[ -e "$AUTOGAIN_STATS_PREVIOUS_LOCAL_ACCEPTED_MSGS_FILE" ]]; then
        cp "$AUTOGAIN_STATS_PREVIOUS_LOCAL_ACCEPTED_MSGS_FILE" "$AUTOGAIN_STATS_OFFSET_TOTAL_ACCEPTED_MSGS_FILE"
        rm "$AUTOGAIN_STATS_PREVIOUS_LOCAL_ACCEPTED_MSGS_FILE"
    fi
    if [[ -e "$AUTOGAIN_STATS_PREVIOUS_TRACKS_NEW_FILE" ]]; then
        cp "$AUTOGAIN_STATS_PREVIOUS_TRACKS_NEW_FILE" "$AUTOGAIN_STATS_OFFSET_TRACKS_NEW_FILE"
        rm "$AUTOGAIN_STATS_PREVIOUS_TRACKS_NEW_FILE"
    fi

    logger_debug "Exiting: update_offsets_after_container_restart"

}

function rank_gain_levels () {
    # Ranks the gain levels to determine a suitable range
    # -----
    
    logger_debug "Entering: rank_gain_levels"

    # Prepare gain_rank dictionary with all tested gain levels
    declare -A gain_rank
    while read -r line; do
        gain_level=$(echo "$line" | cut -d ' ' -f 1)
        gain_rank[$gain_level]=0
    done < "$AUTOGAIN_STATS_PERCENT_STRONG_MSGS_FILE"

    # Rank longest range and award points
    sort -n -k2 -o "$AUTOGAIN_STATS_MAX_DISTANCE_FILE" "$AUTOGAIN_STATS_MAX_DISTANCE_FILE"
    points=0
    while read -r line; do
        gain_level=$(echo "$line" | cut -d ' ' -f 1)
        value=$(echo "$line" | cut -d ' ' -f 2)
        gain_rank[$gain_level]=$((gain_rank[$gain_level] + points))
        points=$((points + 1))
    done < "$AUTOGAIN_STATS_MAX_DISTANCE_FILE"

    # -100 points for percentage strong messages less than AUTOGAIN_PERCENT_STRONG_MESSAGES_MIN (local_strong_signals/local_samples_processed)
    # -100 as we don't want to use them
    while read -r line; do
        gain_level=$(echo "$line" | cut -d ' ' -f 1)
        value=$(echo "$line" | cut -d ' ' -f 2)
        bc_expression="$value < $AUTOGAIN_PERCENT_STRONG_MESSAGES_MIN"
        if [[ $(echo "$bc_expression" | bc -l) -eq 1 ]]; then
            gain_rank[$gain_level]=$((gain_rank[$gain_level] - 100))
        fi
    done < "$AUTOGAIN_STATS_PERCENT_STRONG_MSGS_FILE"

    # -100 points for percentage strong messages greater than AUTOGAIN_PERCENT_STRONG_MESSAGES_MAX (local_strong_signals/local_samples_processed)
    # -100 as we don't want to use them
    while read -r line; do
        gain_level=$(echo "$line" | cut -d ' ' -f 1)
        value=$(echo "$line" | cut -d ' ' -f 2)
        bc_expression="$value > $AUTOGAIN_PERCENT_STRONG_MESSAGES_MAX"
        if [[ $(echo "$bc_expression" | bc -l) -eq 1 ]]; then
            gain_rank[$gain_level]=$((gain_rank[$gain_level] - 100))
        fi
    done < "$AUTOGAIN_STATS_PERCENT_STRONG_MSGS_FILE"

    # Rank best SNR (local_signal - local_noise) and award points
    sort -n -k2 -o "$AUTOGAIN_STATS_SNR_FILE" "$AUTOGAIN_STATS_SNR_FILE"
    points=0
    while read -r line; do
        gain_level=$(echo "$line" | cut -d ' ' -f 1)
        value=$(echo "$line" | cut -d ' ' -f 2)
        gain_rank[$gain_level]=$((gain_rank[$gain_level] + points))
        points=$((points + 1))
    done < "$AUTOGAIN_STATS_SNR_FILE"

    # Write out results file
    for gain_level in "${!gain_rank[@]}"; do
        echo "$gain_level:${gain_rank[$gain_level]}" >> "/tmp/.autogain_results"
    done
    sort -n "/tmp/.autogain_results" > "$AUTOGAIN_RESULTS_FILE.$(cat "$AUTOGAIN_STATE_FILE")"
    rm "/tmp/.autogain_results"

    # Pick the gain level with the most points
    local best_gain_level_points
    local best_gain_level_value
    best_gain_level_points=-1000
    best_gain_level_value=0
    while read -r line; do
        gain_level_points=$(echo "$line" | cut -d ':' -f 2)
        gain_level_value=$(echo "$line" | cut -d ':' -f 1)
        logger_verbose "Gain level: $gain_level_value has $gain_level_points points."
        if [[ "$gain_level_points" -gt "$best_gain_level_points" ]]; then
            best_gain_level_points="$gain_level_points"
            best_gain_level_value="$gain_level_value"
        fi
    done < "$AUTOGAIN_RESULTS_FILE.$(cat "$AUTOGAIN_STATE_FILE")"

    echo "$best_gain_level_value"

    logger_debug "Exiting: rank_gain_levels"
}

function adjust_minimum_gain_if_required() {

    # Check to see whether we need to adjust minimum gain level
    # -----
    logger_debug "Entering: adjust_minimum_gain_if_required"

    # Prepare local variables
    local count_below_min
    count_below_min=0
    # For each line in the AUTOGAIN_STATS_PERCENT_STRONG_MSGS_FILE...
    while read -r line; do
        # Get gain level and percentage of strong messages
        gain_level=$(echo "$line" | cut -d ' ' -f 1)
        pct_strong_msgs=$(echo "$line" | cut -d ' ' -f 2)
        # Look for gain levels that have a suitable percentage of strong messages
        bc_expression="$pct_strong_msgs <= $AUTOGAIN_PERCENT_STRONG_MESSAGES_MAX"
        if [[ "$(echo "$bc_expression" | bc -l)" -eq 1 ]]; then
            bc_expression="$pct_strong_msgs >= $AUTOGAIN_PERCENT_STRONG_MESSAGES_MIN"
            if [[ "$(echo "$bc_expression" | bc -l)" -eq 1 ]]; then
                # Gain levels in this block are "good" (within min/max percent of strong messages)
                count_below_min=0
                logger_debug "adjust_minimum_gain_if_required: Found 'good' amount of strong messages at gain level $gain_level dB"
            else
                # Gain levels in this block are below min strong messages
                count_below_min=$((count_below_min + 1))
                logger_debug "adjust_minimum_gain_if_required: Consecutive below minimum % strong messages: $count_below_min"
                if [[ "$count_below_min" -eq "3" ]]; then
                    break
                fi
            fi
        else
            # Gain levels in this block are above max strong messages
            count_below_min=0
            logger_debug "adjust_minimum_gain_if_required: Found gain level with % strong messages above max at gain level $gain_level dB"
        fi                            
    done < "$AUTOGAIN_STATS_PERCENT_STRONG_MSGS_FILE"
    # If we've seen two consecutive "below minimums" after the "good" region, we've most likely gone past the "good" region.
    # Bring up the minimum gain
    if [[ "$count_below_min" -eq "3" ]]; then
        logger_verbose "Bringing up minimum gain level to: $(cat "$AUTOGAIN_CURRENT_VALUE_FILE") dB"
        cp "$AUTOGAIN_CURRENT_VALUE_FILE" "$AUTOGAIN_MIN_GAIN_VALUE_FILE"
    fi
    logger_debug "Exiting: adjust_minimum_gain_if_required"
}

function adjust_maximum_gain_if_required() {

    # Check to see whether we need to adjust minimum gain level
    # -----
    logger_debug "Entering: adjust_maximum_gain_if_required"

    # Prepare local variables
    local count_above_max
    count_above_max=0
    # re-order file with lowest gain at first line
    sort -n -o "$AUTOGAIN_STATS_PERCENT_STRONG_MSGS_FILE" "$AUTOGAIN_STATS_PERCENT_STRONG_MSGS_FILE"
    # For each line in the AUTOGAIN_STATS_PERCENT_STRONG_MSGS_FILE...
    while read -r line; do
        # Get gain level and percentage of strong messages
        gain_level=$(echo "$line" | cut -d ' ' -f 1)
        pct_strong_msgs=$(echo "$line" | cut -d ' ' -f 2)
        # Look for gain levels that have a suitable percentage of strong messages
        bc_expression="$pct_strong_msgs >= $AUTOGAIN_PERCENT_STRONG_MESSAGES_MIN"
        if [[ "$(echo "$bc_expression" | bc -l)" -eq 1 ]]; then
            bc_expression="$pct_strong_msgs <= $AUTOGAIN_PERCENT_STRONG_MESSAGES_MAX"
            if [[ "$(echo "$bc_expression" | bc -l)" -eq 1 ]]; then
                # Gain levels in this block are "good" (within min/max percent of strong messages)
                count_above_max=0
                logger_debug "adjust_maximum_gain_if_required: Found 'good' amount of strong messages at gain level $gain_level dB"
            else
                # Gain levels in this block are above max strong messages
                count_above_max=$((count_above_max + 1))
                logger_debug "adjust_maximum_gain_if_required: Consecutive above maximum % strong messages: $count_above_max"
                if [[ "$count_above_max" -eq "3" ]]; then
                    max_gain_value="$gain_level"
                    break
                fi
            fi
        else
            # Gain levels in this block are above max strong messages
            count_above_max=0
            logger_debug "adjust_maximum_gain_if_required: Found gain level with % strong messages below min at gain level $gain_level dB"
        fi                            
    done < "$AUTOGAIN_STATS_PERCENT_STRONG_MSGS_FILE"
    # Put order of the file back to normal
    sort -n -r -o "$AUTOGAIN_STATS_PERCENT_STRONG_MSGS_FILE" "$AUTOGAIN_STATS_PERCENT_STRONG_MSGS_FILE"

    # If we've seen two consecutive "above maximums" after the "good" region, we've most likely gone past the "good" region.
    # Lower the maximum gain
    if [[ "$count_above_max" -eq "3" ]]; then
        # TODO - only lower if AUTOGAIN_MAX_GAIN_VALUE_FILE gain is above max_gain_value
        logger_verbose "Lowering maximum gain level to: $max_gain_value dB"
        echo "$max_gain_value" > "$AUTOGAIN_MAX_GAIN_VALUE_FILE"
    fi
    logger_debug "Exiting: adjust_maximum_gain_if_required"
}

function is_current_gain_min_gain() {
    logger_debug "Entering: is_current_gain_min_gain"
    bc_expression="$(cat "$AUTOGAIN_CURRENT_VALUE_FILE") <= $(cat "$AUTOGAIN_MIN_GAIN_VALUE_FILE")"
    if [[ "$(echo "$bc_expression" | bc -l)" -eq "1" ]]; then
        logger_debug "Current gain is minimum gain"
    else
        logger_debug "Current gain is not minimum gain"
        return 1
    fi
    logger_debug "Exiting: is_current_gain_min_gain"
}

function autogain_finish_gainlevel_init() {
    # $1 = set to anything to go to the next gain level if needed
    # -----
    logger_debug "Entering: autogain_finish_state_init"
    # Set review time 
    increase_review_timestamp

    # Gather statistics for the current gain level
    update_stats_files

    # Check to see if we should adjust the minimum/maximum gain levels
    adjust_minimum_gain_if_required
    adjust_maximum_gain_if_required

    # If current gain is at the minimum gain, then we're done with this stage
    if is_current_gain_min_gain; then

        # Determine the best gain
        best_gain=$(rank_gain_levels)

        # Inform user
        logger "Auto-gain stage '$(cat "$AUTOGAIN_STATE_FILE")' complete. Best gain figure appears to be: $best_gain dB."                            

        # Block below commented out, as max & min gains should be set via adjust_minimum_gain_if_required/adjust_maximum_gain_if_required
        #
        # # Try values sandwiching the best gain
        # best_gain_number=$(get_gain_number "$best_gain")
        # upper_gain_number=$((best_gain_number + 3))
        # lower_gain_number=$((best_gain_number - 3))
        # if [[ $upper_gain_number -gt $((${#gain_levels[@]}-1)) ]]; then
        #     upper_gain_number=$((${#gain_levels[@]}-1))
        # fi
        # if [[ $lower_gain_number -lt 0 ]]; then
        #     lower_gain_number=0
        # fi
        # echo "${gain_levels[$upper_gain_number]}" > "$AUTOGAIN_MAX_GAIN_VALUE_FILE"
        # echo "${gain_levels[$lower_gain_number]}" > "$AUTOGAIN_MIN_GAIN_VALUE_FILE"
        #

        # Store original stats files for later review
        archive_stats_files

        # Initialise next stage
        autogain_change_into_state finetune "$AUTOGAIN_FINETUNE_PERIOD"

    # otherwise, reduce gain if required
    else
        if [[ -n "$1" ]]; then
            rm_previous_and_offset_stats_files
            reduce_gain
        fi
    fi
    logger_debug "Exiting: autogain_finish_state_init"
}

function autogain_finish_gainlevel_finetune() {
    # $1 = set to anything to go to the next gain level if needed
    # -----    
    logger_debug "Entering: autogain_finish_state_finetune"
    # Set review time 
    increase_review_timestamp

    # Gather statistics for the current gain level
    update_stats_files

    # Check to see if we should adjust the minimum/maximum gain levels
    adjust_minimum_gain_if_required
    adjust_maximum_gain_if_required

    # If current gain is at the minimum gain, then we're done with this stage
    if is_current_gain_min_gain; then

        # Determine the best gain
        best_gain=$(rank_gain_levels)

        # Inform user
        logger "Auto-gain stage '$(cat "$AUTOGAIN_STATE_FILE")' complete. Best gain figure appears to be: $best_gain dB."                            

        # Switch to best gain
        set_readsb_gain "$best_gain"
        
        # Store original stats files for later review
        archive_stats_files

        finish_date="$(date -I)"
        mkdir "/run/autogain/$finish_date" > /dev/null 2>&1
        cp /run/autogain/* "/run/autogain/$finish_date/" > /dev/null 2>&1

        # Initialise next stage
        # echo "$best_gain" > "$AUTOGAIN_MAX_GAIN_VALUE_FILE" # we can leave the max/min, finish doesn't use these
        # echo "$best_gain" > "$AUTOGAIN_MIN_GAIN_VALUE_FILE" # we can leave the max/min, finish doesn't use these
        autogain_change_into_state finished "$AUTOGAIN_FINISHED_PERIOD"
    
    # otherwise, reduce gain if required
    else
        if [[ -n "$1" ]]; then
            rm_previous_and_offset_stats_files
            reduce_gain
        fi
    fi
    logger_debug "Exiting: autogain_finish_state_finetune"
}

##### MAIN SCRIPT #####

# If the user wants to use the autogain system...
if [[ "$READSB_GAIN" == "autogain" ]]; then

    # If autogain is requested, but there is no state file, then initialise everything
    if [[ ! -e "$AUTOGAIN_STATE_FILE" ]]; then

        # If there's no state, then start with the init state

        # If max/min values don't exist from a previous run, set them based on env var
        if [[ ! -e "$AUTOGAIN_MAX_GAIN_VALUE_FILE" ]]; then
            echo "$AUTOGAIN_MAX_GAIN_VALUE" > "$AUTOGAIN_MAX_GAIN_VALUE_FILE"
        fi
        if [[ ! -e "$AUTOGAIN_MIN_GAIN_VALUE_FILE" ]]; then
            echo "$AUTOGAIN_MIN_GAIN_VALUE" > "$AUTOGAIN_MIN_GAIN_VALUE_FILE"
        fi
        autogain_change_into_state init "$AUTOGAIN_INITIAL_PERIOD"

    elif [[ ! -e "$AUTOGAIN_RUNNING_FILE" ]]; then

        # If the container has been restarted, but we were previously running autogain
        # Re-start from current state/gain
        logger "Container restart detected, resuming auto-gain state '$(cat "$AUTOGAIN_STATE_FILE")' with gain $(cat "$AUTOGAIN_CURRENT_VALUE_FILE") dB"
        
        # Update offsets from before container restarted
        update_offsets_after_container_restart

        # Create running file so we can tell if the container has been restarted and we need to resume a previous run...
        touch "$AUTOGAIN_RUNNING_FILE"
        
        if [[ ! "$(cat "$AUTOGAIN_STATE_FILE")" == "finished" ]]; then
            increase_review_timestamp_after_container_restart
        fi

    else

        # determine which state the autogain system is in
        case "$(cat "$AUTOGAIN_STATE_FILE")" in
            init)

                logger_debug "In init state"

                # store current counters in case of container restart
                store_current_counters

                # if it's time to review the current gain setting...
                if review_is_due; then

                    # If stats we require aren't yet available, extend runtime.
                    if ! are_required_stats_available; then
                        logger "Insufficient data available, extending runtime of gain $(cat "$AUTOGAIN_CURRENT_VALUE_FILE") dB."
                        # Set review time 
                        increase_review_timestamp
                    
                    # If stats we require are available, then process.
                    else

                        # Make sure we've received at least 500000 accepted messages:
                        if ! sufficient_local_accepted "$AUTOGAIN_INITIAL_MSGS_ACCEPTED"; then
                            logger "Insufficient messages received for accurate measurement, extending runtime of gain $(cat "$AUTOGAIN_CURRENT_VALUE_FILE") dB."
                            
                            # Set review time 
                            increase_review_timestamp

                            # Limit number of retries to 24 hours
                            if [[ "$(get_current_timestamp)" -gt "$(($(cat "$AUTOGAIN_CURRENT_TIMESTAMP_FILE") + 86400))" ]]; then
                                
                                # Finish init state
                                autogain_finish_gainlevel_init

                            fi
                        
                        else

                            # Finish init state or reduce gain
                            autogain_finish_gainlevel_init reduce
                            
                        fi
                    fi
                    
                # otherwise, do nothing
                else
                    #logger_verbose "Not time to do anything yet..."
                    exit 0
                fi
                ;;

            finetune)

                logger_debug "In finetune state"

                # store current counters in case of container restart
                store_current_counters

                # if it's time to review the current gain setting...
                if review_is_due; then

                    # If stats we require aren't yet available, extend runtime.
                    if ! are_required_stats_available; then
                        logger "Insufficient data available, extending runtime of gain $(cat "$AUTOGAIN_CURRENT_VALUE_FILE") dB."
                        # Set review time 
                        increase_review_timestamp

                    # If stats we require are available, then process.
                    else

                        # Make sure we've received at least 500000 accepted messages:
                        if ! sufficient_local_accepted "$AUTOGAIN_FINETUNE_MSGS_ACCEPTED"; then
                            logger "Insufficient messages received for accurate measurement, extending runtime of gain $(cat "$AUTOGAIN_CURRENT_VALUE_FILE") dB."
                            
                            # Set review time 
                            increase_review_timestamp

                            # Limit number of retries to 2 days
                            if [[ "$(get_current_timestamp)" -gt "$(($(cat "$AUTOGAIN_CURRENT_TIMESTAMP_FILE") + 172800))" ]]; then

                                # Finish finetune state
                                autogain_finish_gainlevel_finetune

                            fi
                        else
                                                
                            # Finish finetune state
                            autogain_finish_gainlevel_finetune reduce
                            
                        fi
                    fi
                    
                # otherwise, do nothing
                else
                    #logger_verbose "Not time to do anything yet..."
                    exit 0
                fi
                ;;

            finished)

                logger_debug "In finished state"

                # Steady state (basically do nothing for a year)

                # if it's time to review the current gain setting...
                if review_is_due; then
                    # re-run autogain process
                    rm "$AUTOGAIN_STATE_FILE"
                fi

                # sleep for a day (unless testing)
                if [[ -z "$AUTOGAIN_TESTING_TIMESTAMP" ]]; then
                    sleep 86400
                fi
                ;;

            *)
                logger "Error, unknown state: $(cat "$AUTOGAIN_STATE_FILE")"
                exit 1
                ;;
        esac
    fi
fi
