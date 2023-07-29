#!/usr/bin/with-contenv bash
#shellcheck shell=bash

# When telegraf supports protobuf input, change to this.
# https://github.com/influxdata/telegraf/pull/3421

if [[ -n "$VERBOSE_LOGGING" ]]; then
    set -x
fi

function get_ip() {
    # $1 = IP(v4) address or hostname
    # -----
    local IP
    if IP=$(echo "$1" | grep -P '^\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}$' 2> /dev/null); then
        :
        if [[ -n "$VERBOSE_LOGGING" ]]; then
            >&2 echo "DEBUG: Already IP"
        fi
    # Attempt to resolve $1 into an IP address with getent
    elif IP=$(getent hosts "$1" 2> /dev/null | cut -d ' ' -f 1 | grep -P '^\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}$'); then
        :
        if [[ -n "$VERBOSE_LOGGING" ]]; then
            >&2 echo "DEBUG: Got IP via getent"
        fi
    # Attempt to resolve $1 into an IP address with s6-dnsip4
    elif IP=$(s6-dnsip4 "$1" 2> /dev/null); then
        :
        if [[ -n "$VERBOSE_LOGGING" ]]; then
            >&2 echo "DEBUG: Got IP via s6-dnsip4"
        fi
    # Catch-all (maybe we were given an IP...)
    else
        if [[ -n "$VERBOSE_LOGGING" ]]; then
            >&2 echo "DEBUG: No host found, assuming IP was given instead of hostname"
        fi
        IP="$1"
    fi
    # Return the IP address
    echo "$IP"
}

function is_tcp_connection_established() {
    # $1 = ip
    # $2 = port
    # -----
    # Define local vars
    local pattern_ip_port
    local pattern
    # Prepare the part of the regex pattern that has the IP and port
    pattern_ip_port=$(echo "$1:$2" | sed 's/\./\\./g')
    # Prepare the remainder of the regex including the IP and port
    pattern="^tcp\s+\d+\s+\d+\s+\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}:\d{1,5}\s+${pattern_ip_port}\s+ESTABLISHED$"
    # Check to see if the connection is established
    if netstat -an | grep -P "$pattern" > /dev/null 2>&1; then
        true
    else
        false
    fi
}

##### MAIN SCRIPT #####

##### Network Connections #####
# If using --net-connector, ensure each net-connector connection is established.
# Only need to do this if networking is enabled
if [[ -n "$READSB_NET_ENABLE" ]]; then
    if [[ -n "$READSB_NET_CONNECTOR" ]]; then
        
        # Loop through each given net-connector
        IFS=';' read -r -a READSB_NET_CONNECTOR_ARRAY <<< "$READSB_NET_CONNECTOR"
        for NET_CONNECTOR_ELEMENT in "${READSB_NET_CONNECTOR_ARRAY[@]}"
        do
            
            # Separate into IP / PORT
            NET_CONNECTOR_ELEMENT_IP=$(get_ip "$(echo "$NET_CONNECTOR_ELEMENT" | cut -d ',' -f 1)")
            NET_CONNECTOR_ELEMENT_PORT=$(echo "$NET_CONNECTOR_ELEMENT" | cut -d ',' -f 2)

            # Is the connection established?
            if is_tcp_connection_established "$NET_CONNECTOR_ELEMENT_IP" "$NET_CONNECTOR_ELEMENT_PORT"; then
                echo "net-connector to $NET_CONNECTOR_ELEMENT_IP:$NET_CONNECTOR_ELEMENT_PORT established OK: HEALTHY"
            else
                echo "net-connector to $NET_CONNECTOR_ELEMENT_IP:$NET_CONNECTOR_ELEMENT_PORT not established: UNHEALTHY"
                exit 1
            fi
        done
    fi
fi
# If InfluxDB 
if [[ -n "$INFLUXDBURL" ]]; then
    INFLUXDB_HOST=$(echo "$INFLUXDBURL" | sed -rn 's;https{0,1}:\/\/(.*):([[:digit:]]+).*$;\1;p')
    INFLUXDB_PORT=$(echo "$INFLUXDBURL" | sed -rn 's;https{0,1}:\/\/(.*):([[:digit:]]+).*$;\2;p')
    INFLUXDB_IP=$(get_ip "$INFLUXDB_HOST")
    # Is the connection established?
    if is_tcp_connection_established "$INFLUXDB_IP" "$INFLUXDB_PORT"; then
        echo "InfluxDB connection to $INFLUXDB_IP:$INFLUXDB_PORT established OK: HEALTHY"
    else
        echo "InfluxDB connection to $INFLUXDB_IP:$INFLUXDB_PORT not established: UNHEALTHY"
        exit 1
    fi
fi

##### SDR #####
# If using --device-type=*, ensure local messages are being received/accepted.
# Only need to do this if a local radio is attached
if [[ -n "$READSB_DEVICE_TYPE" ]]; then
    case $READSB_DEVICE_TYPE in
        rtlsdr | bladerf | modesbeast | gnshulc | plutosdr)
        returnvalue=$(protoc \
            --proto_path="$READSB_PROTO_PATH" \
            --decode Statistics \
            readsb.proto < "$READSB_STATS_PB_FILE" | \
            # Just get the last_15min section
            grep -A 999 --max-count=1 "last_15min {" | \
            grep -B 999 --max-count=1 '}' | \
            # Remove the section wrappers
            grep -v '{' | \
            grep -v '}' | \
            # Delete whitespace
            tr -d ' ' | \
            # Grep for the key we're looking for
            grep "local_accepted" | \
            # Return the value only
            cut -d ':' -f 2)
        # Log healthy/unhealthy and exit abnormally if unhealthy
        if [[ $(echo "$returnvalue > 0" | bc -l) -eq 1 ]]; then
            echo "last_15min:local_accepted is $returnvalue: HEALTHY"
        else
            echo "last_15min:local_accepted is 0: UNHEALTHY"
            exit 1
        fi
        ;;
    esac
fi

##### Service Death Counts #####
services=('autogain' 'collectd' 'graphs_1h-24h' 'graphs_7d-1y' 'lighttpd')
services+=('readsb' 'readsbrrd' 'telegraf_socat_vrs_json' 'telegraf')
# For each service...
for service in "${services[@]}"; do
    # Get number of non-zero service exits
    returnvalue=$(s6-svdt \
                    -s "/run/s6/services/$service" | \
                    grep -cv 'exitcode 0')
    # Reset service death counts
    s6-svdt-clear "/run/s6/services/$service"
    # Log healthy/unhealthy and exit abnormally if unhealthy
    if [[ "$returnvalue" -eq "0" ]]; then
        echo "abnormal death count for service $service is $returnvalue: HEALTHY"
    else
        echo "abnormal death count for service $service is $returnvalue: UNHEALTHY"
        exit 1
    fi
done

exit 0
