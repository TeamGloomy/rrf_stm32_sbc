# rrf_stm32_sbc

Armbian image build files for running RepRapFirmware (RRF) with Duet Software Framework (DSF) on an SBC connected to an STM32 based board.

## rrf_upgrade

The Armbian image ships with the `rrf_upgrade` command (installed as `/usr/local/bin/rrf_upgrade`, source: [`armbian/userpatches/overlay/rrf_upgrade.sh`](armbian/userpatches/overlay/rrf_upgrade.sh)). It installs or switches the Duet packages (DuetControlServer, DuetWebControl, RepRapFirmware, ...) and the matching TeamGloomy board firmware.

What it does:

- Switches the apt repository to the Duet3D **stable** or **unstable** channel.
- Installs the latest release of that channel, or a specific version.
- Backs up and restores your board configuration in `/opt/dsf/conf/config.json` (`SpiDevice`, `GpioChipDevice`, `TransferReadyPin`, `CommunicationMethod`) so an upgrade doesn't reset it.
- Switches between **SPI** and **USB** communication with the board.
- Checks that `duetcontrolserver` is running afterwards and prints its log if not.
- Updates itself: on each run it checks GitHub for a newer version of the script and re-runs itself after updating.

The script needs root; if you run it as a normal user it re-runs itself with `sudo`.

### Interactive mode

Run it without arguments:

```bash
rrf_upgrade
```

A menu shows the installed DSF version, the current channel and the current communication method:

```
  ____   ____   _____
 |  _ \ |  _ \ |  ___|
 | |_) || |_) || |_
 |  _ < |  _ < |  _|
 |_| \_\|_| \_\|_|

  TeamGloomy RRF Upgrade Utility v0.2.1
  Installed DSF: 3.5.2
  Channel: stable   Comms: spi


=== Configuration ===
Select Release Channel:
  1) Stable   (Recommended)
  2) Unstable (Bleeding Edge)
  3) Switch SPI/USB Communication
  4) Restart Services
  5) Exit

Enter choice [1-5]:
```

| Choice | Action |
|--------|--------|
| 1 / 2 | Install from the stable / unstable channel (see below) |
| 3 | Change the communication method only, no packages are touched |
| 4 | Restart the Duet services and run the health check |
| 5 | Exit |

**Installing (1 or 2).** The script refreshes the package list for the chosen channel and lists the available versions, newest first, with the RRF and DWC versions each one contains. Pick `0` for the latest release, a number for a specific version, `a` to show all versions, `b` to go back or `x` to exit.

```
=== Select Version ===
  0) Latest stable (Recommended)
  1) 3.5.2          RRF 3.5.2        DWC 3.5.2
  2) 3.5.1          RRF 3.5.1        DWC 3.5.1
  ...
  a) Show all 24 versions
  b) Back
  x) Exit

Select version to install [0-15, a, b or x]:
```

You are then asked for the communication method (keep current, SPI or USB), shown a summary, and asked to confirm before anything changes:

```
=== Communication Method ===
  1) Keep current (spi)
  2) SPI
  3) USB

Enter choice [1-3, default 1]: 1

=== Summary ===
[INFO] Channel: stable
[INFO] Version: latest-stable
[INFO] Comms:   keep current
[WARN] Duet services will be stopped during the upgrade.
Proceed with installation? [y/N to Exit]
```

The Duet services are stopped while the packages are installed and started again at the end.

> The listings above are examples; the versions you see depend on what the Duet3D repository currently offers. Screenshots of a real run on a board can be added to a `docs/` folder and linked here.

### Command line mode

For scripting or quick use, pass the arguments directly:

```
rrf_upgrade <RRF_version> [--comms spi|usb]
rrf_upgrade set-comms spi|usb
```

| Argument | Description |
|----------|-------------|
| *(none)* | Interactive menu (see above). Needs a terminal; with piped input it prints the usage and exits. |
| `latest-stable` | Install the latest release from the stable channel. |
| `latest-unstable` | Install the latest release from the unstable channel. |
| `<RRF_version>` | Install a specific version from the unstable channel, e.g. `3.4-b7`. Use the package version as listed by the interactive menu. |
| `--comms spi\|usb` | Optional, used with a version. Also switch the communication method during the upgrade. If omitted, the current method is kept. |
| `set-comms spi\|usb` | Only switch the communication method. No packages are installed or changed; the Duet services are restarted. |

Examples:

```bash
# Latest stable release, keeping the current communication method
rrf_upgrade latest-stable

# Latest unstable release and switch to USB at the same time
rrf_upgrade latest-unstable --comms usb

# A specific version
rrf_upgrade 3.4-b7

# Just change from SPI to USB (or back), no upgrade
rrf_upgrade set-comms usb
rrf_upgrade set-comms spi
```

### SPI and USB communication

The communication method is stored as `CommunicationMethod` in `/opt/dsf/conf/config.json`.

- **SPI**: the board is connected to the SBC over SPI. Nothing else is changed.
- **USB**: the board is connected over USB. In addition to `CommunicationMethod`, the script sets `"UsbDevice": "/dev/serial/by-id/usb-Duet_3D_Duet-if02"`, adding the line if it is missing.

The previous `config.json` is kept as `config.json.bak`.

### Exit status

The script exits with a non-zero status for invalid arguments, and `check_health` reports an error if `duetcontrolserver` is not running after the change.
