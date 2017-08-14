from jadi import component
import aj
from aj.api.http import url, HttpPlugin
from aj.api.endpoint import endpoint, EndpointError, EndpointReturn
from aj.plugins import PluginManager
import os.path
import subprocess
import time
import json

from pyroute2 import IPRoute

@component(HttpPlugin)
class Handler(HttpPlugin):
	def __init__(self, context):
		self.context = context
	
	def getPluginPath(self):
		manager = PluginManager.get(aj.context)
		plugin = manager['coach']
		return plugin['path']
		
	def runCMD(self, cmd):
		ps = subprocess.Popen(cmd,shell=True,stdout=subprocess.PIPE,stderr=subprocess.STDOUT)
		output = ps.communicate()[0]
		return output
	
	@url(r'/api/coach/isCephInstalled')
	@endpoint(api=True)
	def handle_api_coach_isCephInstalled(self, http_context):
		return os.path.isfile("/etc/ceph/ceph.conf");
		
	@url(r'/api/coach/installNetworkServices')
	@endpoint(api=True)
	def handle_api_coach_installNetworkServices(self, http_context):
		if not self.runCMD("command -v docker").replace("\n",""):
			self.runCMD("curl -fsSL https://get.docker.com/ | sh")
			return "Docker installed."
		if self.runCMD("docker node ls").replace("\n","") === "Cannot connect to the Docker daemon. Is the docker daemon running on this host?":
			self.runCMD("docker swarm init --advertise-addr x.x.x.x")
			return "Docker swarm initilized."
		if not os.path.isfile("/etc/systemd/system/provisioner-dnsmasq.service"):
			self.runCMD("chmod +x "+self.getPluginPath()+"/docker/provisioner/dnsmasq/deploy.sh")
			self.runCMD(self.getPluginPath()+"/docker/provisioner/dnsmasq/deploy.sh")
			return "DNS and DHCP services installed and running."
		
		return "Ready."
			
	@url(r'/api/coach/isCephFS')
	@endpoint(api=True)
	def handle_api_coach_isCephFS(self, http_context):
		if self.runCMD("df -h | grep /mnt/ceph/fs").replace("\n","") == "":
			return False
		else:
			return True
	
	@url(r'/api/coach/bootstrap/join')
	@endpoint(api=True)
	def handle_api_coach_bootstrap_join(self, http_context):
		config = json.loads(http_context.body)
		return config
		
	@url(r'/api/coach/bootstrap/(?P<iface>\w+)')
	@endpoint(api=True)
	def handle_api_coach_bootstrap_net(self, http_context, iface):		
		is_ipcalc = self.runCMD("command -v ipcalc").replace("\n","")
		if not is_ipcalc:
			self.runCMD("apt-get -y install ipcalc")
			return "Networking dependancies were installed."
			
		ip = IPRoute()
		config = [{'iface': x['index'],
			'cidr': str(x.get_attr('IFA_ADDRESS'))+"/"+str(x['prefixlen'])} for x in ip.get_addr(label=iface)]
		ip.close()
		config = config[0]
		config['iface'] = iface
		
		net_state = self.runCMD("cat /sys/class/net/"+config['iface']+"/operstate").replace('\n', '')
		net_min = self.runCMD("ipcalc -n "+config['cidr']+" | grep HostMin | awk '{print $2}'").replace('\n', '')
		net_mask = self.runCMD("ipcalc -n "+config['cidr']+" | grep Netmask | awk '{print $2}'").replace('\n', '')
		net_cidr = self.runCMD("ipcalc -n "+config['cidr']+" | grep Netmask | awk '{print $4}'").replace('\n', '')
		net_work = self.runCMD("ipcalc -n "+config['cidr']+" | grep Network | awk '{print $2}'").replace('\n', '')
		net_bot = self.runCMD("ipcalc -n "+config['cidr']+" | grep Network | awk -F/ '{print $1}' | awk '{print $2}'").replace('\n', '')
		net_use = self.runCMD("ipcalc -n "+config['cidr']+" | grep Address | awk '{print $2}'").replace('\n', '')
		
		if net_bot == net_use:
			net_use = net_min
		
		iface_in_file = False
		ip_in_file = False
		if os.path.isfile("/etc/network/interfaces.d/storage"):
			for line in file("/etc/network/interfaces.d/storage"):
				if config['iface'] in line:
					iface_in_file = True
					
				if net_use in line:
					ip_in_file = True
					
			if iface_in_file & ip_in_file:
				storage_fabric_ready = True;
			else:
				store_fab_file = open("/etc/network/interfaces.d/storage", 'r+')
				
				net_4 = '["' + self.runCMD("ip -4 -o address show dev "+config['iface']+" | awk '{print $4}'").replace("\n", '", "') + '"]'
				net_4 = json.loads(net_4.replace(', ""', ''))
				net_6 = '["' + self.runCMD("ip -6 -o address show dev "+config['iface']+" | awk '{print $4}'").replace("\n", '", "') + '"]'
				net_6 = json.loads(net_6.replace(', ""', ''))
				
				if net_state == "up":
					self.runCMD("ip link set dev "+config['iface']+" down")
				for ip in net_4:
					self.runCMD("ip addr del "+ip+" dev "+config['iface'])
				for ip in net_6:
					self.runCMD("ip addr del "+ip+" dev "+config['iface'])
				self.runCMD("ip addr add "+net_use+"/"+net_cidr+" dev "+config['iface'])
				self.runCMD("ip link set dev "+config['iface']+" up")
				
				store_fab_file.truncate()
				store_fab_file.write("auto "+config['iface']+"\n")
				store_fab_file.write("iface "+config['iface']+" inet static\n")
				store_fab_file.write("address "+net_use+"\n")
				store_fab_file.write("netmask "+net_mask+"\n")
				store_fab_file.close()
				
				return "The storage fabric configuration has been updated.";
		else:
			store_fab_file = open("/etc/network/interfaces.d/storage", 'w')
			
			net_4 = '["' + self.runCMD("ip -4 -o address show dev "+config['iface']+" | awk '{print $4}'").replace("\n", '", "') + '"]'
			net_4 = json.loads(net_4.replace(', ""', ''))
			net_6 = '["' + self.runCMD("ip -6 -o address show dev "+config['iface']+" | awk '{print $4}'").replace("\n", '", "') + '"]'
			net_6 = json.loads(net_6.replace(', ""', ''))
			
			if net_state == "up":
				self.runCMD("ip link set dev "+config['iface']+" down")
			for ip in net_4:
				self.runCMD("ip addr del "+ip+" dev "+config['iface'])
			for ip in net_6:
				self.runCMD("ip addr del "+ip+" dev "+config['iface'])
			self.runCMD("ip addr add "+net_use+"/"+net_cidr+" dev "+config['iface'])
			self.runCMD("ip link set dev "+config['iface']+" up")
			
			store_fab_file.write("auto "+config['iface']+"\n")
			store_fab_file.write("iface "+config['iface']+" inet static\n")
			store_fab_file.write("address "+net_use+"\n")
			store_fab_file.write("netmask "+net_use+"\n")
			store_fab_file.close()
			
			return "The storage fabric configuration has been created.";
		
		domain = self.runCMD("cat /var/lib/dhcp/dhclient.leases | grep 'option domain-name ' | cut -d '\"' -f2").replace('\n', '')
		fqdn = self.runCMD("hostname -f").replace('\n', '')
		hostname = self.runCMD("hostname -s").replace('\n', '')
		config['fqdn'] = hostname+"."+domain
		if fqdn != config['fqdn']:
			self.runCMD('sed -i "/'+hostname+'/ s/.*//g" /etc/hosts')
			self.runCMD("hostname -b "+config['fqdn'])
			fqdn = self.runCMD("hostname -f").replace('\n', '')
			hostname = self.runCMD("hostname -s").replace('\n', '')
			return "FQDN updated."
		
		fqdn_file = open("/etc/hostname", 'r+')
		fqdn_old = fqdn_file.readline().strip()
		if fqdn_old != fqdn:
			fqdn_file.seek(0)
			fqdn_file.truncate()
			fqdn_file.write(fqdn+"\n")
			return fqdn_old != fqdn
		
		fqdn_in_file = False
		for line in file("/etc/hosts"):
			if net_min+"	"+fqdn+"	"+hostname+"	#coach-storage" in line:
				fqdn_in_file = True
				break
		if not fqdn_in_file:
			self.runCMD('sed -i "/'+hostname+'/ s/.*//g" /etc/hosts')
			store_fab_file = open("/etc/hosts", 'a')
			store_fab_file.write(net_min+'	'+fqdn+'	'+hostname+"	#coach-storage\n");
			return "Hosts file updated."
			
		return "Networking Ready."
	
	@url(r'/api/coach/bootstrap')
	@endpoint(api=True)
	def handle_api_coach_bootstrap(self, http_context):
		config = json.loads(http_context.body)
		
		is_ipcalc = self.runCMD("command -v ipcalc").replace("\n","")
		if not is_ipcalc:
			self.runCMD("apt-get -y install ipcalc")
			return "Networking dependancies were installed."
		
		net_state = self.runCMD("cat /sys/class/net/"+config['iface']+"/operstate").replace('\n', '')
		net_min = self.runCMD("ipcalc -n "+config['cidr']+" | grep HostMin | awk '{print $2}'").replace('\n', '')
		net_mask = self.runCMD("ipcalc -n "+config['cidr']+" | grep Netmask | awk '{print $2}'").replace('\n', '')
		net_cidr = self.runCMD("ipcalc -n "+config['cidr']+" | grep Netmask | awk '{print $4}'").replace('\n', '')
		net_work = self.runCMD("ipcalc -n "+config['cidr']+" | grep Network | awk '{print $2}'").replace('\n', '')
		net_bot = self.runCMD("ipcalc -n "+config['cidr']+" | grep Network | awk -F/ '{print $1}' | awk '{print $2}'").replace('\n', '')
		net_use = self.runCMD("ipcalc -n "+config['cidr']+" | grep Address | awk '{print $2}'").replace('\n', '')
		
		if net_bot == net_use:
			net_use = net_min
		
		iface_in_file = False
		ip_in_file = False
		if os.path.isfile("/etc/network/interfaces.d/storage"):
			for line in file("/etc/network/interfaces.d/storage"):
				if config['iface'] in line:
					iface_in_file = True
					
				if net_use in line:
					ip_in_file = True
					
			if iface_in_file & ip_in_file:
				storage_fabric_ready = True;
			else:
				store_fab_file = open("/etc/network/interfaces.d/storage", 'r+')
				
				net_4 = '["' + self.runCMD("ip -4 -o address show dev "+config['iface']+" | awk '{print $4}'").replace("\n", '", "') + '"]'
				net_4 = json.loads(net_4.replace(', ""', ''))
				net_6 = '["' + self.runCMD("ip -6 -o address show dev "+config['iface']+" | awk '{print $4}'").replace("\n", '", "') + '"]'
				net_6 = json.loads(net_6.replace(', ""', ''))
				
				if net_state == "up":
					self.runCMD("ip link set dev "+config['iface']+" down")
				for ip in net_4:
					self.runCMD("ip addr del "+ip+" dev "+config['iface'])
				for ip in net_6:
					self.runCMD("ip addr del "+ip+" dev "+config['iface'])
				self.runCMD("ip addr add "+net_use+"/"+net_cidr+" dev "+config['iface'])
				self.runCMD("ip link set dev "+config['iface']+" up")
				
				store_fab_file.truncate()
				store_fab_file.write("auto "+config['iface']+"\n")
				store_fab_file.write("iface "+config['iface']+" inet static\n")
				store_fab_file.write("address "+net_use+"\n")
				store_fab_file.write("netmask "+net_mask+"\n")
				store_fab_file.close()
				
				return "The storage fabric configuration has been updated.";
		else:
			store_fab_file = open("/etc/network/interfaces.d/storage", 'w')
			
			net_4 = '["' + self.runCMD("ip -4 -o address show dev "+config['iface']+" | awk '{print $4}'").replace("\n", '", "') + '"]'
			net_4 = json.loads(net_4.replace(', ""', ''))
			net_6 = '["' + self.runCMD("ip -6 -o address show dev "+config['iface']+" | awk '{print $4}'").replace("\n", '", "') + '"]'
			net_6 = json.loads(net_6.replace(', ""', ''))
			
			if net_state == "up":
				self.runCMD("ip link set dev "+config['iface']+" down")
			for ip in net_4:
				self.runCMD("ip addr del "+ip+" dev "+config['iface'])
			for ip in net_6:
				self.runCMD("ip addr del "+ip+" dev "+config['iface'])
			self.runCMD("ip addr add "+net_use+"/"+net_cidr+" dev "+config['iface'])
			self.runCMD("ip link set dev "+config['iface']+" up")
			
			store_fab_file.write("auto "+config['iface']+"\n")
			store_fab_file.write("iface "+config['iface']+" inet static\n")
			store_fab_file.write("address "+net_use+"\n")
			store_fab_file.write("netmask "+net_use+"\n")
			store_fab_file.close()
			
			return "The storage fabric configuration has been created.";
		
		fqdn = self.runCMD("hostname -f").replace('\n', '')
		hostname = self.runCMD("hostname -s").replace('\n', '')
		if fqdn != config['fqdn']:
			self.runCMD('sed -i "/'+hostname+'/ s/.*//g" /etc/hosts')
			self.runCMD("hostname -b "+config['fqdn'])
			fqdn = self.runCMD("hostname -f").replace('\n', '')
			hostname = self.runCMD("hostname -s").replace('\n', '')
			return "FQDN updated."
		
		fqdn_file = open("/etc/hostname", 'r+')
		fqdn_old = fqdn_file.readline().strip()
		if fqdn_old != fqdn:
			fqdn_file.seek(0)
			fqdn_file.truncate()
			fqdn_file.write(fqdn+"\n")
			return fqdn_old != fqdn
		
		fqdn_in_file = False
		for line in file("/etc/hosts"):
			if net_min+"	"+fqdn+"	"+hostname+"	#coach-storage" in line:
				fqdn_in_file = True
				break
		if not fqdn_in_file:
			self.runCMD('sed -i "/'+hostname+'/ s/.*//g" /etc/hosts')
			store_fab_file = open("/etc/hosts", 'a')
			store_fab_file.write(net_min+'	'+fqdn+'	'+hostname+"	#coach-storage\n");
			return "Hosts file updated."
		
		is_ceph_deploy = self.runCMD("command -v ceph-deploy")
		if not is_ceph_deploy:
			self.runCMD("env DEBIAN_FRONTEND=noninteractive DEBIAN_PRIORITY=critical apt-get -y install ceph-deploy ca-certificates apt-transport-https")
			return "The ceph deployment toolkit has been installed."
		
		ceph_cluster_name = "ceph"
		ceph_conf_path = self.getPluginPath()+"/ceph/"+ceph_cluster_name+".conf"
		if not os.path.isfile(ceph_conf_path):
			cwd = os.getcwd()
			os.chdir(self.getPluginPath()+"/ceph")
			
			self.runCMD("ceph-deploy new $(hostname -s)")
			
			ceph_conf_file = open(ceph_conf_path, 'a')
			ceph_conf_file.write("osd pool default size = 2\n")
			ceph_conf_file.write("public network = "+net_work+"\n")
			ceph_conf_file.close()
			
			os.chdir(cwd)
			return "New ceph configuration created."
		
		is_ceph = self.runCMD("command -v ceph")
		if not is_ceph:
			cwd = os.getcwd()
			os.chdir(self.getPluginPath()+"/ceph")
			
			self.runCMD("env DEBIAN_FRONTEND=noninteractive DEBIAN_PRIORITY=critical apt-get -y install ceph")
				
			os.chdir(cwd)
			return "Ceph has been installed."
		
		is_ceph_mds = self.runCMD("command -v ceph-mds")
		if not is_ceph_mds:
			cwd = os.getcwd()
			os.chdir(self.getPluginPath()+"/ceph")
			
			self.runCMD("env DEBIAN_FRONTEND=noninteractive DEBIAN_PRIORITY=critical apt-get -y install ceph-mds")
				
			os.chdir(cwd)
			return "Ceph metadata server has been installed."
			
		is_radosgw = self.runCMD("command -v radosgw")
		if not is_radosgw:
			cwd = os.getcwd()
			os.chdir(self.getPluginPath()+"/ceph")
			
			self.runCMD("env DEBIAN_FRONTEND=noninteractive DEBIAN_PRIORITY=critical apt-get -y install radosgw")
				
			os.chdir(cwd)
			return "Rados gateway has been installed."
		
		if not os.path.isfile("/etc/ceph/"+ceph_cluster_name+".conf"):
			cwd = os.getcwd()
			os.chdir(self.getPluginPath()+"/ceph")
			
			self.runCMD("ceph-deploy mon create-initial")
			
			os.chdir(cwd)
			return "Ceph monitor initialized on this host."
			
		return "Bootstrap completed."
	
