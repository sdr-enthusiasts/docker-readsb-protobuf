# mikenye/readsb-protobuf

[Mictronics' `readsb-protobuf`](https://github.com/Mictronics/readsb-protobuf) Mode-S/ADSB/TIS decoder for RTLSDR, BladeRF, Modes-Beast and GNS5894 devices, running in a docker container.

This version uses Google's protocol buffer for data storage and exchange with web application. Saves on storage space and bandwidth.

This container also contains InfluxData's [Telegraf](https://docs.influxdata.com/telegraf/), and can send flight data and `readsb` metrics to InfluxDB (if wanted - not started by default).

Support for all supported SDRs is compiled in. Builds and runs on x86_64, arm32v7 and arm64v8 (see below).

This image will configure a software-defined radio (SDR) to receive and decode Mode-S/ADSB/TIS data from aircraft within range, for use with other services such as:

* `mikenye/adsbexchange` to feed ADSB data to [adsbexchange.com](https://adsbexchange.com)
* `mikenye/adsbhub` to feed ADSB data into [adsbhub.org](https://adsbhub.org/)
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

## Readme

The README for this container is too long for Dockerhub. Please [view the README on this image's GitHub repository](https://github.com/mikenye/docker-readsb-protobuf/blob/main/README.md).

## Getting help

Please feel free to [open an issue on the project's GitHub](https://github.com/mikenye/docker-readsb-protobuf/issues).

I also have a [Discord channel](https://discord.gg/sTf9uYF), feel free to [join](https://discord.gg/sTf9uYF) and converse.

## Changelog

See the project's [commit history](https://github.com/mikenye/docker-readsb-protobuf/commits/main).
