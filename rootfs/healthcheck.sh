#!/usr/bin/with-contenv bash
#shellcheck shell=bash

if [[ -n "$VERBOSE_LOGGING" ]]; then
    set -x
fi

function get_ip() {
    # $1 = IP(v4) address or hostname
    # -----
    local IP
    # Attempt to resolve $1 into an IP address with getent
    if IP=$(getent hosts "$1" 2> /dev/null | cut -d ' ' -f 1); then
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
            >&2 echo "DEBIG: No host found, assuming IP was given instead of hostname"
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
                echo "net-connector to $NET_CONNECTOR_ELEMENT_IP:$NET_CONNECTOR_ELEMENT_PORT established OK"
            else
                echo "net-connector to $NET_CONNECTOR_ELEMENT_IP:$NET_CONNECTOR_ELEMENT_PORT not established"
                exit 1
            fi
        done
    fi
fi

exit 0