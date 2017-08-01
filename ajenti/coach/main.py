from jadi import component
from aj.plugins.core.api.sidebar import SidebarItemProvider
import os.path

@component(SidebarItemProvider)
class ItemProvider(SidebarItemProvider):
	def __init__(self, context):
		pass

	def provide(self):
		if os.path.isfile("/etc/systemd/system/provisioner-dnsmasq.service"):
			return [
				{
					'attach': None,
					'id': 'category:cluster',
					'name': _('Cluster'),
					'children': [
						{
							'attach': 'category:cluster',
							'name': 'Fabric',
							'icon': 'sitemap',
							'url': '/view/cluster/fabric',
							'children': []
							},
						{
							'attach': 'category:cluster',
							'name': 'Storage',
							'icon': 'hdd-o',
							'url': '/view/cluster/storage',
							'children': []
							},
						{
							'attach': 'category:cluster',
							'name': 'Nodes',
							'icon': 'server',
							'url': '/view/cluster/nodes',
							'children': []
						}
					]
				}
			]
		else:
			return [
				{
					'attach': None,
					'id': 'category:cluster',
					'name': _('Cluster'),
					'children': [
						{
							'attach': 'category:cluster',
							'name': 'Bootstrap',
							'icon': 'rocket',
							'url': '/view/cluster/bootstrap',
							'children': []
						},
					]
				}
			]