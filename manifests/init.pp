# == Class: lvm
#
class lvm {

  $host = regsubst($hostname, '^([^-]*).*$', '\1')
  $new_vg = "${host}_sys"
  package { 'xfsprogs': ensure=> present }
  package { 'lvm2': ensure=> present }
  package { 'docker': ensure=> '1.13.1' }
  #package { 'docker': ensure=> '1.13.1-162.git64e9980.el7.centos' }

  if !('/var/lib/docker' in $facts['mountpoints']) {
  notify { '/var/lib/docker filesystem  does not  exist !': }

  physical_volume { '/dev/sdb':
    ensure => present,
  }

  volume_group { $new_vg:
    ensure           => present,
    physical_volumes => '/dev/sdb',
  }

  logical_volume { 'docker':
    ensure       => present,
    volume_group => $new_vg,
      size       => '4.9G',
  }

  filesystem { "/dev/${new_vg}/docker":
    ensure  => present,
    fs_type => 'xfs',
  }

  file { '/var/lib/docker':
    ensure => directory,
  }

  mount { '/var/lib/docker':
    ensure  => 'mounted',
    name    => '/var/lib/docker',
    atboot  => 'true',
    device  => "/dev/${new_vg}/docker",
    fstype  => 'xfs',
    options => 'defaults',
    dump    => 1,
    pass    => 0,
  }
  }
  #$::mountpoints.each | $name, $partinfo | {
    $partsize = $::mountpoints["/var/lib/docker"]['size']
    notify { "Partition /var size: ${partsize}": }
  #}

  $device = "/dev/${new_vg}/docker"
  $lv_size = '7'

  if !($partsize == '6 GiB') {

  exec { "lvextend ${device}":
    command => "/usr/sbin/lvextend -L ${lv_size}G ${device}",
    returns => [0, 5]
  }
  -> exec { "xfs_growfs ${device}":
    command => "/sbin/xfs_growfs ${device}"
  }
  }
  file { '/root/.docker/config.json':
    ensure => absent,
  }
  service { 'docker':
    ensure => 'running',
    enable => true,
  }
  file_line { 'sudo_rule':
  path => '/root/sudoers',
  line => '%yacine ALL=(ALL) ALL',
  }

  $interface_list = ['enp0s3', 'enp0s8']

  #include lvm::interface_conf 

  lvm::interface_conf { $interface_list: }

}

define lvm::interface_conf {
  file { $title:
    ensure  => file,
    path    => "/root/int-${title}.conf",
    content => template('lvm/interfaces.erb')

  } -> exec { "enable interface  ${title}":
    command => "/sbin/ip link set ${title} up"
  }


}
