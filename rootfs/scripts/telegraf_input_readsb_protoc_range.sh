#!/usr/bin/with-contenv bash
# shellcheck shell=bash

# Get stats from protoc
# Write to file so we don't have to run protoc many times
protoc --proto_path="$READSB_PROTO_PATH" --decode Statistics readsb.proto < "$READSB_STATS_PB_FILE" > /tmp/.protoc_readsb_range_out

# Turn stats we care about (last_1min) into array

mapfile -t stats_from_protoc < <( \
  grep -A 999 'polar_range {' /tmp/.protoc_readsb_range_out | \
  grep -B 999 '}' | \
  grep -v '{' | \
  grep -v '}' | \
  tr -d " ")

declare -A range
bearing=0
for stat in "${stats_from_protoc[@]}"; do
  key=$(echo "$stat" | cut -d ':' -f 1)
  value=$(echo "$stat" | cut -d ':' -f 2)

  if [[ "$key" == "key" ]]; then
    bearing="$value"
    range[$bearing]=0
  elif [[ "$key" == "value" ]]; then
    range[$bearing]="$value"
  else
    continue
  fi

done

# Prepare timestamp - add timestamp
#                         ms   μs   ns
timestamp="$(($(date +%s)*1000*1000*1000))"

# Prepare output - add ranges
for key in "${!range[@]}"; do

  # Prepare output - add measurement
  output="polar_range,bearing=$(printf "%.2d " "$key") range=${range[$key]} $timestamp"
  
  echo "$output"
done
