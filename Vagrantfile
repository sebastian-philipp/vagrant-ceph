# -*- mode: ruby -*-
# vi: set ft=ruby :

# You may want to enable this line if you're using libvirt and have trouble using 'vagrant destroy'.
# For more information see https://github.com/vagrant-libvirt/vagrant-libvirt/issues/561
# ENV['VAGRANT_DEFAULT_PROVIDER'] = 'libvirt'

# Ensures that the admin node is provisioned last by disabling the simultaneous deployment.
ENV['VAGRANT_NO_PARALLEL'] = 'yes'

require 'yaml'
require 'pp'

### Not working within Vagrant ###
# require 'archive/tar/minitar'

require_relative 'lib/settings.rb'
require_relative 'lib/hosts.rb'
require_relative 'lib/provisions.rb'

config_file = 'config.yml'
yml_config = YAML.load_file(config_file)

# Check that the user has an ssh key
Vagrant::Hosts::check_for_ssh_keys

# Set BOX to one of 'openSUSE-13.2', 'Tumbleweed', 'SLE-12'
BOX = 'opensuse/openSUSE-42.1-x86_64'

# Set INSTALLATION to one of 'ceph-deploy', 'vsm'
INSTALLATION = 'salt'

# Set CONFIGURATION to one of 'default', 'small', 'iscsi' or 'economical'
CONFIGURATION = 'small'

raise "Box #{BOX} missing from config.yml" unless yml_config[BOX]
raise "Installation #{INSTALLATION} missing for box #{BOX} from config.yml" unless yml_config[BOX][INSTALLATION]
raise "Configuration #{CONFIGURATION} missing from config.yml" unless yml_config[CONFIGURATION]

# Set PREFIX for additional sets of VMs in libvirt from a separate directory
# (e.g. vagrant-ceph is default, vsm is another git clone with PREFIX='v'
# hostnames will be 'vadmin', 'vmon1', etc.  Both sets use same address range
# and cannot run simultaneously.  Each set will consume disk space. )
PREFIX = ''

# Generates a hosts file
if INSTALLATION == 'salt'
    hosts = Vagrant::Hosts.new(yml_config[CONFIGURATION]['nodes'], selected = 'public', domain='ceph',
                               aliases={'admin' => 'salt'})
elsif INSTALLATION == 'openattic'
    hosts = Vagrant::Hosts.new(yml_config[CONFIGURATION]['nodes'], selected = 'public', domain='ceph')
else
    hosts = Vagrant::Hosts.new(yml_config[CONFIGURATION]['nodes'])
end

def provisioning(hosts, node, yml_config, name)
    # Update /etc/hosts on each node
    hosts.update(node)

    # Allow passwordless root access between nodes
    keys = Vagrant::Keys.new(node, yml_config[CONFIGURATION]['nodes'].keys)
    keys.authorize if name == 'admin'

    # Add missing repos
    repos = Vagrant::Repos.new(node, yml_config[BOX][INSTALLATION]['repos'])
    repos.add

    # Copy custom files
    files = Vagrant::Files.new(node, INSTALLATION, name, yml_config[BOX][INSTALLATION]['files'])
    files.copy

    # Install additional/unique packages
    pkgs = Vagrant::Packages.new(node, name, yml_config[BOX][INSTALLATION]['packages'])
    pkgs.install

    # Run commands
    commands = Vagrant::Commands.new(node, name, yml_config[BOX][INSTALLATION]['commands'])
    commands.run
end

# All Vagrant configuration is done below. The "2" in Vagrant.configure
# configures the configuration version (we support older styles for
# backwards compatibility). Please don't change it unless you know what
# you're doing.
Vagrant.configure(2) do |config|
    config.vm.provider :libvirt do |lv|
        # May be necessary to use 'qemu' here on some mainboards where 'kvm' doesn't work through a bug. 'qemu' seems to
        # work on all machines, but it looks like it's slower than 'kvm'.
        # See OP-1455 (https://tracker.openattic.org/browse/OP-1455) for more information.
        lv.driver = 'kvm'
    end
    config.vm.box = BOX

    # config.vm.define 'openattic' do |oa|
    #
    #     ## Network ##
    #
    #     oa.vm.network 'private_network', ip: '192.168.10.101'
    #
    #     ## Shared folders ##
    #
    #     oa.vm.synced_folder '..', '/home/vagrant/openattic', type: 'nfs',
    #                         :mount_options => ['nolock,vers=3,udp,noatime,actimeo=1']
    #     oa.vm.synced_folder '.', '/vagrant', disabled: true # Disable default
    #
    #     ## Memory ##
    #
    #     [:virtualbox, :libvirt].each do |provider|
    #         oa.vm.provider provider do |p|
    #             p.memory = 1024
    #             p.cpus = 2
    #         end
    #     end
    #
    #     ## Disks ##
    #
    #     oa.vm.provider :virtualbox do |vb|
    #         # note 1 would mean 2 disks
    #         disk_num = 1
    #         disk_size = 2 * 1024
    #         for i in 0..disk_num do
    #             file_to_disk = "./disks/box-disk#{i}.vmdk"
    #             unless File.exist?(file_to_disk)
    #                 vb.customize ['createhd', '--filename', file_to_disk, '--size', disk_size]
    #             end
    #             # comment this out after provision -> find solution for this
    #             vb.customize ['storageattach', :id, '--storagectl', 'SATA Controller', '--port',
    #                           i + 1, '--device', 0, '--type', 'hdd', '--medium', file_to_disk]
    #         end
    #     end
    #
    #     oa.vm.provider :libvirt do |libvirt|
    #         libvirt.storage :file, :size => '2G', :bus => 'scsi'
    #         libvirt.storage :file, :size => '2G', :bus => 'scsi'
    #     end
    #
    #     ## Provisioning ##
    #
    #     # oa.vm.provision :shell, :path => 'install.sh' # TODO uncomment before commit, temporarily commented out
    #
    #     ## Cache ##
    #
    #     if Vagrant.has_plugin?('vagrant-cachier')
    #         # Configure cached packages to be shared between instances of the same base box.
    #         # More info on http://fgrehm.viewdocs.io/vagrant-cachier/usage
    #         oa.cache.scope = :box
    #
    #         # OPTIONAL: If you are using VirtualBox, you might want to use that to enable
    #         # NFS for shared folders. This is also very useful for vagrant-libvirt if you
    #         # want bi-directional sync
    #         oa.cache.synced_folder_opts = {
    #             type: :nfs,
    #             # The nolock option can be useful for an NFSv3 client that wants to avoid the
    #             # NLM sideband protocol. Without this option, apt-get might hang if it tries
    #             # to lock files needed for /var/cache/* operations. All of this can be avoided
    #             # by using NFSv4 everywhere. Please note that the tcp option is not the default.
    #             mount_options: ['rw', 'vers=3', 'tcp', 'nolock']
    #         }
    #         # For more information please check http://docs.vagrantup.com/v2/synced-folders/basic_usage.html
    #     end
    #     # config.cache.enable :pip
    #     oa.cache.enable :zypper
    #     oa.cache.enable :npm
    #     oa.cache.enable :bower
    # end

    nodes = yml_config[CONFIGURATION]['nodes'].keys
    # Ensure that the admin node is provisioned last (this works in conjunction with disabling the
    # paralell provisioning mode of vagrant)
    nodes.insert(-1, nodes.delete('admin'))

    nodes.each do |name|
        vm_name = PREFIX + name

        config.vm.define vm_name do |node|
            common_settings(node, yml_config, name)

            node.vm.provider :libvirt do |l|
                libvirt_settings(l, yml_config, name)
            end

            node.vm.provider :virtualbox do |vb|
                virtbox_settings(vb, yml_config, name)
            end

            provisioning(hosts, node, yml_config, name)
        end
    end
end
