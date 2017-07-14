from jadi import component
import aj
from aj.api.http import url, HttpPlugin
from aj.api.endpoint import endpoint, EndpointError, EndpointReturn
from aj.plugins import PluginManager
import os.path
import subprocess
import time
import json
import re
import ceph_deploy.cli as CephDeploy

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

	@url(r'/api/coach/fabric/get/fqdn')
	@endpoint(api=True)
	def handle_api_fabric_get_fqdn(self, http_context):
		return self.runCMD("hostname -f").replace('\n', '')

	@url(r'/api/coach/fabric/get/links')
	@endpoint(api=True)
	def handle_api_fabric_get_links(self, http_context):
		start_time = time.time()
		links = '["' + self.runCMD("ip link | grep mtu | awk '{print $2}' | sed 's/://' | grep -v lo").replace("\n", '", "').strip() + '"]'
		output = json.loads(links.replace(', ""', ''))
		results = []
		for link in output:
			net_state = self.runCMD("cat /sys/class/net/"+link+"/operstate").replace('\n', '')
			net_type = self.runCMD("ip link | awk \"/"+link+"/{getline; print}\" | awk '{print $1}' | awk -F \"/\" '{print $2}'").replace('\n', '')
			net_4 = '["' + self.runCMD("ip -4 -o address show dev "+link+" | awk '{print $4}'").replace("\n", '", "') + '"]'
			net_4 = json.loads(net_4.replace(', ""', ''))
			net_6 = '["' + self.runCMD("ip -6 -o address show dev "+link+" | awk '{print $4}'").replace("\n", '", "') + '"]'
			net_6 = json.loads(net_6.replace(', ""', ''))
			fqdn = self.runCMD("hostname -f").replace('\n', '')
			results.append({
				'name' : link,
				'state' : net_state,
				'type' : net_type,
				'ipv4' : net_4,
				'ipv6' : net_6,
				'fqdn' : fqdn
			})
		return results
	
	@url(r'/api/coach/fabric/dhcp_search/(?P<iface>\w+)')
	@endpoint(api=True)
	def handle_api_fabric_dhcp_search(self, http_context, iface):
		is_nmap = self.runCMD("command -v nmap")
		if not is_nmap:
			self.runCMD("apt-get -y install nmap")
			return "Dependancies were installed."
		
		dhclient_patch = False
		for line in file("/etc/dhcp/dhclient.conf"):
			if "option coach-data code 242 = text;" in line:
				dhclient_patch = True
				break
		
		if not dhclient_patch:
			dhclient = open("/etc/dhcp/dhclient.conf", "r+")
			dhclient.write("option coach-data code 242 = text;\n")
			dhclient.write("also request coach-data;\n")
			dhclient.close()
		
		net_state = self.runCMD("cat /sys/class/net/"+iface+"/operstate").replace('\n', '')
		if(net_state == "down"):
			self.runCMD("ip link set dev "+iface+" up")
		
		dhcp_search = self.runCMD("nmap --script broadcast-dhcp-discover -e "+iface+" | grep 'Server Identifier'")
		list_of_words = dhcp_search.split()
		try:
			dhcp_server = list_of_words[list_of_words.index("Identifier:") + 1]
		except ValueError:
			dhcp_server = ''
		
		if dhcp_server:
			self.runCMD("dhclient "+iface)
			dhclient_lease = False
			for line in file("/var/lib/dhcp/dhclient.leases"):
				if "option coach-data" in line:
					dhclient_lease = True
					break
			os.remove('/var/lib/dhcp/dhclient.leases')
		
		if(net_state == "down"):
			self.runCMD("ip link set dev "+iface+" down")
		
		if dhcp_server:
			if dhclient_lease:
				return "Ready to add."
			else:
				return "Not ready."
		else:
			return "Ready to create."
	
	@url(r'/api/coach/fabric/connect/(?P<iface>\w+)/(?P<fabric>\w+)')
	@endpoint(api=True)
	def handle_api_fabric_connect(self, http_context, iface, fabric):
		try:
			store_fab_file = open("/etc/network/interfaces.d/storage", 'r+')
		except IOError:
			store_fab_file = open("/etc/network/interfaces.d/storage", 'w')
		store_fab_file.truncate()
		store_fab_file.write("auto "+iface+"\n")
		store_fab_file.write("iface "+iface+" inet dhcp\n")
		store_fab_file.close()
				
		return "The "+fabric+" fabric has been set up."
	
	@url(r'/api/coach/fabric/bootstrap/new')
	@endpoint(api=True)
	def handle_api_fabric_bootstrap(self, http_context):
		config = json.loads(http_context.body)
		
		is_ipcalc = self.runCMD("command -v ipcalc")
		if not is_ipcalc:
			self.runCMD("apt-get -y install ipcalc")
			return "Networking dependancies were installed."
		
		net_state = self.runCMD("cat /sys/class/net/"+config['iface']+"/operstate").replace('\n', '')
		net_min = self.runCMD("ipcalc -n "+config['cidr']+" | grep HostMin | awk '{print $2}'").replace('\n', '')
		net_mask = self.runCMD("ipcalc -n "+config['cidr']+" | grep Netmask | awk '{print $2}'").replace('\n', '')
		net_cidr = self.runCMD("ipcalc -n "+config['cidr']+" | grep Netmask | awk '{print $4}'").replace('\n', '')
		net_work = self.runCMD("ipcalc -n "+config['cidr']+" | grep Network | awk '{print $2}'").replace('\n', '')
		
		iface_in_file = False
		ip_in_file = False
		if os.path.isfile("/etc/network/interfaces.d/storage"):
			for line in file("/etc/network/interfaces.d/storage"):
				if config['iface'] in line:
					iface_in_file = True
					
				if net_min in line:
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
				self.runCMD("ip addr add "+net_min+"/"+net_cidr+" dev "+config['iface'])
				self.runCMD("ip link set dev "+config['iface']+" up")
				
				store_fab_file.truncate()
				store_fab_file.write("auto "+config['iface']+"\n")
				store_fab_file.write("iface "+config['iface']+" inet static\n")
				store_fab_file.write("address "+net_min+"\n")
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
			self.runCMD("ip addr add "+net_min+"/"+net_cidr+" dev "+config['iface'])
			self.runCMD("ip link set dev "+config['iface']+" up")
			
			store_fab_file.write("auto "+config['iface']+"\n")
			store_fab_file.write("iface "+config['iface']+" inet static\n")
			store_fab_file.write("address "+net_min+"\n")
			store_fab_file.write("netmask "+net_mask+"\n")
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
	
