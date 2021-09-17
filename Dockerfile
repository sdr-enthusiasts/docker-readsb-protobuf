FROM debian:buster-20210902-slim

ENV BRANCH_RTLSDR="ed0317e6a58c098874ac58b769cf2e609c18d9a5" \
    S6_BEHAVIOUR_IF_STAGE2_FAILS=2 \
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
    READSB_NET_RAW_OUTPUT_PORT=30002

SHELL ["/bin/bash", "-o", "pipefail", "-c"]

# Copy container filesystem
COPY rootfs/ /

RUN set -x && \
    TEMP_PACKAGES=() && \
    KEPT_PACKAGES=() && \
    # Required for autogain
    KEPT_PACKAGES+=(bc) && \
    # Required for nicer logging.
    KEPT_PACKAGES+=(gawk) && \
    # Required for healthchecks.
    KEPT_PACKAGES+=(procps) && \
    KEPT_PACKAGES+=(net-tools) && \
    # Required for automatic gain script (to interpret .pb files).
    KEPT_PACKAGES+=(protobuf-compiler) && \
    # Required for downloading stuff.
    TEMP_PACKAGES+=(ca-certificates) && \
    TEMP_PACKAGES+=(curl) && \
    TEMP_PACKAGES+=(git) && \
    # Required for building multiple packages.
    TEMP_PACKAGES+=(build-essential) && \
    TEMP_PACKAGES+=(pkg-config) && \
    TEMP_PACKAGES+=(cmake) && \
    # libusb-1.0-0 + dev - Required for rtl-sdr, libiio (bladeRF/PlutoSDR).
    KEPT_PACKAGES+=(libusb-1.0-0) && \
    TEMP_PACKAGES+=(libusb-1.0-0-dev) && \
    # libxml2 + dev - Required for libiio (bladeRF/PlutoSDR).
    KEPT_PACKAGES+=(libxml2) && \
    TEMP_PACKAGES+=(libxml2-dev) && \
    # bison & flex - Required for building libiio (bladeRF/PlutoSDR).
    TEMP_PACKAGES+=(bison) && \
    TEMP_PACKAGES+=(flex) && \
    # libcdk5 + dev - Required for building libiio (bladeRF/PlutoSDR).
    KEPT_PACKAGES+=(libcdk5nc6) && \
    TEMP_PACKAGES+=(libcdk5-dev) && \
    # libaio1 + dev - Required for building libiio (bladeRF/PlutoSDR).
    KEPT_PACKAGES+=(libaio1) && \
    TEMP_PACKAGES+=(libaio-dev) && \
    # libserialport0 + dev - Required for building libiio (bladeRF/PlutoSDR).
    KEPT_PACKAGES+=(libserialport0) && \
    TEMP_PACKAGES+=(libserialport-dev) && \
    # avahi libraries - needed for libiio
    TEMP_PACKAGES+=(libavahi-client-dev) && \
    KEPT_PACKAGES+=(libavahi-client3) && \
    TEMP_PACKAGES+=(libavahi-common-dev) && \
    KEPT_PACKAGES+=(libavahi-common3) && \
    # Requirements for readsb.
    TEMP_PACKAGES+=(protobuf-c-compiler) && \
    TEMP_PACKAGES+=(libprotobuf-c-dev) && \
    KEPT_PACKAGES+=(libprotobuf-c1) && \
    KEPT_PACKAGES+=(librrd8) && \
    TEMP_PACKAGES+=(librrd-dev) && \
    TEMP_PACKAGES+=(libncurses5-dev) && \
    # Packages for readsb web interface & graphs.
    KEPT_PACKAGES+=(lighttpd) && \
    KEPT_PACKAGES+=(collectd-core) && \
    KEPT_PACKAGES+=(rrdtool) && \
    # Packages for telegraf
    TEMP_PACKAGES+=(apt-transport-https) && \
    KEPT_PACKAGES+=(socat) && \
    # Requirements for kalibrate-rtl
    TEMP_PACKAGES+=(autoconf) && \
    TEMP_PACKAGES+=(automake) && \
    TEMP_PACKAGES+=(libtool) && \
    KEPT_PACKAGES+=(libfftw3-3) && \
    TEMP_PACKAGES+=(libfftw3-dev) && \
    # Packages for s6-overlay deployment.
    TEMP_PACKAGES+=(file) && \
    TEMP_PACKAGES+=(gnupg) && \
    # Install packages.
    apt-get update && \
    apt-get install -o Dpkg::Options::="--force-confold" --force-yes -y --no-install-recommends \
        ${KEPT_PACKAGES[@]} \
        ${TEMP_PACKAGES[@]} \
        && \
    git config --global advice.detachedHead false && \
    # Build rtl-sdr.
    git clone git://git.osmocom.org/rtl-sdr.git "/src/rtl-sdr" && \
    pushd "/src/rtl-sdr" && \
    #export BRANCH_RTLSDR=$(git tag --sort="-creatordate" | head -1) && \
    #git checkout "tags/${BRANCH_RTLSDR}" && \
    git checkout "${BRANCH_RTLSDR}" && \
    echo "rtl-sdr ${BRANCH_RTLSDR}" >> /VERSIONS && \
    mkdir -p "/src/rtl-sdr/build" && \
    pushd "/src/rtl-sdr/build" && \
    cmake ../ -DINSTALL_UDEV_RULES=ON -Wno-dev && \
    make -Wstringop-truncation && \
    make -Wstringop-truncation install && \
    cp -v "/src/rtl-sdr/rtl-sdr.rules" "/etc/udev/rules.d/" && \
    popd && popd && \
    # Build dependencies, libiio for PlutoSDR (ADALM-PLUTO).
    git clone https://github.com/analogdevicesinc/libiio.git "/src/libiio" && \
    pushd "/src/libiio" && \
    echo "libiio $(git log | head -1 | cut -d ' ' -f 2)" >> /VERSIONS && \
    cmake ./ && \
    make all && \
    make install && \
    popd && \
    # Build dependencies, libad9361 for PlutoSDR (ADALM-PLUTO).
    git clone https://github.com/analogdevicesinc/libad9361-iio.git "/src/libad9361-iio" && \
    pushd "/src/libad9361-iio" && \
    echo "libad9361-iio $(git log | head -1 | cut -d ' ' -f 2)" >> /VERSIONS && \
    cmake ./ && \
    make all && \
    make install && \
    popd && \
    # Build dependencies, bladeRF.
    git clone https://github.com/Nuand/bladeRF.git "/src/bladeRF" && \
    pushd "/src/bladeRF" && \
    echo "bladeRF $(git log | head -1 | cut -d ' ' -f 2)" >> /VERSIONS && \
    mkdir -p "/src/bladeRF/build" && \
    pushd "/src/bladeRF/build" && \
    cmake -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX=/usr/local -DINSTALL_UDEV_RULES=ON ../ && \
    make && \
    make install && \
    ldconfig && \
    popd && popd && \
    # Download bladeRF FPGA Images.
    BLADERF_RBF_PATH="/usr/share/Nuand/bladeRF" && \
    mkdir -p "$BLADERF_RBF_PATH" && \
    curl -o "$BLADERF_RBF_PATH/hostedxA4.rbf" https://www.nuand.com/fpga/hostedxA4-latest.rbf && \
    curl -o "$BLADERF_RBF_PATH/hostedxA9.rbf" https://www.nuand.com/fpga/hostedxA9-latest.rbf && \
    curl -o "$BLADERF_RBF_PATH/hostedx40.rbf" https://www.nuand.com/fpga/hostedx40-latest.rbf && \
    curl -o "$BLADERF_RBF_PATH/hostedx115.rbf" https://www.nuand.com/fpga/hostedx115-latest.rbf && \
    curl -o "$BLADERF_RBF_PATH/adsbxA4.rbf" https://www.nuand.com/fpga/adsbxA4.rbf && \
    curl -o "$BLADERF_RBF_PATH/adsbxA9.rbf" https://www.nuand.com/fpga/adsbxA9.rbf && \
    curl -o "$BLADERF_RBF_PATH/adsbx40.rbf" https://www.nuand.com/fpga/adsbx40.rbf && \
    curl -o "$BLADERF_RBF_PATH/adsbx115.rbf" https://www.nuand.com/fpga/adsbx115.rbf && \
    # Build & install kalibrate-rtl
    # See: https://discussions.flightaware.com/t/setting-frequency-offset-or-exact-frequency-ppm/15812/6
    git clone https://github.com/steve-m/kalibrate-rtl.git "/src/kalibrate-rtl" && \
    pushd "/src/kalibrate-rtl" && \
    ./bootstrap && \
    ./configure && \
    make all install && \
    popd && \
    # Build readsb.
    git clone https://github.com/Mictronics/readsb-protobuf.git "/src/readsb-protobuf" && \
    pushd "/src/readsb-protobuf" && \
    BRANCH_READSB=$(git tag --sort="creatordate" | tail -1) && \
    git checkout "$BRANCH_READSB" && \
    make BLADERF=yes RTLSDR=yes PLUTOSDR=yes && \
    popd && \
    # Install readsb - Copy readsb executables to /usr/local/bin/.
    find "/src/readsb-protobuf" -maxdepth 1 -executable -type f -exec cp -v {} /usr/local/bin/ \; && \
    # Install readsb - Deploy webapp.
    git clone https://github.com/Mictronics/readsb-protobuf.git "/src/readsb-protobuf-db" && \
    mkdir -p /usr/share/readsb/html && \
    cp -Rv /src/readsb-protobuf-db/webapp/src/* /usr/share/readsb/html/ && \
    ln -s /etc/lighttpd/conf-available/01-setenv.conf /etc/lighttpd/conf-enabled/01-setenv.conf && \
    cp -v /src/readsb-protobuf/debian/lighttpd/* /etc/lighttpd/conf-enabled/ && \
    # Install readsb - Configure collectd & graphs.
    mkdir -p /etc/collectd/collectd.conf.d && \
    cp -v /src/readsb-protobuf/debian/collectd/readsb.collectd.conf /etc/collectd/collectd.conf.d/ && \
    mkdir -p /usr/share/readsb/graphs && \
    cp -v /src/readsb-protobuf/debian/graphs/*.sh /usr/share/readsb/graphs/ && \
    chmod a+x /usr/share/readsb/graphs/*.sh && \
    # Install readsb - users/permissions/dirs.
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
    # readsb - copy readsb protobuf proto file
    mkdir -p /opt/readsb-protobuf && \
    cp -v /src/readsb-protobuf/readsb.proto /opt/readsb-protobuf/readsb.proto && \
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
    # Install telegraf
    curl --location --silent -o - https://repos.influxdata.com/influxdb.key | apt-key add - && \
    source /etc/os-release && \ 
    echo "deb https://repos.influxdata.com/debian $VERSION_CODENAME stable" > /etc/apt/sources.list.d/influxdb.list && \
    apt-get update && \
    apt-get install --no-install-recommends -y telegraf && \
    mv -v /etc/telegraf/telegraf.conf /etc/telegraf/telegraf.conf.original && \
    mv -v /etc/telegraf.readsb/telegraf.conf /etc/telegraf/telegraf.conf && \
    rmdir /etc/telegraf.readsb && \
    # Deploy s6-overlay.
    curl -s https://raw.githubusercontent.com/mikenye/deploy-s6-overlay/master/deploy-s6-overlay.sh | sh && \
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
