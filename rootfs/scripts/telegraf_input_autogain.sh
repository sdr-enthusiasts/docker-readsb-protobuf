#!/command/with-contenv bash
# shellcheck shell=bash

# For each item in array
field_set=()
field_set+=("autogain_current_value=$(cat "$AUTOGAIN_CURRENT_VALUE_FILE")")
field_set+=("autogain_max_value=$(cat "$AUTOGAIN_MAX_GAIN_VALUE_FILE")")
field_set+=("autogain_min_value=$(cat "$AUTOGAIN_MIN_GAIN_VALUE_FILE")")
field_set+=("autogain_pct_strong_messages_max=$AUTOGAIN_PERCENT_STRONG_MESSAGES_MAX")
field_set+=("autogain_pct_strong_messages_min=$AUTOGAIN_PERCENT_STRONG_MESSAGES_MIN")

# Prepare output - add measurement
output="autogain "

# Prepare output - add fields
first=1
count=0
for field in "${field_set[@]}"; do
  if [[ "$first" -eq "1" ]]; then
    first=0
  else
    output+=","
  fi
  output+="$field"
  count=$((count+1))
done

# Prepare output - add timestamp
#                        ms   μs   ns
output+=" $(($(date +%s)*1000*1000*1000))"

# Echo output
if [[ "$count" -ge "1" ]]; then
  echo "$output"
fi
