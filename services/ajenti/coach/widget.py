import os
import json
import subprocess
import re
from jadi import component

from aj.plugins.dashboard.api import Widget


@component(Widget)
class CephWidget(Widget):
	id = 'ceph'

	# display name
	name = 'Ceph'

	# template of the widget
	template = '/coach:resources/partial/widget.html'

	# template of the configuration dialog
	config_template = '/coach:resources/partial/widget.config.html'
	def runCMD(self, cmd):
		ps = subprocess.Popen(cmd,shell=True,stdout=subprocess.PIPE,stderr=subprocess.STDOUT)
		output = ps.communicate()[0]
		return output

	def __init__(self, context):
		Widget.__init__(self, context)

	def get_value(self, config):
		return None