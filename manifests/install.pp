# @summary Installs Netbox
#
# Installs Netbox
#
# @param install_root
#   The directory where the netbox installation is unpacked
#
# @param version
#   The version of Netbox. This must match the version in the
#   tarball. This is used for managing files, directories and paths in
#   the service.
#
# @param download_url
#   Where to download the binary installation tarball from.
#
# @param download_checksum
#   The expected checksum of the downloaded tarball. This is used for
#   verifying the integrity of the downloaded tarball.
#
# @param download_checksum_type
#   The checksum type of the downloaded tarball. This is used for
#   verifying the integrity of the downloaded tarball.
#
# @param download_tmp_dir
#   Temporary directory for downloading the tarball.
#
# @param user
#   The user owning the Netbox installation files, and running the
#   service.
#
# @param group
#   The group owning the Netbox installation files, and running the
#   service.
#
# @param install_method
#   Method for getting the Netbox software
#
# @param install_dependencies_from_filesystem
#   Used if your machine can't reach the place pip would normally go to fetch dependencies
#   as it would when running "pip install -r requirements.txt". Then you would have to
#   fetch those dependencies beforehand and put them somewhere your machine can reach.
#   This can be done by running (on a machine that can reach pip's normal sources) the following:
#   pip download -r <requirements.txt>  -d <destination>
#   Remember to do this on local_requirements.txt also if you have one.
#
# @param python_dependency_path
#   Path to where pip can find packages when the variable $install_dependencies_from_filesystem is true
#
# @example
#   include netbox::install
class netbox::install (
  Stdlib::Absolutepath $install_root,
  String $version,
  String $download_url,
  String $download_checksum,
  String $download_checksum_type,
  Stdlib::Absolutepath $download_tmp_dir,
  String $user,
  String $group,
  String $python_executable,
  Boolean $install_dependencies_from_filesystem,
  Stdlib::Absolutepath $python_dependency_path,
  Enum['tarball', 'git_clone'] $install_method = 'tarball',
) {

  $packages =[
    'gcc',
    'python3.11',
    'python3.11-devel',
    'libxml2-devel',
    'libxslt-devel',
    'libffi-devel',
    'openssl-devel',
    'redhat-rpm-config',
    'openldap-devel'
  ]

  $local_tarball = "${download_tmp_dir}/netbox-${version}.tar.gz"
  $software_directory_with_version = "${install_root}/netbox-${version}"
  $software_directory = "${install_root}/netbox"
  $venv_dir = "${software_directory}/venv"

  ensure_packages($packages)

  user { $user:
    system => true,
    gid    => $group,
    home   => $software_directory,
  }

  group { $group:
    system => true,
  }

  if $install_dependencies_from_filesystem {
    $install_requirements_command       = "${venv_dir}/bin/pip3 install -r requirements.txt --no-index --find-links ${python_dependency_path}"
    $install_local_requirements_command = "${venv_dir}/bin/pip3 install -r local_requirements.txt --no-index --find-links ${python_dependency_path}"
  } else {
    $install_requirements_command       = "${venv_dir}/bin/pip3 install -r requirements.txt"
    $install_local_requirements_command = "${venv_dir}/bin/pip3 install -r local_requirements.txt"
  }

  archive { $local_tarball:
      source        => $download_url,
      checksum      => $download_checksum,
      checksum_type => $download_checksum_type,
      extract       => true,
      extract_path  => $install_root,
      creates       => $software_directory_with_version,
      cleanup       => true,
      notify        => Exec['install python requirements'],
    }

    exec { 'netbox permission':
      command     => "chown -R ${user}:${group} ${software_directory_with_version}",
      path        => ['/usr/bin'],
      subscribe   => Archive[$local_tarball],
      refreshonly => true,
    }

  file { $software_directory:
    ensure => 'link',
    target => $software_directory_with_version,
  }

  file { 'upgrade_script':
    ensure => 'present',
    owner  => $user,
    group  => $group,
    mode   => '0775',
    path   => "${software_directory}/upgrade.sh",
    source => 'upgrade.sh',
  }

  file { 'local_requirements':
    ensure => 'present',
    owner  => $user,
    group  => $group,
    mode   => '0644',
    path   => "${software_directory}/local_requirements.txt",
    source => 'local_requirements.txt',
    notify  => Exec['install local python requirements'],
  }

  exec { "python_venv_${venv_dir}":
    command => "${python_executable} -m venv ${venv_dir}",
    user    => $user,
    creates => "${venv_dir}/bin/activate",
    cwd     => '/tmp',
    unless  => "/usr/bin/grep '^[\\t ]*VIRTUAL_ENV=[\\\\'\\\"]*${venv_dir}[\\\"\\\\'][\\t ]*$' ${venv_dir}/bin/activate",
  }
  ~>exec { 'install python requirements':
    cwd         => $software_directory,
    path        => [ "${venv_dir}/bin", '/usr/bin', '/usr/sbin' ],
    environment => ["VIRTUAL_ENV=${venv_dir}"],
    provider    => shell,
    user        => $user,
    command     => $install_requirements_command,
    onlyif      => "/usr/bin/grep '^[\\t ]*VIRTUAL_ENV=[\\\\'\\\"]*${venv_dir}[\\\"\\\\'][\\t ]*$' ${venv_dir}/bin/activate",
    refreshonly => true,
  }
  ~>exec { 'install local python requirements':
    cwd         => $software_directory,
    path        => [ "${venv_dir}/bin", '/usr/bin', '/usr/sbin' ],
    environment => ["VIRTUAL_ENV=${venv_dir}"],
    provider    => shell,
    user        => $user,
    command     => $install_local_requirements_command,
    onlyif      => "/usr/bin/grep '^[\\t ]*VIRTUAL_ENV=[\\\\'\\\"]*${venv_dir}[\\\"\\\\'][\\t ]*$' ${venv_dir}/bin/activate",
    refreshonly => true,
  }
}
