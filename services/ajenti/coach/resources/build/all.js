'use strict';

angular.module('coach', ['core']);


'use strict';

angular.module('coach').config(function ($routeProvider) {
    $routeProvider.when('/view/cluster/bootstrap', {
        templateUrl: '/coach:resources/partial/bootstrap.html',
        controller: 'CoachBootstrapController'
    });

    $routeProvider.when('/view/cluster/fabric', {
        templateUrl: '/coach:resources/partial/fabric.html',
        controller: 'CoachFabricController'
    });

    $routeProvider.when('/view/cluster/nodes', {
        templateUrl: '/coach:resources/partial/nodes.html',
        controller: 'CoachNodesController'
    });

    $routeProvider.when('/view/cluster/storage', {
        templateUrl: '/coach:resources/partial/storage.html',
        controller: 'CoachStorageController'
    });
});


'use strict';

angular.module('coach').controller('CoachBootstrapController', function ($scope, $location, notify, pageTitle, bootstrap, fabric, core) {
	pageTitle.set('Fabric');

	$scope.reload = function () {
		fabric.getFQDN().then(function (data) {
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
		fabric.getLinks().then(function (data) {
			$scope.links = data;
		});
	};

	$scope.reload();

	$scope.dhcpSearch = function (iface) {
		$scope.gaterthingData = true;
		fabric.dhcpSearch(iface).then(function (data) {
			notify.info(data);
			$scope.gaterthingData = false;
			switch (data) {
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
	};

	$scope.bootstrap = function () {
		$scope.gaterthingData = false;
		$scope.dhcpFoundBut = false;
		$scope.dhcpFound = false;
		$scope.dhcpNotFound = false;
		$scope.showBootstrap = true;
	};

	$scope.connectToFabric = function (iface, toFabric) {
		fabric.connectToFabric(iface, toFabric).then(function (data) {
			notify.info(data);
		});
	};

	$scope.createCluster = function (config) {
		$scope.showBootstrap = false;
		$scope.creatingFabric = true;
		$scope.processingBootstrap = true;
		bootstrap.start({ 'iface': config.name, 'cidr': config.ipv4[0], 'fqdn': config.fqdn }).then(function (data) {
			notify.info(data);
			switch (data) {
				case "Bootstrap completed.":
					$scope.creatingFabric = false;
					$scope.bootstrapDone = true;
					break;
				default:
					$scope.createCluster(config);
					break;
			}
		});
	};

	$scope.gotoStorage = function () {
		core.restart();
		$location.path("/view/cluster/storage");
	};
});


'use strict';

angular.module('coach').service('bootstrap', function ($http, $q, tasks) {

	this.start = function (config) {
		return $http.post("/api/coach/bootstrap", config).then(function (response) {
			return response.data;
		});
	};

	return this;
});


'use strict';

angular.module('coach').controller('CoachFabricController', function ($scope, notify, pageTitle, fabric, config) {
  pageTitle.set('Fabric');

  $scope.reload = function () {
    $scope.links = null;
    fabric.getLinks().then(function (data) {
      $scope.links = data;
    });
  };

  $scope.reload();
});


'use strict';

angular.module('coach').service('fabric', function ($http, $q, tasks) {
				this.getLinks = function () {
								return $http.get("/api/coach/fabric/get/links").then(function (response) {
												return response.data;
								});
				};
				this.getFQDN = function () {
								return $http.get("/api/coach/fabric/get/fqdn").then(function (response) {
												return response.data;
								});
				};

				this.dhcpSearch = function (iface) {
								return $http.get("/api/coach/fabric/dhcp_search/" + iface).then(function (response) {
												return response.data;
								});
				};

				this.connectToFabric = function (iface, fabric) {
								return $http.get("/api/coach/fabric/connect/" + iface + "/" + fabric).then(function (response) {
												return response.data;
								});
				};

				return this;
});


'use strict';

angular.module('coach').controller('CoachNodesController', function ($scope, notify, pageTitle) {
	pageTitle.set('Nodes');

	$scope.counter = 0;

	$scope.click = function () {
		$scope.counter += 1;
		notify.info('+1');
	};
});


'use strict';

angular.module('coach').controller('CoachStorageController', function ($scope, notify, pageTitle, storage) {
	pageTitle.set('Storage');

	$scope.reload = function () {
		$scope.blockDevices = null;
		storage.getBlockDevices().then(function (data) {
			$scope.blockDevices = data.blockdevices;
		});
	};

	$scope.reload();
});


'use strict';

angular.module('coach').service('storage', function ($http, $q, tasks) {

	this.getBlockDevices = function () {
		return $http.get("/api/coach/storage/local/list/block_devices").then(function (response) {
			return response.data;
		});
	};
	this.getCephMonStat = function () {
		return $http.get("/api/coach/storage/ceph/monitor/status").then(function (response) {
			return response.data;
		});
	};

	return this;
});


