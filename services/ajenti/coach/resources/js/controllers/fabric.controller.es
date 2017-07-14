angular.module('coach').controller('CoachFabricController', function ($scope, notify, pageTitle, fabric, config) {
	pageTitle.set('Fabric');

	$scope.reload = () => {
        $scope.links = null;
        fabric.getLinks().then((data) => {
            $scope.links = data;
        });
    };
	
	$scope.reload();
});
