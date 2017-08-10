angular.module('coach').service('storage', function($http, $q, tasks) {
	
	this.getBlockDevices = () => {
		return $http.get("/api/coach/storage/local/list/block_devices").then(response => response.data)
	}
	this.getDriveBays = () => {
		return $http.get("/api/coach/storage/local/list/bays").then(response => response.data)
	}
	
	this.megaraidExists = () => {
		return $http.get("/api/coach/storage/local/megaraid/exists").then(response => response.data)
	};
	this.megaraidBuild = () => {
		return $http.get("/api/coach/storage/local/megaraid/build").then(response => response.data)
	};
	
    return this;
});