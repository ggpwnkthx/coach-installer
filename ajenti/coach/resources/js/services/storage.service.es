angular.module('coach').service('storage', function($http, $q, tasks) {
	
	this.getBlockDevices = () => {
		return $http.get("/api/coach/storage/local/list/block_devices").then(response => response.data)
	}
	this.getDriveBays = () => {
		return $http.get("/api/coach/storage/local/list/bays").then(response => response.data)
	}
	
	this.getCephMonStat = () => {
		return $http.get("/api/coach/storage/ceph/mon/status").then(response => response.data)
	};
	this.getCephOsdDetails = (config) => {
		return $http.post("/api/coach/storage/ceph/osd/details", config).then(response => response.data)
	}
	this.getCephOsdStat = () => {
		return $http.get("/api/coach/storage/ceph/osd/stat", ).then(response => response.data)
	}
	this.getCephOsdPoolList = () => {
		return $http.get("/api/coach/storage/ceph/osd/pool/list").then(response => response.data)
	}
	this.getCephOsdPoolDetails = (pool) => {
		return $http.get("/api/coach/storage/ceph/osd/pool/"+pool).then(response => response.data)
	}
	this.cephOsdPoolRemove = (pool) => {
		return $http.get("/api/coach/storage/ceph/osd/pool/remove/"+pool).then(response => response.data)
	}
	this.cephOsdPoolCreate = (config) => {
		return $http.post("/api/coach/storage/ceph/osd/pool/create/", config).then(response => response.data)
	}
	this.getCephOsdTree = (config) => {
		return $http.get("/api/coach/storage/ceph/osd/tree", config).then(response => response.data)
	}
	this.cephAddOsd = (config) => {
		return $http.post("/api/coach/storage/ceph/osd/add", config).then(response => response.data)
	};
	this.cephRemoveOsd = (config) => {
		return $http.post("/api/coach/storage/ceph/osd/remove", config).then(response => response.data)
	};
	this.getCephPgTree = () => {
		return $http.get("/api/coach/storage/ceph/pg/tree").then(response => response.data)
	}
	this.getCephPgMap = () => {
		return $http.get("/api/coach/storage/ceph/pg/map").then(response => response.data)
	}
	this.getCephIops = () => {
		return $http.get("/api/coach/storage/ceph/iops").then(response => response.data)
	}
	
	this.megaraidExists = () => {
		return $http.get("/api/coach/storage/local/megaraid/exists").then(response => response.data)
	};
	this.megaraidBuild = () => {
		return $http.get("/api/coach/storage/local/megaraid/build").then(response => response.data)
	};
	
    return this;
});