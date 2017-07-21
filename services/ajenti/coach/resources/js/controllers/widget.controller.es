angular.module('coach').controller('CephController', ($scope, storage)  => {
	$scope.$on('widget-update', ($event, id, data) => {
        if (id !== $scope.widget.id) {
            return;
        }
		storage.getCephOsdTree().then((data) => {
			$scope.value = data
			console.log($scope.value)
		});
	});
});

angular.module('coach').controller('CephConfigController', ($scope) => {
	$scope.configuredWidget.config.name = "ceph"
});