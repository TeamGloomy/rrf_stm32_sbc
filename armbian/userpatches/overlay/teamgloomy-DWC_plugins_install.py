#!/usr/bin/env python3

from pathlib import Path
from dsf.connections import CommandConnection


def main():
    cmd_conn = CommandConnection()
    cmd_conn.connect()

    # github author, github repository name, plugin identifier
    plugins = [
        ('LoicGRENON', 'DSF_ExecOnMcode_Plugin', 'ExecOnMcode'),
        ('MintyTrebor', 'BtnCmd', 'BtnCmd'),
    ]
    plugins_dl_path = '/usr/lib/teamgloomy/dwc-plugins/'
    for plugin in Path(plugins_dl_path).glob('*.zip'):
        res = cmd_conn.install_plugin(str(plugin))
        if res is None:
            cmd_conn.start_plugin(plugin.stem)


if __name__ == "__main__":
    main()
