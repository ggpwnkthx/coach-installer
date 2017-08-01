from jadi import component
import aj
from aj.api.http import url, HttpPlugin
from aj.api.endpoint import endpoint, EndpointError, EndpointReturn
from aj.plugins import PluginManager
import os
import stat
import subprocess
import json

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
		
	@url(r'/api/coach/storage/local/list/controllers')
	@endpoint(api=True)
	def handle_api_storage_local_controllers(self, http_context):
		return ""
		
	@url(r'/api/coach/storage/local/list/block_devices')
	@endpoint(api=True)
	def handle_api_storage_local_block_devices(self, http_context):
		return json.loads(self.runCMD("lsblk -OJp"))
		
	@url(r'/api/coach/storage/local/list/bays')
	@endpoint(api=True)
	def handle_api_storage_local_bays(self, http_context):
		self.runCMD("chmod +x "+self.getPluginPath()+"/scripts/find_bays.sh")
		output = self.runCMD(self.getPluginPath()+"/scripts/find_bays.sh").replace("\n", ",")
		if output:
			return json.loads("{"+output[:-1]+"}")
		else:
			return json.loads("{}")
		
	@url(r'/api/coach/storage/local/megaraid/exists')
	@endpoint(api=True)
	def handle_api_storage_local_controllers(self, http_context):
		return self.runCMD("lspci | grep MegaRAID")
		
	@url(r'/api/coach/storage/local/megaraid/build')
	@endpoint(api=True)
	def handle_api_storage_local_megaraid_build(self, http_context):
		self.runCMD("chmod +x "+self.getPluginPath()+"/scripts/megaraid_build.sh.sh")
		self.runCMD(self.getPluginPath()+"/scripts/megaraid_build.sh")
		return "All unconfigured disks have been added to individual RAID 0 instances."
		
	