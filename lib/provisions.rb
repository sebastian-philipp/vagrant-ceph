require 'open3'
##include Archive::Tar

# Namespace for helper routines
module Vagrant

    # Adds repositories to a VM
    class Repos

        # Builds an array of commands to add each repo.
        #
        #   node - vagrant provider
        #   repos - hash of repo names and urls
        def initialize(node, repos)
            @node = node
            @cmds = []
            (repos or {}).keys.each do |repo|
                # Use shell short circuit to determine if repo already exists
                @cmds << "zypper lr \'#{repo}\' | grep -sq ^Name || zypper ar \'#{repos[repo]}\' \'#{repo}\'"
            end
        end

        # Runs all the commands in a single shell
        def add
            unless @cmds.empty?
                @node.vm.provision 'shell', inline: @cmds.join('; ')
            end
        end
    end

    # Installs additional packages
    class Packages

        # Saves arguments
        #
        #   node - vagrant provider
        #   packages - an array of package names
        def initialize(node, host, packages)
            @node = node
            @host = host
            @packages = packages
            @zypper_install = 'zypper --gpg-auto-import-keys -n --quiet in %s'
        end

        # Install packages for destined for all hosts and this host specifically
        def install
            install_all
            install_host
        end

        # Runs necessary zypper command, automatically trust repo
        def install_all
            unless @packages['all'].nil?
                cmd = @zypper_install % @packages['all'].join(' ')
                @node.vm.provision 'shell', inline: cmd
            end
        end

        # Runs necessary zypper command, automatically trust repo
        def install_host
            unless @packages[@host].nil?
                cmd = @zypper_install % @packages[@host].join(' ')
                @node.vm.provision 'shell', inline: cmd
            end
        end
    end

    # Manage keys for root account
    class Keys

        # Saves arguments and call setup
        #
        #   node - vagrant provider
        #   servers - all the hostnames in the cluster
        def initialize(node, servers)
            @node = node
            @servers = servers
            setup
        end

        # Copy static private/public key to root account.  Run necessary shell
        # commands in a single call.
        def setup
            ['files/id_ecdsa', 'files/id_ecdsa.pub'].each do |file|
                @node.vm.provision 'file', source: file, destination: "/home/vagrant/#{File.basename(file)}"
            end
            steps = <<-END.gsub(/^ +/, '')
                mkdir -p /root/.ssh
                mv /home/vagrant/id_ecdsa /root/.ssh
                mv /home/vagrant/id_ecdsa.pub /root/.ssh
                cp /root/.ssh/id_ecdsa.pub /root/.ssh/authorized_keys
                chmod 0600 /root/.ssh/id_ecdsa
            END
            @node.vm.provision 'shell', inline: steps
        end

        # Log into each machine and accept which generates the known_hosts
        def authorize
            @servers.each do |server|
                cmd = "ssh -oStrictHostKeyChecking=no #{server} exit"
                @node.vm.provision 'shell', inline: cmd
            end
        end
    end

    # Copy files from files/install_mode to the virtual machine.  Effectively,
    # a poor man's patch after package installation to allow quick experimenting
    # until the real solution is decided
    class Files

        # Saves arguments
        #
        #   node - vm provider
        #   install_mode - type of installation
        #   host - hostname
        #   files - boolean determining if tree should be copied
        def initialize(node, install_mode, host, files)
            @node = node
            @install_mode = install_mode
            @host = host
            @files = files
        end

        # Creates a tar file, uses vagrant's copy command and then extracts
        # the file on the virtual machine.  Copies both subdirectories of all
        # and host specific trees.
        def copy
            unless @files.nil?
                ['all', @host].each do |subdir|
                    unless @files[subdir].nil?
                        # check if enabled
                        if @files[subdir]
                            tar_file = tar(subdir)
                            vm_tar_file = "/home/vagrant/#{File.basename(tar_file)}"
                            @node.vm.provision 'file', source: tar_file, destination: vm_tar_file
                            untar(vm_tar_file)
                        end
                    end
                end
            end
        end

        # Change directory and generate tar file via Minitar
        #
        #   subdir - either 'all' or hostname
        def tar(subdir)
            filename = "/tmp/#{@install_mode}-#{subdir}.tar"
            File.open(filename, 'wb') do |tar|
                dir = "files/#{@install_mode}/#{subdir}"
                if File.directory?(dir)
                    Dir.chdir(dir) do
                        cmd = "tar cf #{filename} *"
                        Open3.popen3(cmd) do |stdin, stdout, stderr, wait_thr|
                            puts stdout.readlines
                            puts stderr.readlines
                            exit unless wait_thr.value.success?
                        end
                        #Minitar.pack('*', tar)
                    end
                end
            end
            filename
        end

        # Extract files in the virtual machine
        #
        #   tar_file - path to tar file
        def untar(tar_file)
            cmd = "tar -C / -xf #{tar_file}"
            @node.vm.provision 'shell', inline: cmd
        end
    end

    # Runs necessary commands
    class Commands

        # Saves arguments
        #
        #   node - vm provider
        #   host - hostname
        #   commands - hash of all and hosts to commands
        def initialize(node, host, commands)
            @node = node
            @host = host
            @commands = commands
        end

        def run
            ['all', @host].each do |group|
                unless @commands[group].nil?
                    @commands[group].each do |cmd|
                        @node.vm.provision 'shell', inline: cmd
                    end
                end
            end
        end

    end

end
