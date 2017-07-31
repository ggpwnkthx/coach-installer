import os
import json
import subprocess
import re
from jadi import component

from aj.plugins.dashboard.api import Widget


@component(Widget)
class CephPageWidget(Widget):
	id = 'ceph_pages'

	# display name
	name = 'Ceph Pages'

	# template of the widget
	template = '/coach:resources/partial/widgets/ceph_pages.html'

	# template of the configuration dialog
	config_template = '/coach:resources/partial/widgets/ceph_pages.config.html'
	def __init__(self, context):
		Widget.__init__(self, context)

	def get_value(self, config):
		return None