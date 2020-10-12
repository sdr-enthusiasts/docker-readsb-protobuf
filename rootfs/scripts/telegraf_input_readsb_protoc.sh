#!/usr/bin/with-contenv bash
# shellcheck shell=bash

# Get stats from protoc
# Write to file so we don't have to run protoc many times
protoc --proto_path="$READSB_PROTO_PATH" --decode Statistics readsb.proto < "$READSB_STATS_PB_FILE" > /tmp/.protoc_readsb_out

# Turn stats we care about (last_1min) into array
stats_from_protoc=($(grep -m 1 -A 999 'last_1min' /tmp/.protoc_readsb_out | \
                     grep -m 1 -B 999 '}' | \
                     grep -v '{' | \
                     grep -v '}' | \
                     tr -d " "))

# For each item in array
field_set=()
for stat in "${stats_from_protoc[@]}"; do
  key=$(echo "$stat" | cut -d ':' -f 1)
  value=$(echo "$stat" | cut -d ':' -f 2)
  case "$key" in

    start)
    # do nothing, we don't need this value
    ;;

    stop)
    # this value will become the timestamp
    timestamp="$value"
    ;;

    *)
    # everything else
    field_set+=("$key=$value")
    ;;

  esac
done

# Prepare output - add measurement
output="readsb "

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
output+=" $((timestamp*1000*1000*1000))"

# Echo output
if [[ "$count" -ge "1" ]]; then
  echo "$output"
fi
