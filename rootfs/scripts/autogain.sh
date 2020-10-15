#!/usr/bin/with-contenv bash
# shellcheck shell=bash

# temp for troubleshooting
set -x

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
# update interval
AUTOGAIN_INTERVAL_FILE="/run/autogain/autogain_interval"
# results for init stage
AUTOGAIN_RESULTS_FILE="/run/autogain/autogain_results"

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

function increase_review_timestamp() {
    logger_debug "Entering: increase_review_timestamp"
    # Set review time 
    local new_timestamp
    new_timestamp="$(($(date +%s) + $(cat "$AUTOGAIN_INTERVAL_FILE")))"
    logger_debug "Setting review timestamp to: $new_timestamp"
    echo "$new_timestamp" > "$AUTOGAIN_REVIEW_TIMESTAMP_FILE"
    logger_debug "Exiting: increase_review_timestamp"
}

function review_is_due() {
    logger_debug "Entering: review_is_due"
    # Check if it is time to review
    if [[ "$(date +%s)" -ge "$(cat "$AUTOGAIN_REVIEW_TIMESTAMP_FILE")" ]]; then
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
    if [[ "$(get_readsb_stat total local_accepted)" -ge "$1" ]]; then
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

    # Restart readsb
    logger_verbose "Restarting readsb"
    pkill -ef "/usr/local/bin/readsb " > /dev/null 2>&1

    # Store timestamp gain was updated
    date +%s > "$AUTOGAIN_CURRENT_TIMESTAMP_FILE"
    logger_debug "Exiting: set_readsb_gain"
}

function get_readsb_stat() {
    # Pull a statistic from readsb's stats.pb file
    # $1 = section ('total', 'latest', 'last_1min', etc - from protobuf .proto)
    # $2 = key (from latest)
    # -----
    logger_debug "Entering: get_readsb_stat"
    # Get latest section from protobuf, get line including the key we're after:
    local returnvalue
    returnvalue=$(protoc \
            --proto_path="$READSB_PROTO_PATH" \
            --decode Statistics \
            readsb.proto < "$READSB_STATS_PB_FILE" | \
        # Just get the latest section
        grep -A 999 --max-count=1 "$1 {" | \
        grep -B 999 --max-count=1 '}' | \
        # Remove the section wrappers
        grep -v '{' | \
        grep -v '}' | \
        # Delete whitespace
        tr -d ' ' | \
        # Grep for the key we're looking for
        grep "$2" | \
        # Return the value only
        cut -d ':' -f 2)

    logger_debug "readsb stat $1:$2 = $returnvalue"

    if [[ -z "$returnvalue" ]]; then
        logger_verbose "Error looking up $1:$2 from readsb stats!"
        return 1
    fi

    echo "$returnvalue"
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

function get_pct_strong_signals() {
    # Return the percentage of "strong signals"
    # -----
    logger_debug "Entering: get_pct_strong_signals"
    local local_strong_signals
    local local_accepted
    local pct_strong_signals
    if ! local_strong_signals=$(get_readsb_stat total local_strong_signals); then
        logger_debug "No 'local_strong_signals' measurement! Setting to 0."
        local_strong_signals=0
    fi
    local_accepted=$(get_readsb_stat total local_accepted)
    pct_strong_signals="$(echo "scale=2; ($local_strong_signals / $local_accepted) * 100" | bc -l)"
    logger_debug "Percentage of strong signals: $pct_strong_signals"
    echo "$pct_strong_signals"
    logger_debug "Exiting: get_pct_strong_signals"
}

function get_snr() {
    # Return the signal to noise ratio (local_signal - local_noise)
    # -----
    logger_debug "Entering: get_snr"
    local local_signal
    local local_noise
    local_signal=$(get_readsb_stat total local_signal)
    local_noise=$(get_readsb_stat total local_noise)
    echo "$local_signal - $local_noise" | bc -l
    logger_debug "Exiting: get_snr"
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
    logger_debug "Exiting: rm_stats_files"
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
    date +%s > "$AUTOGAIN_CURRENT_TIMESTAMP_FILE"

    # Store interval
    echo "$2" > "$AUTOGAIN_INTERVAL_FILE"

    # Set review time for now + $2 (seconds until next check)
    echo $(($(date +%s) + $2)) > "$AUTOGAIN_REVIEW_TIMESTAMP_FILE"

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

function gather_statistics () {
    # Gather statistics from readsb into stats files
    # -----

    logger_debug "Entering: gather_statistics"

    # Write statistics for this gain level

    # longest range (max_distance_in_metres)
    echo "$(cat "$AUTOGAIN_CURRENT_VALUE_FILE") $(get_readsb_stat total max_distance_in_metres)" >> "$AUTOGAIN_STATS_MAX_DISTANCE_FILE"
    
    # percentage strong messages (local_strong_signals/local_samples_processed)
    echo "$(cat "$AUTOGAIN_CURRENT_VALUE_FILE") $(get_pct_strong_signals)" >> "$AUTOGAIN_STATS_PERCENT_STRONG_MSGS_FILE"

    # largest number of received messages (local_accepted)
    echo "$(cat "$AUTOGAIN_CURRENT_VALUE_FILE") $(get_readsb_stat total local_accepted)" >> "$AUTOGAIN_STATS_TOTAL_ACCEPTED_MSGS_FILE"

    # best SNR (local_signal - local_noise)
    echo "$(cat "$AUTOGAIN_CURRENT_VALUE_FILE") $(get_snr)" >> "$AUTOGAIN_STATS_SNR_FILE"

    logger_debug "Exiting: gather_statistics"   
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

    # Find longest range
    # +1 point for longest range (max_distance_in_metres)
    # Only one point as this isn't always a reliable indicator
    local max_value
    local max_value_gain
    max_value=0
    max_value_gain=0
    while read -r line; do
        gain_level=$(echo "$line" | cut -d ' ' -f 1)
        value=$(echo "$line" | cut -d ' ' -f 2)
        bc_expression="$value > $max_value"
        if [[ $(echo "$bc_expression" | bc -l) -eq 1 ]]; then
            max_value=$value
            max_value_gain=$gain_level
        fi
    done < "$AUTOGAIN_STATS_MAX_DISTANCE_FILE"
    gain_rank[$max_value_gain]=$((gain_rank[$max_value_gain] + 1))

    # -2 points for percentage strong messages less than AUTOGAIN_PERCENT_STRONG_MESSAGES_MIN (local_strong_signals/local_samples_processed)
    while read -r line; do
        gain_level=$(echo "$line" | cut -d ' ' -f 1)
        value=$(echo "$line" | cut -d ' ' -f 2)
        bc_expression="$value < $AUTOGAIN_PERCENT_STRONG_MESSAGES_MIN"
        if [[ $(echo "$bc_expression" | bc -l) -eq 1 ]]; then
            gain_rank[$gain_level]=$((gain_rank[$gain_level] - 1))
        fi
    done < "$AUTOGAIN_STATS_PERCENT_STRONG_MSGS_FILE"

    # -2 points for percentage strong messages greater than AUTOGAIN_PERCENT_STRONG_MESSAGES_MAX (local_strong_signals/local_samples_processed)
    while read -r line; do
        gain_level=$(echo "$line" | cut -d ' ' -f 1)
        value=$(echo "$line" | cut -d ' ' -f 2)
        bc_expression="$value > $AUTOGAIN_PERCENT_STRONG_MESSAGES_MAX"
        if [[ $(echo "$bc_expression" | bc -l) -eq 1 ]]; then
            gain_rank[$gain_level]=$((gain_rank[$gain_level] - 1))
        fi
    done < "$AUTOGAIN_STATS_PERCENT_STRONG_MSGS_FILE"

    # +2 points for percentage strong messages between AUTOGAIN_PERCENT_STRONG_MESSAGES_MIN & AUTOGAIN_PERCENT_STRONG_MESSAGES_MAX (local_strong_signals/local_samples_processed)
    while read -r line; do
        gain_level=$(echo "$line" | cut -d ' ' -f 1)
        value=$(echo "$line" | cut -d ' ' -f 2)
        bc_expression="$value < $AUTOGAIN_PERCENT_STRONG_MESSAGES_MAX"
        if [[ $(echo "$bc_expression" | bc -l) -eq 1 ]]; then
            bc_expression="$value > $AUTOGAIN_PERCENT_STRONG_MESSAGES_MIN"
            if [[ $(echo "$bc_expression" | bc -l) -eq 1 ]]; then
                gain_rank[$gain_level]=$((gain_rank[$gain_level] + 2))
            fi
        fi
    done < "$AUTOGAIN_STATS_PERCENT_STRONG_MSGS_FILE"

    # +1 point for largest number of received messages (local_accepted)
    # Only one point as this isn't always a reliable indicator
    max_value=0
    max_value_gain=0
    while read -r line; do
        gain_level=$(echo "$line" | cut -d ' ' -f 1)
        value=$(echo "$line" | cut -d ' ' -f 2)
        bc_expression="$value > $max_value"
        if [[ $(echo "$bc_expression" | bc -l) -eq 1 ]]; then
            max_value="$value"
            max_value_gain="$gain_level"
        fi
    done < "$AUTOGAIN_STATS_TOTAL_ACCEPTED_MSGS_FILE"
    gain_rank[$max_value_gain]=$((gain_rank[$max_value_gain] + 1))

    # +2 point for best SNR (local_signal - local_noise)
    max_value=0
    max_value_gain=0
    while read -r line; do
        gain_level=$(echo "$line" | cut -d ' ' -f 1)
        value=$(echo "$line" | cut -d ' ' -f 2)
        bc_expression="$value > $max_value"
        if [[ $(echo "$bc_expression" | bc -l) -eq 1 ]]; then
            max_value=$value
            max_value_gain=$gain_level
        fi
    done < "$AUTOGAIN_STATS_SNR_FILE"
    gain_rank[$max_value_gain]=$((gain_rank[$max_value_gain] + 1))

    # Write out results file
    for gain_level in "${!gain_rank[@]}"; do
        echo "$gain_level:${gain_rank[$gain_level]}" > "/tmp/.autogain_results"
    done
    sort -n "/tmp/.autogain_results" > "$AUTOGAIN_RESULTS_FILE.$(cat "$AUTOGAIN_STATE_FILE")"
    rm "/tmp/.autogain_results"

    # Pick the best gain
    local best_gain_level_points
    local best_gain_level_value
    best_gain_level_points=-100
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
            fi
        else
            # Gain levels in this block are above max strong messages
            count_below_min=0
            logger_debug "adjust_minimum_gain_if_required: Found gain level with % strong messages above max at gain level $gain_level dB"
        fi                            
    done < "$AUTOGAIN_STATS_PERCENT_STRONG_MSGS_FILE"
    # If we've seen two consecutive "below minimums" after the "good" region, we've most likely gone past the "good" region.
    # Bring up the minimum gain
    if [[ "$count_below_min" -gt "2" ]]; then
        logger_verbose "Bringing up minimum gain level to: $(cat "$AUTOGAIN_CURRENT_VALUE_FILE") dB"
        cp "$AUTOGAIN_CURRENT_VALUE_FILE" "$AUTOGAIN_MIN_GAIN_VALUE_FILE"
    fi
    logger_debug "Exiting: adjust_minimum_gain_if_required"
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

##### MAIN SCRIPT #####

# If the user wants to use the autogain system...
if [[ "$READSB_GAIN" == "autogain" ]]; then

    # If autogain is requested, but there is no state file, then initialise everything
    if [[ ! -e "$AUTOGAIN_STATE_FILE" ]]; then

        # If there's no state, then initialise with the first state (2 hours)
        echo "$AUTOGAIN_MAX_GAIN_VALUE" > "$AUTOGAIN_MAX_GAIN_VALUE_FILE"
        echo "$AUTOGAIN_MIN_GAIN_VALUE" > "$AUTOGAIN_MIN_GAIN_VALUE_FILE"
        autogain_change_into_state init "$AUTOGAIN_INITIAL_PERIOD"

    elif [[ ! -e "$AUTOGAIN_RUNNING_FILE" ]]; then

        # If the container has been restarted, but we were previously running autogain
        # Re-start from current state/gain
        logger "Container restart detected, resuming auto-gain state '$(cat "$AUTOGAIN_STATE_FILE")' with gain $(cat "$AUTOGAIN_CURRENT_VALUE_FILE") dB"
        
        # Create running file so we can tell if the container has been restarted and we need to resume a previous run...
        touch "$AUTOGAIN_RUNNING_FILE"
        
        if [[ ! "$(cat "$AUTOGAIN_STATE_FILE")" == "finished" ]]; then
            increase_review_timestamp
        fi

    else

        # determine which state the autogain system is in
        case "$(cat "$AUTOGAIN_STATE_FILE")" in
            init)

                logger_debug "In init state"

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
                            if [[ "$(date +%s)" -gt "$(($(cat "$AUTOGAIN_CURRENT_TIMESTAMP_FILE") + 86400))" ]]; then

                                # Set review time 
                                increase_review_timestamp

                                # Gather statistics for the current gain level
                                gather_statistics

                                # Check to see if we should adjust the minimum gain
                                adjust_minimum_gain_if_required

                                # If current gain is at the minimum gain, then we're done with this stage
                                if is_current_gain_min_gain; then

                                    # Determine the best gain
                                    best_gain=$(rank_gain_levels)

                                    # Inform user
                                    logger "Auto-gain stage '$(cat "$AUTOGAIN_STATE_FILE")' complete. Best gain figure appears to be: $best_gain dB."                            

                                    # Try values sandwiching the best gain
                                    best_gain_number=$(get_gain_number "$best_gain")
                                    upper_gain_number=$((best_gain_number + 3))
                                    lower_gain_number=$((best_gain_number - 3))
                                    if [[ $upper_gain_number -gt $((${#gain_levels[@]}-1)) ]]; then
                                        upper_gain_number=$((${#gain_levels[@]}-1))
                                    fi
                                    if [[ $lower_gain_number -lt 0 ]]; then
                                        lower_gain_number=0
                                    fi
                                    echo "${gain_levels[$upper_gain_number]}" > "$AUTOGAIN_MAX_GAIN_VALUE_FILE"
                                    echo "${gain_levels[$lower_gain_number]}" > "$AUTOGAIN_MIN_GAIN_VALUE_FILE"

                                    # Store original stats files for later review
                                    cp "$AUTOGAIN_STATS_MAX_DISTANCE_FILE" "$AUTOGAIN_STATS_MAX_DISTANCE_FILE.$(cat "$AUTOGAIN_STATE_FILE")"
                                    cp "$AUTOGAIN_STATS_PERCENT_STRONG_MSGS_FILE" "$AUTOGAIN_STATS_PERCENT_STRONG_MSGS_FILE.$(cat "$AUTOGAIN_STATE_FILE")"
                                    cp "$AUTOGAIN_STATS_TOTAL_ACCEPTED_MSGS_FILE" "$AUTOGAIN_STATS_TOTAL_ACCEPTED_MSGS_FILE.$(cat "$AUTOGAIN_STATE_FILE")"
                                    cp "$AUTOGAIN_STATS_SNR_FILE" "$AUTOGAIN_STATS_SNR_FILE.$(cat "$AUTOGAIN_STATE_FILE")"

                                    # Initialise next stage
                                    autogain_change_into_state finetune "$AUTOGAIN_FINETUNE_PERIOD"

                                fi
                            fi
                        
                        else

                            # Set review time 
                            increase_review_timestamp

                            # Gather statistics for the current gain level
                            gather_statistics

                            # Check to see if we should adjust the minimum gain
                            adjust_minimum_gain_if_required

                            # If current gain is at the minimum gain, then we're done with this stage
                            if is_current_gain_min_gain; then

                                # Determine the best gain
                                best_gain=$(rank_gain_levels)

                                # Inform user
                                logger "Auto-gain stage '$(cat "$AUTOGAIN_STATE_FILE")' complete. Best gain figure appears to be: $best_gain dB."                            

                                # Try values sandwiching the best gain
                                best_gain_number=$(get_gain_number "$best_gain")
                                upper_gain_number=$((best_gain_number + 3))
                                lower_gain_number=$((best_gain_number - 3))
                                if [[ $upper_gain_number -gt $((${#gain_levels[@]}-1)) ]]; then
                                    upper_gain_number=$((${#gain_levels[@]}-1))
                                fi
                                if [[ $lower_gain_number -lt 0 ]]; then
                                    lower_gain_number=0
                                fi
                                echo "${gain_levels[$upper_gain_number]}" > "$AUTOGAIN_MAX_GAIN_VALUE_FILE"
                                echo "${gain_levels[$lower_gain_number]}" > "$AUTOGAIN_MIN_GAIN_VALUE_FILE"

                                # Store original stats files for later review
                                cp "$AUTOGAIN_STATS_MAX_DISTANCE_FILE" "$AUTOGAIN_STATS_MAX_DISTANCE_FILE.$(cat "$AUTOGAIN_STATE_FILE")"
                                cp "$AUTOGAIN_STATS_PERCENT_STRONG_MSGS_FILE" "$AUTOGAIN_STATS_PERCENT_STRONG_MSGS_FILE.$(cat "$AUTOGAIN_STATE_FILE")"
                                cp "$AUTOGAIN_STATS_TOTAL_ACCEPTED_MSGS_FILE" "$AUTOGAIN_STATS_TOTAL_ACCEPTED_MSGS_FILE.$(cat "$AUTOGAIN_STATE_FILE")"
                                cp "$AUTOGAIN_STATS_SNR_FILE" "$AUTOGAIN_STATS_SNR_FILE.$(cat "$AUTOGAIN_STATE_FILE")"

                                # Initialise next stage
                                autogain_change_into_state finetune "$AUTOGAIN_FINETUNE_PERIOD"
                            
                            # otherwise, reduce gain
                            else
                                reduce_gain

                            fi
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

                            # Limit number of retries to 24 hours
                            if [[ "$(date +%s)" -gt "$((AUTOGAIN_CURRENT_TIMESTAMP_FILE + 172800))" ]]; then

                                # Set review time 
                                increase_review_timestamp

                                # Gather statistics for the current gain level
                                gather_statistics

                                # Check to see if we should adjust the minimum gain
                                adjust_minimum_gain_if_required

                                # If current gain is at the minimum gain, then we're done with this stage
                                if is_current_gain_min_gain; then

                                    # Determine the best gain
                                    best_gain=$(rank_gain_levels)

                                    # Inform user
                                    logger "Auto-gain stage '$(cat "$AUTOGAIN_STATE_FILE")' complete. Best gain figure appears to be: $best_gain dB."                            

                                    # Switch to best gain
                                    set_readsb_gain "$best_gain"
                                    
                                    # Store original stats files for later review
                                    cp "$AUTOGAIN_STATS_MAX_DISTANCE_FILE" "$AUTOGAIN_STATS_MAX_DISTANCE_FILE.$(cat "$AUTOGAIN_STATE_FILE")"
                                    cp "$AUTOGAIN_STATS_PERCENT_STRONG_MSGS_FILE" "$AUTOGAIN_STATS_PERCENT_STRONG_MSGS_FILE.$(cat "$AUTOGAIN_STATE_FILE")"
                                    cp "$AUTOGAIN_STATS_TOTAL_ACCEPTED_MSGS_FILE" "$AUTOGAIN_STATS_TOTAL_ACCEPTED_MSGS_FILE.$(cat "$AUTOGAIN_STATE_FILE")"
                                    cp "$AUTOGAIN_STATS_SNR_FILE" "$AUTOGAIN_STATS_SNR_FILE.$(cat "$AUTOGAIN_STATE_FILE")"

                                    # Initialise next stage
                                    echo "$best_gain" > "$AUTOGAIN_MAX_GAIN_VALUE_FILE"
                                    echo "$best_gain" > "$AUTOGAIN_MIN_GAIN_VALUE_FILE"
                                    autogain_change_into_state finished "$AUTOGAIN_FINISHED_PERIOD"

                                    # TODO set while testing
                                    echo "finish" > "$AUTOGAIN_STATE_FILE"
                                fi
                            fi
                        else
                                                
                            # Set review time 
                            increase_review_timestamp

                            # Gather statistics for the current gain level
                            gather_statistics

                            # Check to see if we should adjust the minimum gain
                            adjust_minimum_gain_if_required

                            # If current gain is at the minimum gain, then we're done with this stage
                            if is_current_gain_min_gain; then

                                # Determine the best gain
                                best_gain=$(rank_gain_levels)

                                # Inform user
                                logger "Auto-gain stage '$(cat "$AUTOGAIN_STATE_FILE")' complete. Best gain figure appears to be: $best_gain dB."                            

                                # Switch to best gain
                                set_readsb_gain "$best_gain"

                                # Store original stats files for later review
                                cp "$AUTOGAIN_STATS_MAX_DISTANCE_FILE" "$AUTOGAIN_STATS_MAX_DISTANCE_FILE.$(cat "$AUTOGAIN_STATE_FILE")"
                                cp "$AUTOGAIN_STATS_PERCENT_STRONG_MSGS_FILE" "$AUTOGAIN_STATS_PERCENT_STRONG_MSGS_FILE.$(cat "$AUTOGAIN_STATE_FILE")"
                                cp "$AUTOGAIN_STATS_TOTAL_ACCEPTED_MSGS_FILE" "$AUTOGAIN_STATS_TOTAL_ACCEPTED_MSGS_FILE.$(cat "$AUTOGAIN_STATE_FILE")"
                                cp "$AUTOGAIN_STATS_SNR_FILE" "$AUTOGAIN_STATS_SNR_FILE.$(cat "$AUTOGAIN_STATE_FILE")"
                                
                                # Initialise next stage
                                echo "$best_gain" > "$AUTOGAIN_MAX_GAIN_VALUE_FILE"
                                echo "$best_gain" > "$AUTOGAIN_MIN_GAIN_VALUE_FILE"
                                autogain_change_into_state finished "$AUTOGAIN_FINISHED_PERIOD"

                                # TODO set while testing
                                echo "finish" > "$AUTOGAIN_STATE_FILE"
                            
                            # otherwise, reduce gain
                            else
                                reduce_gain

                            fi
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
                sleep 86400
                ;;

            *)
                logger "Error, unknown state: $(cat "$AUTOGAIN_STATE_FILE")"
                exit 1
                ;;
        esac
    fi
fi
