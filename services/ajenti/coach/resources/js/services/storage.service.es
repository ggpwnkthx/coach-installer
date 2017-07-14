angular.module('coach').service('storage', function($http, $q, tasks) {
	
	this.getBlockDevices = () => {
		return $http.get("/api/coach/storage/local/list/block_devices").then(response => response.data)
	}
	this.getCephMonStat = () => {
		return $http.get("/api/coach/storage/ceph/monitor/status").then(response => response.data)
	};
	
    return this;
});