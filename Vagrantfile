# -*- mode: ruby -*-
# vi: set ft=ruby :

ENV["LANG"]   = 'C'
ENV["LC_ALL"] = 'C'

boxname      = 'debian/bullseye64'
pg_nodes     = 'srv1', 'srv2'
base_ip      = '192.168.122.90'
pgver        = 13
storage_pool = 'default'
storage_name = 'san_storage.img'

common_env = {
    'DEBIAN_FRONTEND' => 'noninteractive',
}

diskid = '0123456789'

if File.file?('vagrant.yml') and ( custom = YAML.load_file('vagrant.yml') )
    boxname      = custom['boxname']      if custom.has_key?('boxname')
    pg_nodes     = custom['pg_nodes']     if custom.has_key?('pg_nodes')
    base_ip      = custom['base_ip']      if custom.has_key?('base_ip')
    pgver        = custom['pgver']        if custom.has_key?('pgver')
    storage_pool = custom['storage_pool'] if custom.has_key?('storage_pool')
    storage_name = custom['storage_name'] if custom.has_key?('storage_name')
    if custom.has_key?('prov_env')
        custom['prov_env'].each do |k,v|
            common_env[k] = v
        end
    end
end

next_ip    = IPAddr.new(base_ip).succ
nodes_ips  = {}

( pg_nodes ).each do |node|
    nodes_ips[node] = next_ip.to_s
    next_ip = next_ip.succ
end

Vagrant.configure('2') do |config|
  config.vm.box = boxname

  config.vm.provider 'libvirt' do |lv|
    lv.qemu_use_session = false
    lv.storage_pool_name = storage_pool
    lv.memory = 1024
    lv.watchdog model: 'i6300esb'
    lv.storage :file, :path => storage_name,
        :size => '10G',
        :device => 'vds',
        :allow_existing => true,
        :shareable => true,
        :type => 'raw',
        :cache => 'writethrough',
        :serial => diskid
  end

  config.trigger.after :destroy do |t|
    t.warn = "YOU MUST DROP THE SHARED STORAGE USING:
    virsh vol-delete --pool #{storage_pool} #{storage_name}"
  end

  config.ssh.insert_key = false
  config.vm.synced_folder '.', '/vagrant', disabled: true

  pg_nodes.each do |node|
    config.vm.define node do |conf|
      conf.vm.network 'private_network',
        ip: nodes_ips[node]
    end
  end

  config.vm.provision 'ssh-prv', type: 'file',
      source: 'provision/id_rsa',
      destination: '/home/vagrant/.ssh/id_rsa'

  config.vm.provision 'ssh-pub', type: 'file',
      source: 'provision/id_rsa.pub',
      destination: '/home/vagrant/.ssh/id_rsa.pub'

  config.vm.provision 'sys', type: "shell", path: "provision/system.bash",
      env: common_env,
      args: [ pgver ]

  pg_nodes.each do |node|
    config.vm.define node do |conf|
      conf.vm.provision 'net', type: "shell", path: "provision/network.bash",
        env: common_env,
        args: [ node ] + nodes_ips.keys.map {|n| "#{n}=#{nodes_ips[n]}"}
    end
  end

  config.vm.provision 'lvm', type: "shell", path: "provision/lvm.bash",
      run: 'never', env: common_env

  config.vm.define pg_nodes.first, primary: true do |conf|
    conf.vm.provision 'san', type: "shell", path: 'provision/san.bash',
        run: 'never', env: common_env, args: [ diskid ]
    conf.vm.provision 'pgsql', type: "shell", path: 'provision/pgsql.bash',
        run: 'never', env: common_env, args: [ pgver ]
    conf.vm.provision 'pcmk', type: "shell", path: 'provision/pcmk.bash',
        run: 'never', env: common_env, args: [ pgver, base_ip ] + pg_nodes
  end
end
