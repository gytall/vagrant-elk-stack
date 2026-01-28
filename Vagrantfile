ENV['VAGRANT_SERVER_URL'] = 'https://vagrant.elab.pro'

Vagrant.configure("2") do |config|
  config.vm.box = "ubuntu/jammy64"

  # =======================
  # VM1 — Web
  # =======================
  config.vm.define "web" do |web|
    web.vm.hostname = "web"
    web.vm.network "private_network", ip: "192.168.56.10"

    web.vm.provider "virtualbox" do |vb|
      vb.name = "vm-web"
      vb.memory = 4096
      vb.cpus = 2
    end

    web.vm.provision "shell", path: "provision/common.sh"
    web.vm.provision "shell", path: "provision/web.sh"
  end

  # =======================
  # VM2 — Monitoring
  # =======================
  config.vm.define "monitoring" do |mon|
    mon.vm.hostname = "monitoring"
    mon.vm.network "private_network", ip: "192.168.56.20"

    mon.vm.provider "virtualbox" do |vb|
      vb.name = "vm-monitoring"
      vb.memory = 8192
      vb.cpus = 2
    end

    mon.vm.provision "shell", path: "provision/common.sh"
    mon.vm.provision "shell", path: "provision/monitoring.sh"
  end
end
