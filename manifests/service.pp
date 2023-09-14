# @summary Manage the Netbox and Netvox-rq Systemd services
#
# @param install_root
#   The directory where the netbox installation is unpacked
#
# @param user
#   The user running the
#   service.
#
# @param group
#   The group running the
#   service.
#
# A class for running Netbox as a Systemd service
#
class netbox::service (
  Stdlib::Absolutepath $install_root,
  String $user,
  String $group,
){

  $netbox_pid_file = '/var/tmp/netbox.pid'

  $service_params_netbox_rq = {
    'netbox_home'  => "${install_root}/netbox",
    'user'         => $user,
    'group'        => $group,
  }

  $service_params_netbox = {
    'netbox_home'  => "${install_root}/netbox",
    'user'         => $user,
    'group'        => $group,
    'pidfile'      => $netbox_pid_file,
  }

  file { 'netbox-rq.service':
    path    => '/etc/systemd/system/netbox-rq.service',
    ensure  => 'present',
    content => epp('netbox/netbox-rq.service.epp', $service_params_netbox_rq),
    mode    => '0644',
    owner   => 'root',
    group   => 'root',
  }
  -> service { 'netbox-rq.service':
      ensure => 'running',
  }

  file { 'netbox.service':
    path    => '/etc/systemd/system/netbox.service',
    ensure  => 'present',
    content => epp('netbox/netbox.service.epp', $service_params_netbox),
    mode    => '0644',
    owner   => 'root',
    group   => 'root',
  }
  -> service { 'netbox.service':
      ensure => 'running',
  }

}
