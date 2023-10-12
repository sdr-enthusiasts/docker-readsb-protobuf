# sdr-enthusiasts/docker-readsb-protobuf

[![Docker Image Size (tag)](https://img.shields.io/docker/image-size/mikenye/readsb-protobuf/latest)](https://hub.docker.com/r/mikenye/readsb-protobuf)
[![Discord](https://img.shields.io/discord/734090820684349521)](https://discord.gg/sTf9uYF)

[Mictronics' `readsb-protobuf`](https://github.com/Mictronics/readsb-protobuf) Mode-S/ADSB/TIS decoder for RTLSDR, BladeRF, Modes-Beast and GNS5894 devices, running in a docker container.

This version uses Google's protocol buffer for data storage and exchange with web application. Saves on storage space and bandwidth.

This container also contains InfluxData's [Telegraf](https://docs.influxdata.com/telegraf/), and can send flight data and `readsb` metrics to InfluxDB (if wanted - not started by default).

Support for all supported SDRs is compiled in. Builds and runs on x86_64, arm32v7 and arm64v8 (see below).

This image will configure a software-defined radio (SDR) to receive and decode Mode-S/ADSB/TIS data from aircraft within range, for use with other services such as:

- [`sdr-enthusiasts/docker-adsbexchange`](https://github.com/sdr-enthusiasts/docker-adsbexchange) to feed ADSB data to [adsbexchange.com](https://adsbexchange.com)
- [`sdr-enthusiasts/docker-adsbhub`](https://github.com/sdr-enthusiasts/docker-adsbhub) to feed ADSB data into [adsbhub.org](https://adsbhub.org/)
- [`sdr-enthusiasts/docker-piaware`](https://github.com/sdr-enthusiasts/docker-piaware) to feed ADSB data into [flightaware.com](https://flightaware.com)
- [`sdr-enthusiasts/docker-flightradar24`](https://github.com/sdr-enthusiasts/docker-flightradar24) to feed ADSB data into [flightradar24.com](https://www.flightradar24.com)
- [`sdr-enthusiasts/docker-radarbox`](https://github.com/sdr-enthusiasts/docker-radarbox) to feed ADSB data into [radarbox.com](https://www.radarbox.com)
- [`sdr-enthusiasts/docker-opensky-network`](https://github.com/sdr-enthusiasts/docker-opensky-network) to feed ADSB data into [opensky-network.org](https://opensky-network.org/)
- [`sdr-enthusiasts/docker-planefinder`](https://github.com/sdr-enthusiasts/docker-planefinder) to feed ADSB data into [planefinder.net](https://planefinder.net/)
- `mikenye/adsb-to-influxdb` to feed data into your own instance of [InfluxDB](https://docs.influxdata.com/influxdb/), for visualisation with [Grafana](https://grafana.com) and/or other tools
- Any other tools that can receive Beast, BeastReduce, Basestation or the raw data feed from `readsb` or `dump1090` and their variants

bladeRF & plutoSDR are untested - I don't own bladeRF or plutoSDR hardware (only RTL2832U as outlined above), but support for the devices is compiled in. If you have the hardware and would be willing to test, please [open an issue on GitHub](https://github.com/sdr-enthusiasts/docker-readsb-protobuf/issues).

## Readme

The README for this container is too long for Dockerhub. Please [view the README on this image's GitHub repository](https://github.com/sdr-enthusiasts/docker-readsb-protobuf/blob/main/README.md).

## Getting help

Please feel free to [open an issue on the project's GitHub](https://github.com/sdr-enthusiasts/docker-readsb-protobuf/issues).

I also have a [Discord channel](https://discord.gg/sTf9uYF), feel free to [join](https://discord.gg/sTf9uYF) and converse.

## Changelog

See the project's [commit history](https://github.com/sdr-enthusiasts/docker-readsb-protobuf/commits/main).
