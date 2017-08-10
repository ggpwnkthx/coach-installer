from jadi import component
import aj
from aj.api.http import url, HttpPlugin
from aj.api.endpoint import endpoint, EndpointError, EndpointReturn
import subprocess
import json

@component(HttpPlugin)
class Handler(HttpPlugin):
	def __init__(self, context):
		self.context = context
		
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
			with file('/etc/dhcp/dhclient.conf', 'r') as original: 
				data = original.read()
			with file('/etc/dhcp/dhclient.conf', 'w') as modified: 
				modified.write("option coach-data code 242 = text;\nalso request coach-data;\n" + data)
		
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