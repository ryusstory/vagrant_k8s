# --- Variables ---
require 'yaml'

# Load settings from vagrant.yml or vagrant.yml.dist
current_dir = File.dirname(File.expand_path(__FILE__))
CONFIG = YAML.load_file("#{current_dir}/config.yaml")

# -- Validation --
if CONFIG['network']['ip_offset'] % 10 != 0
  raise "Error: K8S_NETWORK_IP_OFFSET must be a multiple of 10. now #{CONFIG['network']['ip_offset']}"
end
if CONFIG['node_counts']['control_plane'] < 1 || CONFIG['node_counts']['worker'] < 1 || CONFIG['node_counts']['control_plane'] > 3
  raise "Error: K8S_CONTROL_PLANE_NODE must be 1~3 and K8S_WORKER_NODE must be (1~)"
end
if CONFIG['k8s']['k8s_version'] !~ /^\d+\.\d+\.\d+$/
  raise "Error: K8S_VERSION must be in the format 'n.nn.n' (e.g., '1.32.5')."
end
if CONFIG['k8s']['containerd_version'] !~ /^\d+\.\d+\.\d+-\d+$/ && CONFIG['k8s']['containerd_version'] !~ /^\d+\.\d+\.\d+$/
  raise "Error: K8S_CONTAINERD_VERSION must be in the format 'n.n.n-n' (e.g., '1.7.27-1') OR 'n.n.n' (e.g., '2.1.3')."
end

# --- Vagrant Configuration ---
Vagrant.configure("2") do |config|
  config.vm.define "ha" do |subconfig|
    subconfig.vm.provider :virtualbox do |v|
      v.cpus = 1
      v.memory = "1024"
    end
    subconfig.vm.box = CONFIG['box_image']
    subconfig.vm.synced_folder "./", "/vagrant", disabled: true
    subconfig.vm.synced_folder "_shared", "/_shared", create: true
    subconfig.vm.hostname = "k8ha"
    subconfig.vm.network "public_network", bridge: CONFIG['network']['bridge_adapter'], auto_config: "false"
    subconfig.vm.provision "shell", path: "_ha_config_sync.sh", args: [ CONFIG.to_json ]
    subconfig.vm.provision "shell", path: "_all_netplan.sh", args: [ 0 ]
    subconfig.vm.provision "shell", path: "_ha_setup_haproxy.sh"
    subconfig.vm.provision "shell", path: "_ha_nohup_provision.sh"
    subconfig.vm.post_up_message = "vagrant ssh k8c1 -- tail -f /_shared/ha.log"
  end

  (1..CONFIG['node_counts']['control_plane']).each do |i|
    config.vm.define "k8c#{i}" do |subconfig|
      subconfig.vm.provider :virtualbox do |v|
        v.cpus = CONFIG['node_resources']['control_plane']['cpu']
        v.memory = CONFIG['node_resources']['control_plane']['memory']
      end
      subconfig.vm.box = CONFIG['box_image']
      subconfig.vm.synced_folder "./", "/vagrant", disabled: true
      subconfig.vm.synced_folder "_shared", "/_shared"
      subconfig.vm.hostname = "k8c#{i}"
      subconfig.vm.network "public_network", bridge: CONFIG['network']['bridge_adapter'], auto_config: "false"
      subconfig.vm.provision "shell", path: "_all_netplan.sh", args: [ i ]
      subconfig.vm.provision "shell", inline: "cat /_shared/ha_id_rsa.pub >> ~/.ssh/authorized_keys"
      subconfig.vm.provision "shell", path: "_k8s_later_join.sh"
    end
  end

  (1..CONFIG['node_counts']['worker']).each do |i|
    config.vm.define "k8w#{i}" do |subconfig|
      subconfig.vm.provider :virtualbox do |v|
        v.cpus = CONFIG['node_resources']['worker']['cpu']
        v.memory = CONFIG['node_resources']['worker']['memory']
      end
      subconfig.vm.box = CONFIG['box_image']
      subconfig.vm.synced_folder "./", "/vagrant", disabled: true
      subconfig.vm.synced_folder "_shared", "/_shared"
      subconfig.vm.hostname = "k8w#{i}"
      subconfig.vm.network "public_network", bridge: CONFIG['network']['bridge_adapter'], auto_config: "false"
      subconfig.vm.provision "shell", path: "_all_netplan.sh", args: [ i ]
      subconfig.vm.provision "shell", inline: "cat /_shared/ha_id_rsa.pub >> ~/.ssh/authorized_keys"
      subconfig.vm.provision "shell", path: "_k8s_later_join.sh"
    end
  end
end
