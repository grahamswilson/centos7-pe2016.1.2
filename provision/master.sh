#!/bin/bash

# Perform a few steps first
export PATH=$PATH:/opt/puppetlabs/puppet/bin/

# Install Zack's r10k module
/opt/puppetlabs/puppet/bin/puppet module install 'zack-r10k'

# Install Hunner's Hiera module
/opt/puppetlabs/puppet/bin/puppet module install 'hunner-hiera'

# Stop and disable Firewalld
/bin/systemctl stop  firewalld.service
/bin/systemctl disable firewalld.service

# Place the r10k configuration file
cat > /var/tmp/configure_r10k.pp << 'EOF'
class { 'r10k':
  version           => '2.1.1',
  sources           => {
    'puppet' => {
      'remote'  => 'https://github.com/grahamswilson/control_repo.git',
      'basedir' => "${::settings::codedir}/environments",
      'prefix'  => false,
    }
  },
  manage_modulepath => false,
}
EOF

# Place the directory environments config file
cat > /var/tmp/configure_directory_environments.pp << 'EOF'
######                           ######
##  Configure Directory Environments ##
######                           ######

# Default for ini_setting resources:
Ini_setting {
  ensure => present,
  path   => "${::settings::confdir}/puppet.conf",
}

ini_setting { 'Configure environmentpath':
  section => 'main',
  setting => 'environmentpath',
  value   => '$codedir/environments',
}

ini_setting { 'Configure basemodulepath':
  section => 'main',
  setting => 'basemodulepath',
  value   => '$confdir/modules:/opt/puppetlabs/puppet/modules',
}
EOF

# Now configure Hiera
cat > /var/tmp/configure_hiera.pp << 'EOF'
class { 'hiera':
  hiera_yaml => '/etc/puppetlabs/code/hiera.yaml',
  hierarchy  => [
    'nodes/%{clientcert}',
    '%{environment}',
    'common',
  ],
  logger     => 'console',
  datadir    => '/etc/puppetlabs/code/environments/%{environment}/hieradata'
}
EOF

# Now, apply your new configuration
/opt/puppetlabs/puppet/bin/puppet apply /var/tmp/configure_r10k.pp

# Then configure directory environments
/opt/puppetlabs/puppet/bin/puppet apply /var/tmp/configure_directory_environments.pp

# Then Configure Hiera
/opt/puppetlabs/puppet/bin/puppet apply /var/tmp/configure_hiera.pp

# Move the r10k.yaml to the new location
/usr/bin/mv /etc/r10k.yaml /etc/puppetlabs/r10k/r10k.yaml

# Do the first deployment run
/opt/puppetlabs/puppet/bin/r10k deploy environment -pv
