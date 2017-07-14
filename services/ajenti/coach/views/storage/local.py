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
		
	@url(r'/api/coach/storage/local/list/block_devices')
	@endpoint(api=True)
	def handle_api_storage_monitor_status(self, http_context):
		return json.loads(self.runCMD("lsblk -OJ"))
