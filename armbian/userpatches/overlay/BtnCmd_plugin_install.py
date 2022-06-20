# -*- coding: utf-8 -*-

from pathlib import Path
import json
import os
import pwd
import requests
import shutil
import subprocess
import zipfile


PLUGIN_DIR = '/opt/dsf/plugins'
BASE_DIR = '/opt/dsf/sd'
APPARMOR_PARSER = '/usr/sbin/apparmor_parser'
APPARMOR_PROFILE_DIR = '/etc/apparmor.d'
APPARMOR_TEMPLATE = '/opt/dsf/conf/apparmor.conf'


def get_asset_url():
    url = 'https://api.github.com/repos/MintyTrebor/BtnCmd/releases/latest'
    r = requests.get(url).json()
    return r['assets'][0]['browser_download_url']


def download_plugin():
    asset_url = get_asset_url()
    r = requests.get(asset_url)
    zip_archive = Path('/opt/dsf/') / 'plugin.zip'
    open(zip_archive, 'wb').write(r.content)
    return zip_archive


def json_filter(x, y):
    return dict([(i, x[i]) for i in x if i.lower() in set(y)])


def parse_manifest(zip_archive):
    with zip_archive.open('plugin.json') as manifest_file:
        raw_json = json.load(manifest_file)

    # Convert JSON keys into lowercase
    raw_json = dict((k.lower(), v) for k, v in raw_json.items())

    # See https://github.com/Duet3D/DuetSoftwareFramework/blob/master/src/DuetAPI/ObjectModel/Plugins/PluginManifest.cs
    manifest_json = {
        'dsfFiles': [],
        'dwcFiles': [],
        'sdFiles': [],
        'pid': -1,
        'id': None,
        'name': None,
        'author': None,
        'version': None,
        'license': None,
        'homepage': None,
        'dwcVersion': None,
        'dwcDependencies': [],
        'sbcRequired': False,
        'sbcDsfVersion': None,
        'sbcExecutable': None,
        'sbcExecutableArguments': None,
        'sbcExtraExecutables': [],
        'sbcOutputRedirected': True,
        'sbcPermissions': [],
        'sbcPackageDependencies': [],
        'sbcPythonDependencies': [],
        'sbcPluginDependencies': [],
        'rrfVersion': None,
        'data': {}
    }

    for key in manifest_json.keys():
        if key in ['dsf_files', 'dwc_files', 'sd_files', 'pid']:
            continue

        try:
            manifest_json[key] = raw_json[key.lower()]
        except KeyError:
            pass

    return manifest_json


def __select_dsf_user():
    pw = pwd.getpwnam('dsf')
    os.setgid(pw.pw_gid)
    os.setuid(pw.pw_uid)


def __install_web_files(manifest_json):
    for file in manifest_json['dwcFiles']:
        src = Path(PLUGIN_DIR) / manifest_json['id'] / 'dwc' / file
        dst = Path(BASE_DIR) / 'www' / file
        shutil.copyfile(src, dst)


def __install_plugin_manifest(manifest_json):
    manifest_filename = Path(PLUGIN_DIR) / f"{manifest_json['id']}.json"
    with open(manifest_filename, 'w') as f:
        json.dump(manifest_json, f, ensure_ascii=False)
    return manifest_filename


def __install_plugin_package_dependencies(manifest_json):
    # https://github.com/Duet3D/DuetSoftwareFramework/blob/6b59f8408b6edb2ecde9d5371631bc5f50edbcce/src/DuetPluginService/Commands/InstallPlugin.cs#L56
    # TODO: Install package dependencies
    pass


def __install_plugin_python_dependencies(manifest_json):
    # https://github.com/Duet3D/DuetSoftwareFramework/blob/6b59f8408b6edb2ecde9d5371631bc5f50edbcce/src/DuetPluginService/Commands/InstallPlugin.cs#L62
    # TODO: Install python dependencies
    pass


def __install_plugin_security_profile(manifest_json):
    # https://github.com/Duet3D/DuetSoftwareFramework/blob/6b59f8408b6edb2ecde9d5371631bc5f50edbcce/src/DuetPluginService/Commands/InstallPlugin.cs#L68
    # https://github.com/Duet3D/DuetSoftwareFramework/blob/6b59f8408b6edb2ecde9d5371631bc5f50edbcce/src/DuetPluginService/Permissions/AppArmor.cs#L23

    # Read AppArmor profile template
    with open(APPARMOR_TEMPLATE) as f:
        profile = f.read()

    plugin_directory = str(Path(PLUGIN_DIR) / manifest_json['id'])
    # TODO: get includes and rules according to SbcPermissions values
    # See https://github.com/Duet3D/DuetSoftwareFramework/blob/6b59f8408b6edb2ecde9d5371631bc5f50edbcce/src/DuetPluginService/Permissions/AppArmor.cs#L30
    includes = ''
    rules = ''

    profile  = profile.replace('{pluginDirectory}', plugin_directory)
    profile  = profile.replace('{includes}', includes)
    profile  = profile.replace('{rules}', rules)

    # Write AppArmor profile
    profile_path = Path(APPARMOR_PROFILE_DIR) / f"dsf.{manifest_json['id']}"
    with open(profile_path, 'w') as f:
        f.write(profile)

    # Reload AppArmor profile
    subprocess.run([APPARMOR_PARSER, '-r', profile_path], stdout=subprocess.DEVNULL)

    __select_dsf_user()


def install_plugin(zip_file):
    with zipfile.ZipFile(zip_file, mode='r') as archive:
        plugin_manifest = parse_manifest(archive)
        plugin_base = Path(PLUGIN_DIR) / plugin_manifest['id']

        # TODO: Check DSF/DWC version are correct

        __install_plugin_package_dependencies(plugin_manifest)
        __install_plugin_python_dependencies(plugin_manifest)
        __install_plugin_security_profile(plugin_manifest)
        __select_dsf_user()

        for file in archive.namelist():
            # See https://github.com/Duet3D/DuetSoftwareFramework/blob/78c784a328e549dcb885eb9871af89e1781dc407/src/DuetPluginService/Commands/InstallPlugin.cs#L113
            if file.endswith('/'):
                # Skip directories
                continue
            elif file.startswith('dsf/'):
                # Put DSF plugin files into <PluginDirectory>/<PluginName>/dsf
                extract_path = plugin_base
                plugin_manifest['dsfFiles'].append(file[4:])
            elif file.startswith('dwc/'):
                # Put DWC plugin files into <PluginDirectory>/<PluginName>/dwc
                extract_path = plugin_base
                plugin_manifest['dwcFiles'].append(file[4:])
            elif file.startswith('sd/'):
                # Put SD files into 0:/
                extract_path = Path(BASE_DIR)
                plugin_manifest['sdFiles'].append(file[3:])
            else:
                # Skip all others files
                continue

            archive.extract(file, extract_path)
        __install_web_files(plugin_manifest)
        __install_plugin_manifest(plugin_manifest)
    return plugin_manifest


def enable_plugin(plugin_manifest):
    dwc_settings_path = Path(BASE_DIR) / 'sys/dwc-settings.json'
    if dwc_settings_path.is_file():
        with open(dwc_settings_path) as f:
            dwc_settings = json.load(f)
    else:  # DWC settings files doesn't exists (default)
        dwc_settings = {'machine': {'enabledPlugins': []}}

    # Enable plugin
    dwc_settings['machine']['enabledPlugins'].append(plugin_manifest['id'])
    # Update settings file
    with open(dwc_settings_path, 'w') as f:
        json.dump(dwc_settings, f, ensure_ascii=False)


def main():
    plugin_archive = download_plugin()
    plugin_manifest = install_plugin(plugin_archive)
    enable_plugin(plugin_manifest)
    # Clean files
    os.remove(plugin_archive)


if __name__ == '__main__':
    main()
