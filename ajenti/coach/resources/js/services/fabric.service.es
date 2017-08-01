angular.module('coach').service('fabric', function($http, $q, tasks) {
    this.getLinks = () => {
        return $http.get("/api/coach/fabric/get/links").then(response => response.data)
    };
    this.getFQDN = () => {
        return $http.get("/api/coach/fabric/get/fqdn").then(response => response.data)
    };
	
	this.dhcpSearch = (iface) => {
		return $http.get("/api/coach/fabric/dhcp_search/"+iface).then(response => response.data)
	}
	
	this.connectToFabric = (iface, fabric) => {
		return $http.get("/api/coach/fabric/connect/"+iface+"/"+fabric).then(response => response.data)
	};
	
    return this;
});