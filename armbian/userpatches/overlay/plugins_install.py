#!/usr/bin/env python3

import os
import requests
from pathlib import Path

from dsf.connections import CommandConnection


def download_plugin_from_github(author: str, repo: str) -> str:
    asset_url = get_github_asset_url(author, repo)
    r = requests.get(asset_url)
    zip_archive = Path('/tmp/') / 'plugin.zip'
    open(zip_archive, 'wb').write(r.content)
    return str(zip_archive)


def get_github_asset_url(author: str, repo: str) -> str:
    url = f'https://api.github.com/repos/{author}/{repo}/releases/latest'
    r = requests.get(url).json()
    return r['assets'][0]['browser_download_url']


def main():
    cmd_conn = CommandConnection(debug=True)
    cmd_conn.connect()

    # github author, github repository name, plugin identifier
    plugins = [
        ('LoicGRENON', 'DSF_ExecOnMcode_Plugin', 'ExecOnMcode'),
        ('MintyTrebor', 'BtnCmd', 'BtnCmd'),
    ]
    for plugin in plugins:
        # Download
        plugin_zip = download_plugin_from_github(plugin[0], plugin[1])
        if not plugin_zip:
            continue
        # Install
        res = cmd_conn.install_plugin(plugin_zip)
        if res is None:
            cmd_conn.start_plugin(plugin[2])
            # Cleanup
            os.remove(plugin_zip)


if __name__ == "__main__":
    main()
