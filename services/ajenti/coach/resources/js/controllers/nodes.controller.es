angular.module('coach').controller('CoachNodesController', function ($scope, notify, pageTitle) {
	pageTitle.set('Nodes');

	$scope.counter = 0;

	$scope.click = () => {
		$scope.counter += 1;
		notify.info('+1');
	};
});
