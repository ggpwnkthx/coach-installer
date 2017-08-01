angular.module('coach').controller('CoachBootstrapController', function ($scope, $location, notify, pageTitle, bootstrap, fabric, core) {
	pageTitle.set('Fabric');

	$scope.reload = () => {
		$scope.task = "fabric";
		bootstrap.isCephInstalled().then((data) => {
			if(data){
				$scope.task = "storage";
			}
		});
		bootstrap.isCephFS().then((data) => {
			if(data){
				$scope.task = "network";
				$scope.installNetworkServices();
			}
		});
		fabric.getFQDN().then((data) => {
			$scope.fqdn = data;
		});
        $scope.links = null;
		$scope.gaterthingData = false;
		$scope.dhcpFoundBut = false;
		$scope.dhcpFound = false;
		$scope.dhcpNotFound = false;
		$scope.showBootstrap = false;
		$scope.creatingFabric = false;
		$scope.processingBootstrap = false;
		$scope.bootstrapDone = false;
        fabric.getLinks().then((data) => {
            $scope.links = data;
        });
    };
	
	$scope.reload();
	
	$scope.dhcpSearch = (iface) => {
		$scope.gaterthingData = true;
		fabric.dhcpSearch(iface).then((data) => {
			notify.info(data);
			$scope.gaterthingData = false;
			switch(data) {
				case "Dependancies were installed.":
					$scope.dhcpSearch(iface);
					break;
				case "Not ready.":
					$scope.dhcpFoundBut = true;
					break;
				case "Ready to add.":
					$scope.dhcpFound = true;
					break;
				case "Ready to create.":
					$scope.dhcpNotFound = true;
					break;
			}
		});
	}
	
	$scope.bootstrap = () => {
		$scope.gaterthingData = false;
		$scope.dhcpFoundBut = false;
		$scope.dhcpFound = false;
		$scope.dhcpNotFound = false;
		$scope.showBootstrap = true;
	}
	
	$scope.connectToFabric = (iface, toFabric) => {
		fabric.connectToFabric(iface, toFabric).then((data) => {
			notify.info(data);
		});
	}
	
	$scope.createCluster = (config) => {
		$scope.showBootstrap = false;
		$scope.creatingFabric = true;
		$scope.processingBootstrap = true;
		bootstrap.start({'iface': config.name, 'cidr': config.ipv4[0], 'fqdn': config.fqdn}).then((data) => {
			notify.info(data);
			switch(data) {
				case "Bootstrap completed.":
					$scope.reload();
					break;
				default:
					$scope.createCluster(config);
					break;
			}
		});
	}
	
	$scope.installCephFS = (config = null) => {
		$scope.task = "cephfs";
		if(config == null) {
			config = {
				'cluster': 'ceph',
				'fs': 'cephfs'
			};
		}
		bootstrap.installCephFS(config).then((data) => {
			notify.info(data);
			switch(data) {
				case "Clustered file system ready.":
					$scope.mountCephFS();
					break;
				default:
					$scope.installCephFS(config);
					break;
			}
		});
	}
	
	$scope.mountCephFS = () => {
		bootstrap.mountCephFS().then((data) => {
			notify.info(data);
			switch(data) {
				case "CephFS Ready.":
					$scope.reload();
					break;
				default:
					$scope.mountCephFS(config);
					break;
			}
		});
	}
	
	$scope.installNetworkServices = () => {
		$scope.task = "network";
		bootstrap.installNetworkServices().then((data) => {
			notify.info(data);
			switch(data) {
				case "Ready.":
					$scope.task = "done"
					break;
				default:
					$scope.installNetworkServices();
					break;
			}
		});
	}
});
