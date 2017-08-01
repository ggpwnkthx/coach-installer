from jadi import component
import aj
from aj.api.http import url, HttpPlugin
from aj.api.endpoint import endpoint, EndpointError, EndpointReturn
from aj.plugins import PluginManager
import subprocess
import os.path
import json
import re
import shutil

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
		
	@url(r'/api/coach/storage/ceph/mon/status')
	@endpoint(api=True)
	def handle_api_storage_monitor_status(self, http_context):
		if self.runCMD("command -v ceph").replace("\n",""):
			return json.loads(self.runCMD("ceph -f json mon_status"))
		else:
			return False

	@url(r'/api/coach/storage/ceph/osd/details')
	@endpoint(api=True)
	def handle_api_storage_ceph_osd_details(self, http_context):
		config = json.loads(http_context.body)
		if not config.has_key('cluster'):
			config['cluster'] = 'ceph'
		config['id'] = self.runCMD("lsblk -lp | grep \"/var/lib/ceph/osd/"+config['cluster']+"-*\" | grep \""+config['osd']['name']+"\"").replace("\n", "").split("/var/lib/ceph/osd/"+config['cluster']+"-",1)[1]
		config['journal'] = self.runCMD("readlink /var/lib/ceph/osd/"+config['cluster']+"-"+config['id']+"/journal").replace("\n", "")
		config['journal'] = self.runCMD("readlink "+config['journal']).replace("\n", "")
		config['journal_part'] = re.search(r'\d+$',config['journal']).group()
		config['journal'] = "/dev/"+config['journal'].replace("../../","").replace(config['journal_part'], "")
		config['osd'] = None
		return config
		
	@url(r'/api/coach/storage/ceph/osd/add')
	@endpoint(api=True)
	def handle_api_storage_ceph_osd_add(self, http_context):
		cwd = os.getcwd()
		os.chdir(self.getPluginPath()+"/ceph")
		
		config = json.loads(http_context.body)
		self.runCMD("sgdisk -z "+config['osd'])
		if not config.has_key('cluster'):
			config['cluster'] = 'ceph'
			
		if config.has_key('journal'):
			self.runCMD("ceph-deploy osd prepare --fs-type btrfs $(hostname -s):"+config['osd']+":"+config['journal'])
			os.chdir(cwd)
			return config['osd']+", with journal "+config['journal']+", has been added to the ceph cluster."
		else:
			self.runCMD("ceph-deploy osd prepare --fs-type btrfs $(hostname -s):"+config['osd'])
			os.chdir(cwd)
			return config['osd']+" has been added to the ceph cluster."

	@url(r'/api/coach/storage/ceph/osd/remove')
	@endpoint(api=True)
	def handle_api_storage_ceph_osd_remove(self, http_context):
		cwd = os.getcwd()
		os.chdir(self.getPluginPath()+"/ceph")
		
		config = json.loads(http_context.body)
		if not config.has_key('cluster'):
			config['cluster'] = 'ceph'
		id = self.runCMD("lsblk -lp | grep \"/var/lib/ceph/osd/"+config['cluster']+"-*\" | grep \""+config['osd']+"\"").replace("\n", "").split("/var/lib/ceph/osd/"+config['cluster']+"-",1)[1]
		if not config.has_key('journal'):
			config['journal'] = self.runCMD("readlink /var/lib/ceph/osd/"+config['cluster']+"-"+id+"/journal").replace("\n", "")
			config['journal'] = self.runCMD("readlink "+config['journal']).replace("\n", "")
			config['journal_part'] = re.search(r'\d+$',config['journal']).group()
			config['journal'] = "/dev/"+config['journal'].replace("../../","").replace(config['journal_part'], "")
		
		self.runCMD("systemctl stop ceph-osd@"+id)
		self.runCMD("umount /var/lib/ceph/osd/ceph-"+id)
		self.runCMD("rm -r /var/lib/ceph/osd/ceph-"+id)
		self.runCMD("ceph osd out "+id)
		self.runCMD("ceph osd crush remove osd."+id)
		self.runCMD("ceph auth del osd."+id)
		self.runCMD("ceph osd rm "+id)
		self.runCMD("sgdisk -z "+config['osd'])
		if config['osd'] != config['journal']:
			self.runCMD("sgdisk "+config['journal']+" -d "+config['journal_part'])
		
		os.chdir(cwd)
		return "The device "+config['osd']+", OSD #"+id+", has been removed from the storage cluster."
		
	@url(r'/api/coach/storage/ceph/osd/tree')
	@endpoint(api=True)
	def handle_api_storage_ceph_osd_tree(self, http_context):
		if self.runCMD("command -v ceph").replace("\n",""):
			osd_tree = json.loads(self.runCMD("ceph -f json osd tree"))
			
			for node in osd_tree['nodes']:
				if node['type'] == 'root':
					root = {
						'name' : node['name'],
						'children' : []
					}
				if node['type'] == 'host':
					host = {
						'name' : node['name'],
						'children' : []
					}
					root['children'].append(host)
				if node['type'] == 'osd':
					host['children'].append({
						'name' : node['name'],
						'status' : node['status'],
						'children' : []
					})
			
			return root
		else:
			return False
	
	@url(r'/api/coach/storage/ceph/pg/tree')
	@endpoint(api=True)
	def handle_api_storage_ceph_pg_tree(self, http_context):
		pools = {}
		osd_dump = json.loads(self.runCMD("ceph osd dump --format=json"))
		for pool in osd_dump['pools']:
			pools[int(pool['pool'])] = pool['pool_name']
		
		pg_dump = json.loads(re.sub(r'^.+\n', '', self.runCMD("ceph pg dump --format=json")))
		pgTree = {
			'name' : 'cluster',
			'version' : pg_dump['version'],
			'children' : []
		}
		
		for pg in pg_dump['pg_stats']:
			if pg['state'].find('active+clean') > 0:
				continue;
			pool = int(pg['pgid'].split('.')[0])
			group = pg['pgid'].split('.')[1]
			
			poolindex = -1
			
			for x in range(0, len(pgTree['children'])):
				if pgTree['children'][x]['name'] == pool:
					poolindex = x
			
			pgNode = {
				'name' : group,
				'pool_name' : pools[pool],
				'pgid' : pg['pgid'],
				'objects' : pg['stat_sum']['num_objects'],
				'state' : pg['state']
			}
			
			if poolindex != -1:
				pgTree['children'][poolindex]['children'].append(pgNode)
			else:
				pgTree['children'].append({
					'name' : pool,
					'pool_name' : pools[pool],
					'children' : [pgNode]
				})
				
		return pgTree
	
	@url(r'/api/coach/storage/ceph/pg/map')
	@endpoint(api=True)
	def handle_api_storage_ceph_pg_map(self, http_context):
		matches = {}
		matches[1] = 100
		response = {'pgmap' : matches[1]}
		return response
	
	@url(r'/api/coach/storage/ceph/iops')
	@endpoint(api=True)
	def handle_api_storage_ceph_iops(self, http_context):
		status = json.loads(self.runCMD("ceph -s -f json"))
		return status
		
	@url(r'/api/coach/storage/ceph/fs/add')
	@endpoint(api=True)
	def handle_api_storage_ceph_fs_add(self, http_context):
		cwd = os.getcwd()
		os.chdir(self.getPluginPath()+"/ceph")
		
		config = json.loads(http_context.body)
		if not config.has_key('cluster'):
			config['cluster'] = 'ceph'
		if not self.runCMD("ceph mds stat | grep $(hostname -s)").replace("\n",""):
			self.runCMD("ceph-deploy --cluster "+config['cluster']+" mds create $(hostname -s)")
			os.chdir(cwd)
			return "Ceph Metadata services installed on this device."
		if config['fs'] not in self.runCMD("ceph fs ls"):
			if "Error" in self.runCMD("ceph osd pool stats "+config['fs']+"_data"):
				self.runCMD("ceph osd pool create "+config['fs']+"_data 128")
				os.chdir(cwd)
				return "OSD Pool '"+config['fs']+"_data' was created."
			if "Error" in self.runCMD("ceph osd pool stats "+config['fs']+"_meta"):
				self.runCMD("ceph osd pool create "+config['fs']+"_meta 128")
				os.chdir(cwd)
				return "OSD Pool '"+config['fs']+"_meta' was created."
			self.runCMD("ceph fs new "+config['fs']+" "+config['fs']+"_meta "+config['fs']+"_data")
			os.chdir(cwd)
			return "Clustered file system '"+config['fs']+"' has been created."
		
		os.chdir(cwd)
		return "Clustered file system ready."
		
	@url(r'/api/coach/storage/ceph/fs/mount')
	@endpoint(api=True)
	def handle_api_storage_ceph_fs_mount(self, http_context):
		if not os.path.isdir("/mnt/ceph"):
			os.makedirs("/mnt/ceph")
			return "Created directory '/mnt/ceph'"
		if not os.path.isdir("/mnt/ceph/fs"):
			os.makedirs("/mnt/ceph/fs")
			return "Created directory '/mnt/ceph/fs'"
		if not os.path.isfile("/etc/systemd/system/ceph-client.service"):
			shutil.copy2(self.getPluginPath()+"/ceph/services/ceph-client.service", "/etc/systemd/system/ceph-client.service")
			self.runCMD("systemctl daemon-reload")
			self.runCMD("systemctl stop ceph-client.service")
			self.runCMD("systemctl enable ceph-client.service")
			self.runCMD("systemctl start ceph-client.service")
			return "Ceph client service installed and started."
		if not os.path.isfile("/etc/ceph/mnt-ceph-fs.sh"):
			shutil.copy2(self.getPluginPath()+"/ceph/services/mnt-ceph-fs.sh", "/etc/ceph/mnt-ceph-fs.sh")
			self.runCMD("chmod +x /etc/ceph/mnt-ceph-fs.sh")
			return "CephFS mounting script installed."
		if not os.path.isfile("/etc/systemd/system/mnt-ceph-fs.service"):
			shutil.copy2(self.getPluginPath()+"/ceph/services/mnt-ceph-fs.service", "/etc/systemd/system/mnt-ceph-fs.service")
			self.runCMD("systemctl daemon-reload")
			self.runCMD("systemctl stop mnt-ceph-fs.service")
			self.runCMD("systemctl enable mnt-ceph-fs.service")
			self.runCMD("systemctl start mnt-ceph-fs.service")
			return "CephFS mounting service installed and started."
		return "CephFS Ready."
			
