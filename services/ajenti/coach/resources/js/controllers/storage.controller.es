angular.module('coach').controller('CoachStorageController', function ($scope, notify, pageTitle, storage) {
	pageTitle.set('Storage');

	$scope.reload = () => {
		$scope.blockDevices = null;
		storage.getBlockDevices().then((data) => {
            $scope.blockDevices = data.blockdevices;
        });
    };
	
	$scope.reload();
	
});
