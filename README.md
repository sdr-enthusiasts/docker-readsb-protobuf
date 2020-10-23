# mikenye/readsb-protobuf

[Mictronics' `readsb-protobuf`](https://github.com/Mictronics/readsb-protobuf) Mode-S/ADSB/TIS decoder for RTLSDR, BladeRF, Modes-Beast and GNS5894 devices, running in a docker container.

This version uses Googles protocol buffer for data storage and exchange with web application. Saves on storage space and bandwidth.

This container also contains InfluxData's [Telegraf](https://docs.influxdata.com/telegraf/), and can send flight data and `readsb` metrics to InfluxDB (if wanted - not started by default).

Support for all supported SDRs is compiled in. Builds and runs on x86_64, arm32v7 and arm64v8 (see below).

This image will configure a software-defined radio (SDR) to receive and decode Mode-S/ADSB/TIS data from aircraft within range, for use with other services such as:

* `mikenye/adsbexchange` to feed ADSB data to [adsbexchange.com](https://adsbexchange.com)
* `mikenye/piaware` to feed ADSB data into [flightaware.com](https://flightaware.com)
* `mikenye/fr24feed` to feed ADSB data into [flightradar24.com](https://www.flightradar24.com)
* `mikenye/radarbox` to feed ADSB data into [radarbox.com](https://www.radarbox.com)
* `mikenye/opensky-network` to feed ADSB data into [opensky-network.org](https://opensky-network.org/)
* `mikenye/planefinder` to feed ADSB data into [planefinder.net](https://planefinder.net/)
* `mikenye/adsb-to-influxdb` to feed data into your own instance of [InfluxDB](https://docs.influxdata.com/influxdb/), for visualisation with [Grafana](https://grafana.com) and/or other tools
* Any other tools that can receive Beast, BeastReduce, Basestation or the raw data feed from `readsb` or `dump1090` and their variants

Tested and working on:

* `x86_64` (`amd64`) platform running Ubuntu 16.04.4 LTS using an RTL2832U radio (FlightAware Pro Stick Plus Blue)
* `armv7l` (`arm32v7`) platform (Odroid HC1) running Ubuntu 18.04.1 LTS using an RTL2832U radio (FlightAware Pro Stick Plus Blue)
* `aarch64` (`arm64v8`) platform (Raspberry Pi 4) running Raspbian Buster 64-bit using an RTL2832U radio (FlightAware Pro Stick Plus Blue)
* If you run on a different platform (or if you have issues) please raise an issue and let me know!
* bladeRF & plutoSDR are untested - I don't own bladeRF or plutoSDR hardware (only RTL2832U as outlined above), but support for the devices is compiled in. If you have the hardware and would be willing to test, please [open an issue on GitHub](https://github.com/mikenye/docker-readsb-protobuf/issues).

## Table of Contents

* [mikenye/readsb-protobuf](#mikenyereadsb-protobuf)
  * [Table of Contents](#table-of-contents)
  * [Supported tags and respective Dockerfiles](#supported-tags-and-respective-dockerfiles)
  * [Multi Architecture Support](#multi-architecture-support)
  * [Prerequisites](#prerequisites)
  * [Identifying your SDR's device path](#identifying-your-sdrs-device-path)
  * [Up-and-Running with `docker run`](#up-and-running-with-docker-run)
  * [Up-and-Running with Docker Compose](#up-and-running-with-docker-compose)
  * [Testing the container](#testing-the-container)
  * [Environment Variables](#environment-variables)
    * [Container Options](#container-options)
    * [`readsb` General Options](#readsb-general-options)
    * [`readsb` Network Options](#readsb-network-options)
      * [`READSB_NET_CONNECTOR` syntax](#readsb_net_connector-syntax)
    * [`readsb` RTL-SDR Options](#readsb-rtl-sdr-options)
    * [`readsb` BladeRF Options](#readsb-bladerf-options)
    * [`readsb` Mode-S Beast Options](#readsb-mode-s-beast-options)
    * [`readsb` GNS HULC Options](#readsb-gns-hulc-options)
    * [`readsb` ADALM-Pluto SDR Options](#readsb-adalm-pluto-sdr-options)
    * [`readsb` Graphs Options](#readsb-graphs-options)
    * [Auto-Gain Options](#auto-gain-options)
    * [InfluxDB Options](#influxdb-options)
  * [Ports](#ports)
  * [Paths & Volumes](#paths--volumes)
  * [Auto-Gain system](#auto-gain-system)
    * [Initialisation Stage](#initialisation-stage)
    * [Fine-Tuning Stage](#fine-tuning-stage)
    * [Finished Stage](#finished-stage)
    * [State/Log/Stats Files](#statelogstats-files)
    * [Forcing auto-gain to re-run from scrach](#forcing-auto-gain-to-re-run-from-scrach)
  * [Advanced Usage: Creating an MLAT Hub](#advanced-usage-creating-an-mlat-hub)
  * [Grafana Dashboard](#grafana-dashboard)
  * [InfluxDB Schema](#influxdb-schema)
    * [`aircraft` Measurement](#aircraft-measurement)
    * [`autogain` Measurement](#autogain-measurement)
    * [`polar_range` Measurement](#polar_range-measurement)
    * [`readsb` Measurement](#readsb-measurement)
  * [Getting help](#getting-help)
  * [Changelog](#changelog)

## Supported tags and respective Dockerfiles

* `latest` should always contain the latest released versions of `rtl-sdr`, `bladeRF`, `libiio`, `libad9361-iio` and `readsb`. This image is built nightly from the [`main` branch](https://github.com/mikenye/docker-readsb-protobuf) [`Dockerfile`](https://github.com/mikenye/docker-readsb-protobuf/blob/main/Dockerfile) for all supported architectures.
* `latest_nohealthcheck` is the same as the `latest` version above. However, this version has the docker healthcheck removed. This is done for people running platforms (such as [Nomad](https://www.nomadproject.io)) that don't support manually disabling healthchecks, where healthchecks are not wanted.
* Specific version and architecture tags are available if required, however these are not regularly updated. It is generally recommended to run `latest`.

## Multi Architecture Support

Currently, this image should pull and run on the following architectures:

* ```amd64```: Linux x86-64
* ```arm32v7```, ```armv7l```: ARMv7 32-bit (Odroid HC1/HC2/XU4, RPi 2/3)
* ```arm64v8```, ```aarch64```: ARMv8 64-bit (RPi 3B+/4)

## Prerequisites

Before this container will work properly, you must blacklist the kernel modules for the RTL-SDR USB device from the host's kernel.

To do this, create a file `/etc/modprobe.d/blacklist-rtl2832.conf` containing the following:

```shell
# Blacklist RTL2832 so docker container readsb can use the device

blacklist rtl2832
blacklist dvb_usb_rtl28xxu
blacklist rtl2832_sdr
```

Once this is done, you can plug in your RTL-SDR USB device and start the container.

Failure to do this will result in the error below being spammed to the container log.

```
usb_claim_interface error -6
rtlsdr: error opening the RTLSDR device: Device or resource busy
```

If you get the error above even after blacklisting the kernel modules as outlined above, the modules may still be loaded. You can unload them by running the following commands:

```shell
sudo rmmod rtl2832_sdr
sudo rmmod dvb_usb_rtl28xxu
sudo rmmod rtl2832
```

## Identifying your SDR's device path

Plug in your USB radio, and run the command `lsusb`. Find your radio. It'll look something like this:

```
Bus 001 Device 004: ID 0bda:2832 Realtek Semiconductor Corp. RTL2832U DVB-T
```

Take note of the **USB bus number**, and **USB device number**. In the output above, its **001** and **004** respectively. This will be used in the examples below.

## Up-and-Running with `docker run`

Start the docker container, passing through the USB device:

```shell
docker run \
 -d \
 -it \
 --restart=always \
 --name readsb \
 --hostname readsb \
 --device /dev/bus/usb/USB_BUS_NUMBER/USB_DEVICE_NUMBER \
 -p 8080:8080 \
 -p 30005:30005 \
 -e TZ=<YOUR_TIMEZONE> \
 -e READSB_DCFILTER=true \
 -e READSB_DEVICE_TYPE=rtlsdr \
 -e READSB_FIX=true \
 -e READSB_GAIN=autogain \
 -e READSB_LAT=<YOUR_LATITUDE> \
 -e READSB_LON=<YOUR_LONGITUDE> \
 -e READSB_MODEAC=true \
 -e READSB_RX_LOCATION_ACCURACY=2 \
 -e READSB_STATS_RANGE=true \
 -e READSB_NET_ENABLE=true \
 -v /local/path/for/autogain=/run/autogain \
 -v /local/path/for/collectd=/run/collectd \
 mikenye/readsb-protobuf
```

For example:

```shell
docker run \
 -d \
 -it \
 --restart=always \
 --name readsb \
 --hostname readsb \
 --device /dev/bus/usb/001/004 \
 -p 8080:8080 \
 -p 30005:30005 \
 -e TZ=Australia/Perth \
 -e READSB_DCFILTER=true \
 -e READSB_DEVICE_TYPE=rtlsdr \
 -e READSB_FIX=true \
 -e READSB_GAIN=autogain \
 -e READSB_LAT=33.33333 \
 -e READSB_LON=-111.11111 \
 -e READSB_MODEAC=true \
 -e READSB_RX_LOCATION_ACCURACY=2 \
 -e READSB_STATS_RANGE=true \
 -e READSB_NET_ENABLE=true \
 -v /opt/readsb/autogain=/run/autogain \
 -v /opt/readsb/collectd=/run/collectd \
 mikenye/readsb-protobuf
```

Alternatively, you could pass through the entire USB bus with `--device /dev/bus/usb`, but please understand the security implications of doing so.

## Up-and-Running with Docker Compose

An example `docker-compose.yml` file is below:

```yaml
version: '2.0'

networks:
  adsbnet:

volumes:
  readsbpb_rrd:
  readsbpb_autogain:

services:

  readsb:
    image: mikenye/readsb-protobuf
    tty: true
    container_name: readsb
    hostname: readsb
    restart: always
    devices:
      - /dev/bus/usb/001/004:/dev/bus/usb/001/004
    ports:
      - 8080:8080
      - 30005:30005
    networks:
      - adsbnet
    environment:
      - TZ=Australia/Perth
      - READSB_DCFILTER=true
      - READSB_DEVICE_TYPE=rtlsdr
      - READSB_FIX=true
      - READSB_GAIN=autogain
      - READSB_LAT=-33.33333
      - READSB_LON=111.11111
      - READSB_MODEAC=true
      - READSB_RX_LOCATION_ACCURACY=2
      - READSB_STATS_RANGE=true
      - READSB_NET_ENABLE=true
    volumes:
      - readsbpb_rrd:/run/collectd
      - readsbpb_autogain:/run/autogain
```

## Testing the container

Once running, you can test the container to ensure it is correctly receiving & decoding ADSB traffic by issuing the command:

```shell
docker exec -it readsb viewadsb
```

Which should display a departure-lounge-style screen showing all the aircraft being tracked, for example:

```
 Hex    Mode  Sqwk  Flight   Alt    Spd  Hdg    Lat      Long   RSSI  Msgs  Ti -
────────────────────────────────────────────────────────────────────────────────
 7C801C S                     8450  256  296                   -28.0    14  1
 7C8148 S                     3900                             -21.5    19  0
 7C7A48 S     1331  VOZ471   28050  468  063  -31.290  117.480 -26.8    48  0
 7C7A4D S     3273  VOZ694   13100  376  077                   -29.1    14  1
 7C7A6E S     4342  YGW       1625  109  175  -32.023  115.853  -5.9    71  0
 7C7A71 S           YGZ        725   64  167  -32.102  115.852 -27.1    26  0
 7C42D1 S                    32000  347  211                   -32.0     4  1
 7C42D5 S                    33000  421  081  -30.955  118.568 -28.7    15  0
 7C42D9 S     4245  NWK1643   1675  173  282  -32.043  115.961 -13.6    60  0
 7C431A S     3617  JTE981   24000  289  012                   -26.7    41  0
 7C1B2D S     3711  VOZ9242  11900  294  209  -31.691  116.118  -9.5    65  0
 7C5343 S           QQD      20000  236  055  -30.633  116.834 -25.5    27  0
 7C6C96 S     1347  JST116   24000  397  354  -30.916  115.873 -17.5    62  0
 7C6C99 S     3253  JST975    2650  210  046  -31.868  115.993  -2.5    70  0
 76CD03 S     1522  SIA214     grnd   0                        -22.5     7  0
 7C4513 S     4220  QJE1808   3925  282  279  -31.851  115.887  -1.9    35  0
 7C4530 S     4003  NYA      21925  229  200  -30.933  116.640 -19.8    58  0
 7C7533 S     3236  XFP       4300  224  266  -32.066  116.124  -6.9    74  0
 7C4D44 S     3730  PJQ      20050  231  199  -31.352  116.466 -20.1    62  0
 7C0559 S     3000  BCB       1000                             -18.4    28  0
 7C0DAA S     1200            2500  146  002  -32.315  115.918 -26.6    48  0
 7C6DD7 S     1025  QFA793   17800  339  199  -31.385  116.306  -8.7    53  0
 8A06F0 S     4131  AWQ544    6125  280  217  -32.182  116.143 -12.6    61  0
 7CF7C4 S           PHRX1A                                     -13.7     8  1
 7CF7C5 S           PHRX1B                                     -13.3     9  1
 7C77F6 S           QFA595     grnd 112  014                   -33.2     2  2
```

Press `CTRL-C` to escape this screen.

You should also be able to point your web browser at `http://dockerhost:8080/` to view the web interface.

## Environment Variables

### Container Options

| Variable | Description | Default |
|----------|-------------|---------|
| `DISABLE_PERFORMANCE_GRAPHS` | Set to any value to disable the performance graphs (and data collection). | Unset |
| `DISABLE_WEBAPP` | Set to any value to disable the container's web server (you may also want to `DISABLE_PERFORMANCE_GRAPHS` if using this option). | Unset |
| `TZ` | Local timezone in ["TZ database name" format](<https://en.wikipedia.org/wiki/List_of_tz_database_time_zones>). | `UTC` |
| `VERBOSE_LOGGING` | Set to any value to enable verbose logging for troubleshooting. | Unset |

### `readsb` General Options

Where the default value is "Unset", `readsb`'s default will be used.

| Variable | Description | Controls which `readsb` option | Default |
|----------|-------------|--------------------------------|---------|
| `READSB_DCFILTER` | Set to any value to apply a 1Hz DC filter to input data (requires more CPU) | `--dcfilter` | Unset |
| `READSB_DEVICE_TYPE` | If using an SDR, set this to `rtlsdr`, `bladerf`, `modesbeast`, `gnshulc` or `plutosdr` depending on the model of your SDR. If not using an SDR, leave un-set. | `--device-type=<type>` | Unset |
| `READSB_ENABLE_BIASTEE` | Set to any value to enable bias tee on supporting interfaces | `--enable-biastee` | Unset |
| `READSB_FIX` | Set to any value to enable CRC single-bit error correction | `--fix` | Unset |
| `READSB_FORWARD_MLAT` | Set this to any value to allow forwarding of received mlat results to output ports. Leave this unset unless you know what you're doing. | `--forward-mlat` | Unset |
| `READSB_FREQ` | Set frequency (in MHz) | `--freq=<hz>` | `1090` |
| `READSB_GAIN` | Set gain (in dB). Use `autogain` to have the container determine an appropriate gain, more on this below. | `--gain=<db>` | Max gain |
| `READSB_GNSS` | Set this to any value to show altitudes as GNSS when available | `--gnss` | Unset |
| `READSB_LAT` | Reference/receiver surface latitude | `--lat=<lat>` | Unset |
| `READSB_LON` | Reference/receiver surface longitude | `--lon=<lon>` | Unset |
| `READSB_MAX_RANGE` | Absolute maximum range for position decoding (in nm) | `--max-range=<dist>` | `300` |
| `READSB_METRIC` | Set this to any value to use metric units | `--metric` | Unset |
| `READSB_MLAT` | Set this to any value to display raw messages in Beast ASCII mode | `--mlat` | Unset |
| `READSB_MODEAC` | Set this to any value to enable decoding of SSR Modes 3/A & 3/C | `--modeac` | Unset |
| `READSB_NO_CRC_CHECK` | Set this to any value to disable messages with invalid CRC (discouraged) | `--no-crc-check` | Unset |
| `READSB_NO_FIX` | Set this to any value to disable CRC single-bit error correction | `--no-fix` | Unset |
| `READSB_NO_MODEAC_AUTO` | Set this to any value and Mode A/C won't be enabled automatically if requested by a Beast connection | `--no-modeac-auto` | Unset |
| `READSB_RX_LOCATION_ACCURACY` | Accuracy of receiver location in metadata: `0`=no location, `1`=approximate, `2`=exact | `--rx-location-accuracy=<n>` | Unset |
| `READSB_STATS_EVERY` | Number of seconds between showing and resetting stats. | `--stats-every=<sec>` | Unset |
| `READSB_STATS_RANGE` | Set this to any value to collect range statistics for polar plot. | `--stats-range` |  Unset |

### `readsb` Network Options

Where the default value is "Unset", `readsb`'s default will be used.

| Variable | Description | Controls which `readsb` option | Default |
|----------|-------------|--------------------------------|---------|
| `READSB_NET_ENABLE` | Set this to any value to enable networking. | `--net` | Unset |
| `READSB_NET_BEAST_REDUCE_INTERVAL` | BeastReduce position update interval, longer means less data (valid range: `0.000` - `14.999`) | `--net-beast-reduce-interval=<seconds>` | `0.125` |
| `READSB_NET_BEAST_REDUCE_OUT_PORT` | TCP BeastReduce output listen ports (comma separated) | `--net-beast-reduce-out-port=<ports>` | Unset |
| `READSB_NET_BEAST_INPUT_PORT`| TCP Beast input listen ports | `--net-bi-port=<ports>` | `30004,30104` |
| `READSB_NET_BEAST_OUTPUT_PORT` | TCP Beast output listen ports | `--net-bo-port=<ports>` | `30005` |
| `READSB_NET_BUFFER` | TCP buffer size 64Kb * (2^n) | `--net-buffer=<n>` | `2` (256Kb) |
| `READSB_NET_CONNECTOR` | See "`READSB_NET_CONNECTOR` syntax" below. | `--net-connector=<ip,port,protocol>` | Unset |
| `READSB_NET_CONNECTOR_DELAY` | Outbound re-connection delay. | `--net-connector-delay=<seconds>` | `30` |
| `READSB_NET_HEARTBEAT` | TCP heartbeat rate in seconds (0 to disable). | `--net-heartbeat=<rate>` | `60` |
| `READSB_NET_ONLY` | Set this to any value to enable just networking, no SDR used. | `--net-only` | Unset |
| `READSB_NET_RAW_INPUT_PORT` | TCP raw input listen ports. | `--net-ri-port=<ports>` | `30001` |
| `READSB_NET_RAW_OUTPUT_INTERVAL` | TCP output flush interval in seconds (maximum interval between two network writes of accumulated data). | `--net-ro-interval=<rate>` | `0.05` |
| `READSB_NET_RAW_OUTPUT_PORT` | TCP raw output listen ports. | `--net-ro-port=<ports>` | `30002` |
| `READSB_NET_RAW_OUTPUT_SIZE` | TCP output flush size (maximum amount of internally buffered data before writing to network). | `--net-ro-size=<size>` | `1200` |
| `READSB_NET_SBS_INPUT_PORT` | TCP BaseStation input listen ports. | `--net-sbs-in-port=<ports>` | Unset |
| `READSB_NET_SBS_OUTPUT_PORT` | TCP BaseStation output listen ports. | `--net-sbs-port=<ports>` | `30003` |
| `REASSB_NET_VERBATIM` | Set this to any value to forward messages unchanged. | `--net-verbatim` | Unset |
| `READSB_NET_VRS_PORT` | TCP VRS JSON output listen ports. | `--net-vrs-port=<ports>` | Unset |

#### `READSB_NET_CONNECTOR` syntax

This variable allows you to configure outgoing connections. The variable takes a semicolon (`;`) separated list of `ip,port,protocol`, where:

* `ip` is an IP address. Specify an IP/hostname/containername for outgoing connections.
* `port` is a TCP port number
* `protocol` can be one of the following:
  * `beast_out`: Beast-format output
  * `beast_in`: Beast-format input
  * `raw_out`: Raw output
  * `raw_in`: Raw input
  * `sbs_out`: SBS-format output
  * `vrs_out`: SBS-format output

For example, to pull in MLAT results (so the performance graphs in the web interface show MLAT numbers), you could do the following:

```yaml
    environment:
    ...
      - READSB_NET_CONNECTOR=piaware,30105,beast_in;adsbx,30105,beast_in;rbfeeder,30105,beast_in
    ...
```

### `readsb` RTL-SDR Options

Use with `READSB_DEVICE_TYPE=rtlsdr`.

Where the default value is "Unset", `readsb`'s default will be used.

| Variable | Description | Controls which `readsb` option | Default |
|----------|-------------|--------------------------------|---------|
| `READSB_RTLSDR_DEVICE` | Select device by index or serial number. | `--device=<index or serial>` | Unset |
| `READSB_RTLSDR_ENABLE_AGC` | Set this to any value to enable digital AGC (not tuner AGC!) | `--enable-agc` | Unset |
| `READSB_RTLSDR_PPM` | Set oscillator frequency correction in PPM | `--ppm=<correction>` | Unset |

### `readsb` BladeRF Options

Use with `READSB_DEVICE_TYPE=bladerf`.

Where the default value is "Unset", `readsb`'s default will be used.

| Variable | Description | Controls which `readsb` option | Default |
|----------|-------------|--------------------------------|---------|
| `READSB_BLADERF_DEVICE` | Select device by bladeRF 'device identifier'. | `--device=<ident>` | Unset |
| `READSB_BLADERF_BANDWIDTH` | Set LPF bandwidth ('bypass' to bypass the LPF). | `--bladerf-bandwidth=<hz>` | Unset |
| `READSB_BLADERF_DECIMATION` | Assume FPGA decimates by a factor of N. | `--bladerf-decimation=<N>` | Unset |
| `READSB_BLADERF_FPGA` | Use alternative FPGA bitstream ('' to disable FPGA load). | `--bladerf-fpga=<path>` | Unset

### `readsb` Mode-S Beast Options

Use with `READSB_DEVICE_TYPE=modesbeast`.

Where the default value is "Unset", `readsb`'s default will be used.

Beast binary protocol and hardware handshake are always enabled.

| Variable | Description | Controls which `readsb` option | Default |
|----------|-------------|--------------------------------|---------|
| `READSB_BEAST_CRC_OFF` | Set this to any value to turn OFF CRC checking. | `--beast-crc-off` | Unset |
| `READSB_BEAST_DF045_ON` | Set this to any value to turn ON DF0/4/5 filter. | `--beast-df045-on` | Unset |
| `READSB_BEAST_DF1117_ON` | Set this to any value to turn ON DF11/17-only filter. | `--beast-df1117-on` | Unset |
| `READSB_BEAST_FEC_OFF` | Set this to any value to turn OFF forward error correction. | `--beast-fec-off` | Unset |
| `READSB_BEAST_MLAT_OFF` | Set this to any value to turn OFF MLAT time stamps. | `--beast-mlat-off` | Unset |
| `READSB_BEAST_MODEAC` | Set this to any value to turn ON mode A/C. | `--beast-modeac` | Unset |
| `READSB_BEAST_SERIAL` | Path to Beast serial device. | `--beast-serial=<path>` | `/dev/ttyUSB0` |

### `readsb` GNS HULC Options

Use with `READSB_DEVICE_TYPE=gnshulc`.

| Variable | Description | Controls which `readsb` option | Default |
|----------|-------------|--------------------------------|---------|
| `READSB_BEAST_SERIAL` | Path to Beast serial device. | `--beast-serial=<path>` | `/dev/ttyUSB0` |

### `readsb` ADALM-Pluto SDR Options

Use with `READSB_DEVICE_TYPE=plutosdr`.

Where the default value is "Unset", `readsb`'s default will be used.

| Variable | Description | Controls which `readsb` option | Default |
|----------|-------------|--------------------------------|---------|
| `READSB_PLUTO_NETWORK` | Hostname or IP to create networks context. | `--pluto-network=<hostname or IP>` | `pluto.local` |
| `READSB_PLUTO_URI` | Create USB context from this URI. (eg. usb:1.2.5) | `--pluto-uri=<USB uri>` | Unset |

### `readsb` Graphs Options

Where the default value is "Unset", `readsb`'s default will be used.

| Variable | Description | Controls which `readsb` option | Default |
|----------|-------------|--------------------------------|---------|
| `READSBRRD_STEP` | Interval in seconds to feed data into RRD files. | `60` |
| `READSB_GRAPH_SIZE` | Set graph size, possible values: `small`, `default`, `large`, `huge`, `custom`. | `default` |
| `READSB_GRAPH_ALL_LARGE` | Make the small graphs as large as the big ones by setting to `yes`. | `no` |
| `READSB_GRAPH_FONT_SIZE` | Font size (relative to graph size). | `10.0` |
| `READSB_GRAPH_MAX_MESSAGES_LINE` | Set to `1` to draw a reference line at the maximum message rate. | `0` |
| `READSB_GRAPH_LARGE_WIDTH` | Defines the width of the larger graphs. | `1096` |
| `READSB_GRAPH_LARGE_HEIGHT` | Defines the height of the larger graphs. | `235` |
| `READSB_GRAPH_SMALL_WIDTH` | Defines the width of the smaller graphs. | `619` |
| `READSB_GRAPH_SMALL_HEIGHT` | Defines the height of the smaller graphs. | `324` |

### Auto-Gain Options

These variables control the auto-gain system (explained further below). These should rarely need changing from the defaults.

| Variable | Description | Default |
|----------|-------------|---------|
| `AUTOGAIN_INITIAL_PERIOD` | How long each gain level should be measured during auto-gain initialisation (ie: "roughing in"), in seconds. | `7200` (2 hours) |
| `AUTOGAIN_INITIAL_MSGS_ACCEPTED` | How many locally accepted messages should be received per gain level during auto-gain initialisaion to ensure accurate measurement. | `1000000` |
| `AUTOGAIN_FINETUNE_PERIOD` | How long each gain level should be measured during auto-gain fine-tuning, in seconds. | `604800` (7 days) |
| `AUTOGAIN_FINETUNE_MSGS_ACCEPTED` | How many locally accepted messages should be received per gain level during auto-gain fine-tuning to ensure accurate measurement. | `10000000` |
| `AUTOGAIN_FINISHED_PERIOD` | How long between the completion of fine-tuning (and ultimetly setting a preferred gain), and re-running the entire process. | `31536000` (1 year) |
| `AUTOGAIN_MAX_GAIN_VALUE` | The maximum gain setting in dB that will be used by auto-gain. | `49.6` (max supported by `readsb`) |
| `AUTOGAIN_MIN_GAIN_VALUE` | The minimum gain setting in dB that will be used by auto-gain. | `0.0` (min supported by `readsb`) |
| `AUTOGAIN_PERCENT_STRONG_MESSAGES_MAX` | The maximum percentage of "strong messages" auto-gain will aim for. | `10.0` |
| `AUTOGAIN_PERCENT_STRONG_MESSAGES_MIN` | The minimum percentage of "strong messages" auto-gain will aim for. | `0.5` |
| `AUTOGAIN_SERVICE_PERIOD` | How often the auto-gain system will check results and perform actions, in seconds | `900` |

### InfluxDB Options

These variables control the sending of flight data and readsb metrics to [InfluxDB](https://docs.influxdata.com/influxdb/) (via a built-in instance of [Telegraf](https://docs.influxdata.com/telegraf/)).

| Variable | Description | Default |
|----------|-------------|---------|
| `INFLUXDBURL` | The full HTTP URL for your InfluxDB instance. | Unset |
| `INFLUXDBUSERNAME` | If using authentication, a username for your InfluxDB instance. If not using authentication, leave unset. | Unset |
| `INFLUXDBPASSWORD` | If using authentication, a password for your InfluxDB instance. If not using authentication, leave unset. | Unset |

If `INFLUXDBURL` is left unset, the built-in instance of Telegraf will not be started.

## Ports

| Port | Details |
|------|---------|
| `8080/tcp` | `readsb` web interface |

In addition to the ports listed above, depending on your `readsb` configuration the container may also be listening on other ports that you'll need to map through (if external connectivity is required).

Some common ports are as follows (which may or may not be in use depending on your configuration):

| Port | Details |
|------|---------|
| `30001/tcp` | Raw protocol input |
| `30002/tcp` | Raw protocol output |
| `30003/tcp` | SBS/Basestation protocol output |
| `30004/tcp` | Beast protocol input |
| `30005/tcp` | Beast protocol output |
| `30104/tcp` | Beast protocol input |

## Paths & Volumes

| Path (inside container) | Details |
|-------------------------|---------|
| `/run/readsb` | `readsb` protobuf file storage. Not necessarily required to be mapped to persistant storage. |
| `/run/collectd` | `collectd` RRD file storage used by `readsb`'s "performance graphs" in the web interface. Map to persistant storage if you use this feature. |
| `/run/autogain` | Map this to persistant storage if you set `READSB_GAIN=autogain` |

## Auto-Gain system

An automatic gain adjustment system is included in this container, and can be activated by setting the environment variable `READSB_GAIN` to `autogain`. You should also map `/run/autogain` to persistant storage, otherwise the auto-gain system will start over each time the container is restarted.

*Why is this written in bash?* Because I wanted to keep the container size down and not have to install an interpreter like python. I don't know C/Go/Perl or any other languages.

Auto-gain will take several weeks to initially (over the period of a week or so) work out feasible maximum and minimum gain levels for your environment. It will then perform a fine-tune process to find the optimal gain level.

During each process, gain levels are ranked as follows:

* The range achievable by each gain level
* The number of aircraft tracks with positions
* The signal-to-noise ratio of the receiver

The ranking process is done by sorting the gain levels for each statistic from worst to best, then awarding points. 0 points are awarded for the worst gain level, 1 point for the next gain level all the way up to several points for the best gain level (total number of points is the number of gain levels tested). The number of points for each gain level is totalled, and the optimal gain level is the level with the largest number of points. Any gain level with a percentage of "strong signals" outside of `AUTOGAIN_PERCENT_STRONG_MESSAGES_MAX` and `AUTOGAIN_PERCENT_STRONG_MESSAGES_MIN` is discarded.

Using this method, auto-gain tried to achieve the best balance of range, tracks and signal-to-noise ratio, whilst ensuring an appropriate number of "strong signals".

The auto-gain system will work as follows:

### Initialisation Stage

In the initialisation process:

1. `readsb` is set to maximum gain (`AUTOGAIN_MAX_GAIN_VALUE`).
1. Results are collected up to `AUTOGAIN_INITIAL_PERIOD` (up to 2 hours by default).
1. Check to ensure at least `AUTOGAIN_INITIAL_MSGS_ACCEPTED` messages have been locally accepted (1,000,000 by default). If not, contine collecting data for up to 24 hours. This combination of time and number of messages ensures we have enough data to make a valid initial assessment of each gain level.
1. Gain level is lowered by one level.
1. If there have been gain levels resulting in a percentage of strong messages between `AUTOGAIN_PERCENT_STRONG_MESSAGES_MAX` and `AUTOGAIN_PERCENT_STRONG_MESSAGES_MIN`, and there have been two consecutive gain levels below `AUTOGAIN_PERCENT_STRONG_MESSAGES_MIN`, auto-gain discontinues testing gain levels.

At this point, all of the tested gain levels are ranked based on the criterea discussed above.

The gain level with the most points is taken, and the maximum and minimum gain levels used by the fine-tuning process are three levels above and below this level.

Auto-gain then moves onto the fine-tuning stage.

### Fine-Tuning Stage

In the fine-tuning process:

1. `readsb` is set to maximum gain level chosen at the end of the initialisation process.
1. Results are collected up to `AUTOGAIN_FINETUNE_PERIOD` (7 days by default).
1. Check to ensure at least `AUTOGAIN_FINETUNE_MSGS_ACCEPTED` messages have been locally accepted (10,000,000 by default). If not, contine collecting data for up to 48 hours. This combination of time and number of messages ensures we have enough data to make an accurate assessment of each gain level, and by using 7 days this ensures any peaks/troughs in data due to quiet/busy days of the week do not skew results.
1. Gain level is lowered by one level until the minimum gain level chosen at the end of the initialisation process is reached.

At this point, all of the tested gain levels are ranked based on the criterea discussed above.

The gain level with the most points is chosen, and `readsb` is set to this gain level.

Auto-gain then moves onto the finished stage.

### Finished Stage

In the finished stage, auto-gain does nothing (as `readsb` is operating at optimal gain) for `AUTOGAIN_FINISHED_PERIOD` (1 year by default). After this time, auto-gain reverts to the initialisation stage and the entire process is completed again. This makes sure your configuration is always running at the optimal gain level as your RTLSDR ages.

### State/Log/Stats Files

All files for auto-gain are located at `/run/autogain` within the container. They should not be modified by hand.

| File | Description |
|------|-------------|
| `/run/autogain/state` | The current state of the auto-gain system (`init`,`finetune`,`finish`). |
| `/run/autogain/autogain_current_value` | The current gain setting, as set by the auto-gain system. |
| `/run/autogain/autogain_current_timestamp` | The timestamp (seconds since epoch) when the current gain was set. |
| `/run/autogain/autogain_review_timestamp` | The timestamp (seconds since epoch) when the current gain level will be reviewed by auto-gain. |
| `/run/autogain/autogain_log` | The log file for auto-gain. Contains verbose/debug entries not normally written to the container log. |
| `/run/autogain/autogain_stats.max_distance` | During initialisation and fine-tuning stages, this file will be used to collect the maximum distance for each gain level. Used for ranking. |
| `/run/autogain/autogain_stats.pct_strong_msgs` | During initialisation and fine-tuning stages, this file will be used to collect the percentage of strong signals for each gain level. Used for ranking. |
| `/run/autogain/autogain_stats.total_accepted_msgs` | During initialisation and fine-tuning stages, this file will be used to collect the total number of accepted messages for each gain level. |
| `/run/autogain/autogain_stats.snr` | During initialisation and fine-tuning stages, this file will be used to collect the signal-to-noise ratio (SNR) for each gain level. Used for ranking. |
| `/run/autogain/autogain_stats.tracks_with_position` | During initialisation and fine-tuning stages, this file will be used to collect the number of tracks with positions for each gain level. Used for ranking. |
| `/run/autogain/autogain_max_value` | During initialisation and fine-tuning stages, this file will be used to set the maximum gain value tested. |
| `/run/autogain/autogain_min_value` | During initialisation and fine-tuning stages, this file will be used to set the maximum gain value tested. |
| `/run/autogain/autogain_interval` | This file will contain the number of seconds for the current state's interval. |
| `/run/autogain/autogain_results.init` | The results (gain rankings) as a result of the initialisation process. |
| `/run/autogain/autogain_results.finetune` | The results (gain rankings) as a result of the fine-tuning process. |

After each stage has completed, the `/run/autogain/autogain_stats.*` files for that stage are moved to `/run/autogain/autogain_stats.*.<stage>`.

### Forcing auto-gain to re-run from scrach

Run `docker exec <container_name> rm /run/autogain/state` to remove the current state. Within 15 minutes or so, auto-gain will detect this and re-start at initialisation stage.

## Advanced Usage: Creating an MLAT Hub

There may be reasons you wish to use `readsb` to combine MLAT feeds from different collectors, to feed into visualisation tools (eg: `mikenye/tar1090`) or data collectors (eg: `mikenye/adsb-to-influxdb`).

To do this, you can create a second container to act as an MLAT hub.

Here are example service definitions (from a `docker-compose.yml` file) for `readsb`, `mlathub`, `asup2influxdb` and `tar1090`.

```yml
...
  readsb:
    image: mikenye/readsb-protobuf:latest
    tty: true
    container_name: readsb
    hostname: readsb
    restart: always
    devices:
      - /dev/bus/usb/001/004:/dev/bus/usb/001/004
    ports:
      - 8079:8080
      - 30003:30003
      - 30005:30005
    networks:
      - adsbnet
    environment:
      - TZ=Australia/Perth
      - READSB_DCFILTER=true
      - READSB_DEVICE_TYPE=rtlsdr
      - READSB_FIX=true
      - READSB_GAIN=autogain
      - READSB_LAT=-33.33333
      - READSB_LON=111.11111
      - READSB_MAX_RANGE=600
      - READSB_MODEAC=true
      - READSB_RX_LOCATION_ACCURACY=2
      - READSB_STATS_RANGE=true
      - READSB_NET_ENABLE=true
      - READSB_NET_CONNECTOR=mlathub,30105,beast_in
    volumes:
      - readsbpb_rrd:/run/collectd
      - readsbpb_autogain:/run/autogain

  mlathub:
    image: mikenye/readsb-protobuf:latest
    tty: true
    container_name: mlathub
    hostname: mlathub
    restart: always
    ports:
      - 30105:30105
    networks:
      - adsbnet
    environment:
      - TZ=Australia/Perth
      - DISABLE_PERFORMANCE_GRAPHS=true
      - DISABLE_WEBAPP=true
      - READSB_NET_ENABLE=true
      - READSB_NET_ONLY=true
      - READSB_FORWARD_MLAT=true
      - READSB_NET_CONNECTOR=piaware,30105,beast_in;adsbx,30105,beast_in;rbfeeder,30105,beast_in
      - READSB_NET_BEAST_OUTPUT_PORT=30105

  adsb2influxdb:
    image: mikenye/adsb-to-influxdb:latest
    tty: true
    container_name: adsb2influxdb
    restart: always
    environment:
      - TZ=Australia/Perth
      - INFLUXDBURL=http://influxdb:8086
      - ADSBHOST=readsb
      - MLATHOST=mlathub
    networks:
      - adsbnet

  tar1090:
    image: mikenye/tar1090:latest
    tty: true
    container_name: tar1090
    restart: always
    depends_on:
      - readsb
    environment:
      - TZ=Australia/Perth
      - BEASTHOST=readsb
      - MLATHOST=mlathub
      - LAT=-33.33333
      - LONG=111.11111
    volumes:
      - "tar1090_heatmap:/var/globe_history"
      - "tar1090_rundir:/run/readsb"
    networks:
      - adsbnet
    ports:
      - 8078:80
```

In this example:

* `readsb` reads and demodulates the ADSB data from the RTLSDR.
* Other services (such as `adsbx`, `piaware` and `rbfeeder` - not shown) pull ADSB data from `readsb`, perform multilateration, and have their resulting MLAT data published on TCP port `30105`.
* `mlathub` connects to the services providing MLAT results (via `READSB_NET_CONNECTOR`), and combines them into a single feed, available on TCP port `30105` (via `READSB_NET_BEAST_OUTPUT_PORT=30105`).
* `readsb` pulls these MLAT results (via a `READSB_NET_CONNECTOR`) so MLAT results show up in its webapp. It is important to note that MLAT results are NOT fed to feeders, which is the desired approach.
* `adsb2influxdb` pulls these MLAT results (via `MLATHOST`) so MLAT metrics are sent to InfluxDB.
* `tar1090` pulls these MLAT results (via `MLATHOST`) so MLAT positions show up in tar1090's web interface.

**You must make absolutely certain that `READSB_FORWARD_MLAT` is NOT set on your main `readsb` instance!** This is why we perform the MLAT hub functionality in a separate instance of `readsb`. You do not want to cross-contaminate MLAT results between feeders. Doing so will almost certainly result in your MLAT results being rejected, and/or may end up getting you ignored/banned from feeding services.

## Grafana Dashboard

If you're using `INFLUXDBURL` and pushing metrics into InfluxDB, I've put together an example Grafana dashboard, which can be found here:

<https://grafana.com/grafana/dashboards/13168>

## InfluxDB Schema

If `INFLUXDBURL` is set, an instance of Telegraf will be started within the container, and metrics will be written to the InfluxDB.

The database `readsb` will be created if it does not exist.

Within this database are the following measurements:

### `aircraft` Measurement

Tags and fields used for this measurement should match [Virtual Radar Server's JSON response ("the new way")](https://www.virtualradarserver.co.uk/Documentation/Formats/AircraftList.aspx).

| Tag Key  | Type | Description |
|----------|------|-------------|
| `Call`   | String | The aircraft's callsign. |
| `Gnd`    | Boolean | True if the aircraft is on the ground. |
| `Icao`   | String | The ICAO of the aircraft. |
| `Mlat`   | Boolean | True if the latitude and longitude appear to have been calculated by an MLAT server and were not transmitted by the aircraft. |
| `SpdTyp` | Number | The type of speed that Spd represents. Only used with raw feeds. `0`/`missing` = ground speed, `1` = ground speed reversing, `2` = indicated air speed, `3` = true air speed. |
| `Sqk`    | Number | The squawk as a decimal number (e.g. a squawk of `7654` is passed as `7654`, not `4012`).
| `Tisb`   | Boolean | True if the last message received for the aircraft was from a TIS-B source. |
| `TrkH`   | Boolean | True if Trak is the aircraft's heading, false if it's the ground track. Default to ground track until told otherwise. |
| `VsiT`   | Number | `0` = vertical speed is barometric, `1` = vertical speed is geometric. Default to barometric until told otherwise. |
| `host`   | String | The hostname of the container. |

| Field Key | Type  | Description |
|-----------|-------|-------------|
| `Alt`     | float | The altitude in feet at standard pressure. |
| `Cmsgs`   | float | The count of messages received for the aircraft. |
| `GAlt`    | float | The altitude adjusted for local air pressure, should be roughly the height above mean sea level. |
| `InHg`    | float | The air pressure in inches of mercury that was used to calculate the AMSL altitude from the standard pressure altitude. |
| `Lat`     | float | The aircraft's latitude over the ground. |
| `Long`    | float | The aircraft's longitude over the ground. |
| `PosTime` | float | The time (at UTC in JavaScript ticks) that the position was last reported by the aircraft. |
| `Sig`     | float | The signal level for the last message received from the aircraft, as reported by the receiver. Not all receivers pass signal levels. The value's units are receiver-dependent. |
| `Spd`     | float | The ground speed in knots. |
| `TAlt`    | float | The target altitude, in feet, set on the autopilot / FMS etc. |
| `TTrk`    | float | The track or heading currently set on the aircraft's autopilot or FMS. |
| `Trak`    | float | Aircraft's track angle across the ground clockwise from 0° north. |
| `Trt`     | float | Transponder type - `0`=Unknown, `1`=Mode-S, `2`=ADS-B (unknown version), `3`=ADS-B 0, `4`=ADS-B 1, `5`=ADS-B 2. |
| `Vsi`     | float | Vertical speed in feet per minute. |

### `autogain` Measurement

| Tag Key | Type | Description |
|---------|------|-------|
| `host`  | String | The hostname of the container. |

| Field Key | Type  | Description |
|-----------|-------|-------------|
| `autogain_current_value` | float | The current gain level as set by autogain. |
| `autogain_max_value` | float | The maximum gain level as set by autogain. |
| `autogain_min_value` | float | The minimum gain level as set by autogain. |
| `autogain_pct_strong_messages_max` | float | The maximum percentage of strong messages. |
| `autogain_pct_strong_messages_min` | float | The minimum percentage of strong messages. |

### `polar_range` Measurement

| Tag Key | Type | Description |
|---------|------|-------|
| `bearing` | Number | The bearing value is between `00` and `71`. Each bearing represents 5° on the compass, with `00` as North. |
| `host`  | String | The hostname of the container. |

| Field Key | Type  | Description |
|-----------|-------|-------------|
| `range` | float | The range (in metres) at a specific bearing.

### `readsb` Measurement

| Tag Key | Type | Description |
|---------|------|-------|
| `host`  | String | The hostname of the container. |

Field keys should be as-per the `StatisticEntry` message schema from [`readsb.proto`](https://github.com/Mictronics/readsb-protobuf/blob/dev/readsb.proto).

| Field Key | Type | Description |
|---------|------|-------|
| `cpr_airborne`                  | float | Total number of airborne CPR messages received |
| `cpr_global_bad`                | float | Global positions that were rejected because they were inconsistent |
| `cpr_global_ok`                 | float | Global positions successfuly derived |
| `cpr_global_range`              | float | Global positions that were rejected because they exceeded the receiver max range |
| `cpr_global_skipped`            | float | Global position attempts skipped because we did not have the right data (e.g. even/odd messages crossed a zone boundary) |
| `cpr_global_speed`              | float | Global positions that were rejected because they failed the inter-position speed check |
| `cpr_local_aircraft_relative`   | float | Local positions found relative to a previous aircraft position |
| `cpr_local_ok`                  | float | Local (relative) positions successfully found |
| `cpr_local_range`               | float | Local positions not used because they exceeded the receiver max range or fell into the ambiguous part of the receiver range |
| `cpr_local_skipped`             | float | Local (relative) positions not used because we did not have the right data |
| `cpr_local_speed`               | float | Local positions not used because they failed the inter-position speed check |
| `cpr_surface`                   | float | Total number of surface CPR messages received |
| `cpu_background`                | float | Milliseconds spent doing network I/O, processing received network messages, and periodic tasks. |
| `cpu_demod`                     | float | Milliseconds spent doing demodulation and decoding in response to data from a SDR dongle. |
| `cpu_reader`                    | float | Milliseconds spent reading sample data over USB from a SDR dongle. |
| `local_accepted`                | float | The number of valid Mode S messages accepted from a local SDR with N-bit errors corrected. |
| `local_modeac`                  | float | Number of Mode A / C messages decoded. |
| `local_modes`                   | float | Number of Mode S preambles received. This is *not* the number of valid messages! |
| `local_noise`                   | float | Calculated receiver noise floor level. |
| `local_peak_signal`             | float | Peak signal power of a successfully received message, in dbFS; always negative. |
| `local_samples_dropped`         | float | Number of sample blocks dropped before processing. A nonzero value means CPU overload. |
| `local_samples_processed`       | float | Number of sample blocks processed. |
| `local_signal`                  | float | Mean signal power of successfully received messages, in dbFS; always negative. |
| `local_strong_signals`          | float | Number of messages received that had a signal power above -3dBFS. |
| `local_unknown_icao`            | float | Number of Mode S messages which looked like they might be valid but we didn't recognize the ICAO address and it was one of the message types where we can't be sure it's valid in this case. |
| `max_distance_in_metres`        | float | Maximum range in metres |
| `max_distance_in_nautical_miles`| float | Maximum range in nautical miles |
| `messages`                      | float | Total number of messages accepted by readsb from any source |
| `remote_accepted`               | float | Number of valid Mode S messages accepted over the network with N-bit errors corrected. |
| `remote_modeac`                 | float | Number of Mode A / C messages received. |
| `remote_modes`                  | float | Number of Mode S messages received. |
| `tracks_mlat_position`          | float | Tracks consisting of a position derived from MLAT |
| `tracks_new`                    | float | Total tracks (aircrafts) created. Each track represents a unique aircraft and persists for up to 5 minutes. |
| `tracks_single_message`         | float | Tracks consisting of only a single message. These are usually due to message decoding errors that produce a bad aircraft address. |
| `tracks_with_position`          | float | Tracks consisting of a position. |

## Getting help

Please feel free to [open an issue on the project's GitHub](https://github.com/mikenye/docker-readsb-protobuf/issues).

I also have a [Discord channel](https://discord.gg/sTf9uYF), feel free to [join](https://discord.gg/sTf9uYF) and converse.

## Changelog

See the project's [commit history](https://github.com/mikenye/docker-readsb-protobuf/commits/main).
