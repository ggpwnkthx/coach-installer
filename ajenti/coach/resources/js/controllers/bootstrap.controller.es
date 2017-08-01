angular.module('coach').controller('CoachBootstrapController', function ($scope, $location, notify, pageTitle, bootstrap, fabric, core) {
	pageTitle.set('Fabric');

	$scope.reload = () => {
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
					$scope.creatingFabric = false;
					$scope.bootstrapDone = true;
					break;
				default:
					$scope.createCluster(config);
					break;
			}
		});
	}
	
	$scope.gotoStorage = () => {
		core.restart();
		$location.path("/view/cluster/storage");
	}
});
