# Declare the telegraf image so we can copy telegraf binary out of it,
# and avoid headache of having to add apt key / apt repo and/or build from src.
FROM telegraf AS telegraf
RUN touch /tmp/.nothing

# Build final image
FROM ghcr.io/sdr-enthusiasts/docker-baseimage:readsb-full

# Copy telegraf
COPY --from=telegraf /usr/bin/telegraf /usr/bin/telegraf

ENV S6_BEHAVIOUR_IF_STAGE2_FAILS=2 \
    ###########################################################################
    ##### READSBRRD ENVIRONMENT VARS #####
    READSBRRD_STEP=60 \
    ###########################################################################
    ##### READSB GRAPH ENVIRONMENT VARS #####
    READSB_GRAPH_SIZE="default" \
    READSB_GRAPH_ALL_LARGE="no" \
    READSB_GRAPH_FONT_SIZE=10.0 \
    READSB_GRAPH_MAX_MESSAGES_LINE=0 \
    READSB_GRAPH_LARGE_WIDTH=1096 \
    READSB_GRAPH_LARGE_HEIGHT=235 \
    READSB_GRAPH_SMALL_WIDTH=619 \
    READSB_GRAPH_SMALL_HEIGHT=324 \
    ###########################################################################
    ##### AUTOGAIN ENVIRONMENT VARS #####
    # How often the autogain.sh is run (in seconds)
    AUTOGAIN_SERVICE_PERIOD=900 \
    # The autogain state file (init/finetune/finish)
    AUTOGAIN_STATE_FILE="/run/autogain/state" \
    # The current gain figure as-set by autogain
    AUTOGAIN_CURRENT_VALUE_FILE="/run/autogain/autogain_current_value" \
    # The timestamp (seconds since epoch) when the current gain figure was set
    AUTOGAIN_CURRENT_TIMESTAMP_FILE="/run/autogain/autogain_current_timestamp" \
    # The timestamp (seconds since epoch) when the current gain figure should be reviewed
    AUTOGAIN_REVIEW_TIMESTAMP_FILE="/run/autogain/autogain_review_timestamp" \
    # The maximum allowable percentage of strong messages
    AUTOGAIN_PERCENT_STRONG_MESSAGES_MAX=10.0 \
    # The minimum allowable percentage of strong messages
    AUTOGAIN_PERCENT_STRONG_MESSAGES_MIN=0.5 \
    # The number of seconds that autogain "init" stage should run for, for each gain level
    AUTOGAIN_INITIAL_PERIOD=7200 \
    # The minimum number of local_accepted messages that autogain "init" stage should run for, for each gain level
    AUTOGAIN_INITIAL_MSGS_ACCEPTED=1000000 \
    # The number of seconds that autogain "finetune" stage should run for, for each gain level
    AUTOGAIN_FINETUNE_PERIOD=604800 \
    # The minimum number of local_accepted messages that autogain "finetune" stage should run for, for each gain level
    AUTOGAIN_FINETUNE_MSGS_ACCEPTED=7000000 \
    # How long to run once finetune stage has finished before we start the process over (1 year)
    AUTOGAIN_FINISHED_PERIOD=31536000 \
    # Maximum gain level that autogain should use
    AUTOGAIN_MAX_GAIN_VALUE=49.6 \
    # Minimum gain level that autogain should use
    AUTOGAIN_MIN_GAIN_VALUE=0.0 \
    # State file that will disappear when the container is rebuilt/restarted - so autogain can detect container restart/rebuild
    AUTOGAIN_RUNNING_FILE="/tmp/.autogain_running" \
    # maximum accepted gain value
    AUTOGAIN_MAX_GAIN_VALUE_FILE="/run/autogain/autogain_max_value" \
    # minimum accepted gain value
    AUTOGAIN_MIN_GAIN_VALUE_FILE="/run/autogain/autogain_min_value" \
    ###########################################################################
    # Protobuf data from readsb
    READSB_STATS_PB_FILE="/run/readsb/stats.pb" \
    # Protobuf definition
    READSB_PROTO_PATH="/opt/readsb-protobuf" \
    # Current gain value
    GAIN_VALUE_FILE="/tmp/.gain_current" \
    ###########################################################################
    # default BEAST out port
    READSB_NET_BEAST_OUTPUT_PORT=30005 \
    # default BaseStation out port
    READSB_NET_SBS_OUTPUT_PORT=30003 \
    # default RAW out put
    READSB_NET_RAW_OUTPUT_PORT=30002 \
    ###########################################################################
    PROMETHEUSPORT=9273 \
    PROMETHEUSPATH="/metrics"

SHELL ["/bin/bash", "-o", "pipefail", "-c"]

# Copy container filesystem
COPY rootfs/ /

RUN set -x && \
    TEMP_PACKAGES=() && \
    KEPT_PACKAGES=() && \
    # Required for automatic gain script (to interpret .pb files).
    KEPT_PACKAGES+=(protobuf-compiler) && \
    # Required for downloading stuff & readsb database updates
    KEPT_PACKAGES+=(git) && \
    # Required for building multiple packages.
    TEMP_PACKAGES+=(build-essential) && \
    TEMP_PACKAGES+=(pkg-config) && \
    TEMP_PACKAGES+=(cmake) && \
    TEMP_PACKAGES+=(autoconf) && \
    TEMP_PACKAGES+=(automake) && \
    # Packages for readsb web interface & graphs.
    KEPT_PACKAGES+=(lighttpd) && \
    KEPT_PACKAGES+=(lighttpd-mod-magnet) && \
    KEPT_PACKAGES+=(collectd-core) && \
    KEPT_PACKAGES+=(rrdtool) && \
    KEPT_PACKAGES+=(jq) && \
    # Packages for telegraf
    TEMP_PACKAGES+=(apt-transport-https) && \
    KEPT_PACKAGES+=(socat) && \
    TEMP_PACKAGES+=(gnupg) && \
    # Requirements for kalibrate-rtl
    TEMP_PACKAGES+=(libtool) && \
    KEPT_PACKAGES+=(libfftw3-3) && \
    TEMP_PACKAGES+=(libfftw3-dev) && \
    TEMP_PACKAGES+=(libusb-1.0-0-dev) && \
    # Install packages.
    apt-get update && \
    apt-get install -o Dpkg::Options::="--force-confold" --force-yes -y --no-install-recommends \
        ${KEPT_PACKAGES[@]} \
        ${TEMP_PACKAGES[@]} \
        && \
    git config --global advice.detachedHead false && \
    # Build & install kalibrate-rtl
    # See: https://discussions.flightaware.com/t/setting-frequency-offset-or-exact-frequency-ppm/15812/6
    git clone https://github.com/steve-m/kalibrate-rtl.git "/src/kalibrate-rtl" && \
    pushd "/src/kalibrate-rtl" && \
    echo "kalibrate-rtl $(git log | head -1 | tr -s ' ' '_')" >> /VERSIONS && \
    ./bootstrap && \
    ./configure && \
    make all install && \
    popd && \
    # readsb - Deploy webapp.
    ln -s /etc/lighttpd/conf-available/01-setenv.conf /etc/lighttpd/conf-enabled/01-setenv.conf && \
    ln -s /etc/lighttpd/conf-available/87-cachebust.conf /etc/lighttpd/conf-enabled/87-cachebust.conf && \
    ln -s /etc/lighttpd/conf-available/89-readsb.conf /etc/lighttpd/conf-enabled/89-readsb.conf && \
    ln -s /etc/lighttpd/conf-available/88-readsb-statcache.conf /etc/lighttpd/conf-enabled/88-readsb-statcache.conf && \
    # Healthcheck stuff
    mkdir -p /etc/lighttpd/lua && \
    echo -e 'server.modules += ("mod_magnet")\n\n$HTTP["url"] =~ "^/health/?" {\n  magnet.attract-physical-path-to = ("/etc/lighttpd/lua/healthcheck.lua")\n}' > /etc/lighttpd/conf-enabled/90-healthcheck.conf && \
    echo -e 'lighty.content = { "OK" }\nreturn 200' > /etc/lighttpd/lua/healthcheck.lua && \
    # readsb - users/permissions/dirs.
    addgroup --system --gid 1000 readsb && \
    useradd \
      --uid 1000 \
      --system \
      --home-dir /usr/share/readsb \
      --no-create-home \
      --no-user-group \
      --gid 1000 \
      --groups plugdev,dialout \
      readsb \
      && \
    mkdir -p "/var/lib/collectd/rrd/localhost/readsb" && \
    chmod -R 755 "/var/lib/collectd" && \
    chown readsb "/var/lib/collectd" && \
    chown -R readsb: "/usr/share/readsb" && \
    mkdir -p "/run/readsb" && \
    chmod -R 755 "/run/readsb" && \
    chown -R readsb: "/run/readsb" && \
    touch "/etc/default/readsb" && \
    chown -R readsb: "/etc/default/readsb" && \
    # lighttpd configuration - PID file location + permissions.
    sed -i 's/^server\.pid-file.*/server.pid-file = "\/var\/run\/lighttpd\/lighttpd.pid"/g' /etc/lighttpd/lighttpd.conf && \
    mkdir -p "/var/run/lighttpd" && \
    chown readsb "/var/run/lighttpd" && \
    # lighttpd configuration - mod_compress location + permissions.
    mkdir -p "/var/cache/lighttpd/compress/script/readsb/backend" && \
    mkdir -p "/var/cache/lighttpd/compress/css/bootstrap" && \
    mkdir -p "/var/cache/lighttpd/compress/css/leaflet" && \
    chown -R readsb:www-data "/var/cache/lighttpd" && \
    chmod -R u+rwx,g+rwx "/var/cache/lighttpd" && \
    # lighttpd configuration - remove "unconfigured" conf.
    rm -v "/etc/lighttpd/conf-enabled/99-unconfigured.conf" && \
    # lighttpd configuration - change server port (needs to be a high port as this is a rootless container).
    sed -i 's/^server\.port.*/server.port = 8080/g' /etc/lighttpd/lighttpd.conf && \
    # lighttpd configuration - remove errorlog, lighttpd runs in the foreground so errors will show in container log.
    sed -i 's/^server\.errorlog.*//g' /etc/lighttpd/lighttpd.conf && \
    # collectd configuration - move collectd DataDir under /run & set correct permissions.
    mv -v "/var/lib/collectd" "/run" && \
    chown -R readsb "/run/collectd" && \
    ln -s "/run/collectd" "/var/lib" && \
    # copy our config in & remove empty dir
    mv -v /etc/collectd.readsb/collectd.conf /etc/collectd/collectd.conf && \
    rmdir /etc/collectd.readsb && \
    # collectd configuration - remove unneeded readsb plugins.
    sed -i 's/^LoadPlugin syslog.*//g' /etc/collectd/collectd.conf.d/readsb.collectd.conf && \
    sed -i 's/^LoadPlugin exec.*//g' /etc/collectd/collectd.conf.d/readsb.collectd.conf && \
    sed -i 's/^LoadPlugin curl.*//g' /etc/collectd/collectd.conf.d/readsb.collectd.conf && \
    # collectd configuration - remove syslog configuration from readsb config (as we'll be logging to stdout/container log).
    sed -i '/<Plugin syslog>/,/<\/Plugin>/d' /etc/collectd/collectd.conf.d/readsb.collectd.conf && \
    # set up auto-gain file structure
    mkdir -p "/run/autogain" && \
    chown readsb "/run/autogain" && \
    # Configure telegraf
    mkdir -p /etc/telegraf/telegraf.d && \
    mv -v /etc/telegraf.readsb/telegraf.conf /etc/telegraf/telegraf.conf && \
    rmdir /etc/telegraf.readsb && \
    echo "telegraf --version" >> /VERSIONS && \
    # Update readsb webapp databases
    # attempt download of aircrafts.json
    curl \
        --location \
        -o /usr/share/readsb/html/db/aircrafts.json \
        -z /usr/share/readsb/html/db/aircrafts.json \
        'https://github.com/Mictronics/readsb-protobuf/raw/dev/webapp/src/db/aircrafts.json' \
        && \
    # attempt download of dbversion.json
    curl \
        --location \
        -o /usr/share/readsb/html/db/dbversion.json \
        -z /usr/share/readsb/html/db/dbversion.json \
        'https://github.com/Mictronics/readsb-protobuf/raw/dev/webapp/src/db/dbversion.json' \
        && \
    # attempt download of operators.json
    curl \
        --location \
        -o /usr/share/readsb/html/db/operators.json \
        -z /usr/share/readsb/html/db/operators.json \
        'https://github.com/Mictronics/readsb-protobuf/raw/dev/webapp/src/db/operators.json' \
        && \
    # attempt download of types.json
    curl \
        --location \
        -o /usr/share/readsb/html/db/types.json \
        -z /usr/share/readsb/html/db/types.json \
        'https://github.com/Mictronics/readsb-protobuf/raw/dev/webapp/src/db/types.json' \
        && \
    # Clean-up.
    apt-get remove -y ${TEMP_PACKAGES[@]} && \
    apt-get autoremove -y && \
    rm -rf /src/* /tmp/* /var/lib/apt/lists/* && \
    # Document versions.
    echo "readsb $(readsb --version | cut -d ' ' -f 2)" >> /VERSIONS && \
    cat /VERSIONS && \
    readsb --version | cut -d ' ' -f 2 > /CONTAINER_VERSION

# Set s6 init as entrypoint
ENTRYPOINT [ "/init" ]

# Add healthcheck
HEALTHCHECK --start-period=3600s --interval=600s CMD /scripts/healthcheck.sh

# This container can't be rootless - readsb can't talk to RTLSDR if USER is set :-(
