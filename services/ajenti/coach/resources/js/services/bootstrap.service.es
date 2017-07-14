angular.module('coach').service('bootstrap', function($http, $q, tasks) {

	this.start = (config) => {
		return $http.post("/api/coach/bootstrap", config).then(response => response.data)
	};
	
    return this;
});