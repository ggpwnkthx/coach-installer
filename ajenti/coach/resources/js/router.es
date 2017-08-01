angular.module('coach').config(($routeProvider) => {
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