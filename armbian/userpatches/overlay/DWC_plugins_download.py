#!/usr/bin/env python3

import requests
from pathlib import Path


def download_plugin_from_github(author: str, repo: str, plugin_id: str):
    asset_url = get_github_asset_url(author, repo)
    r = requests.get(asset_url)
    # The name has to be the plugin identifier
    # so it can be used to start the plugin during first boot
    plugins_dl_path = f'/usr/lib/teamgloomy/dwc-plugins/{plugin_id}.zip'
    with open(plugins_dl_path, 'wb') as f:
        f.write(r.content)


def get_github_asset_url(author: str, repo: str) -> str:
    url = f'https://api.github.com/repos/{author}/{repo}/releases/latest'
    r = requests.get(url).json()
    return r['assets'][0]['browser_download_url']


def main():
    # github author, github repository name, plugin identifier
    plugins = [
        ('LoicGRENON', 'DSF_ExecOnMcode_Plugin', 'ExecOnMcode'),
        ('MintyTrebor', 'BtnCmd', 'BtnCmd'),
    ]
    for plugin in plugins:
        download_plugin_from_github(*plugin)


if __name__ == "__main__":
    main()
