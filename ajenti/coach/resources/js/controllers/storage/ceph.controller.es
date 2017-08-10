angular.module('coach').controller('CoachStorageCephController', function ($scope, notify, pageTitle, storage, ceph, bootstrap) {
	pageTitle.set('Storage');

	$scope.reload = () => {
		$scope.addOSD = null;
		$scope.blockDevices = null;
		$scope.cephOSDs = [];
		$scope.cephAddPool = {};
		storage.megaraidExists().then((data) => {
			$scope.megaraidExists = data;
		});
		
		storage.getDriveBays().then((bays) => {
			if (bays == "Root permission required") {
				return
			}
			$scope.setCephOSDs(bays);
        });
		bootstrap.isCephFS().then((data) => {
			if(data){
				$scope.setClusterAge();
				$scope.setCephPools();
				$scope.setCephPgNum();
			}
		});
	}
	
	$scope.reload();
	
	$scope.MegaRAID_build = () => {
		storage.megaraidBuild().then((data) => {
			$scope.reload();
		});
	}
	
	$scope.setCephOSDs = (bays) => {
		storage.getBlockDevices().then((data) => {
			$scope.blockDevices = data.blockdevices;
			if($scope.blockDevices.length){
				$scope.blockDevices.forEach(function(device, index) {
					device.ceph = {};
					device.bay = ""+bays[device.name]
					if (typeof device.bay === 'undefined') {
						device.bay = null;
					}
					if (device.children) {
						device.available = false;
						device.children.forEach(function(partition, index) {
							if (partition.partlabel == "ceph data") {
								device.ceph.osd = true;
								config = {};
								config.osd = device;
								ceph.getCephOsdDetails(config).then((details) => {
									if (details == "Root permission required") {
										return
									}
									device.ceph.details = details;
									$scope.blockDevices.forEach(function(deviceB, index) {
										if (deviceB.name == device.ceph.details.journal) {
											if (typeof deviceB.ceph.journalFor == "undefined") {
												deviceB.ceph.journalFor = [device.name]
											} else {
												deviceB.ceph.journalFor.push(device.name)
											}
										}
									});
								});
							}
							if (partition.partlabel == "ceph journal") {
								device.ceph.journal = true;
								if (device.ceph.osd) {
									device.ceph.journal = false;
									device.ceph.canBeJournal = false;
								} else {
									device.ceph.canBeJournal = true;
								}
							}
						});
					} else {
						device.available = true;
						if (device.rota == 1) {
							device.ceph.canBeJournal = false;
						} else {
							device.ceph.canBeJournal = true;
						}
					}
				});
				$scope.blockDevices.sort(function(a, b) {
					return parseFloat(a.bay) - parseFloat(b.bay);
				});
			}
		});
	}
	$scope.toggleAddOSD = (device = null) => {
		$scope.addOSD = device;
	}
	$scope.cephAddOsd = (osd, journal = null) => {
		$scope.cephAddOsdProcessing = true;
		config = {};
		config.osd = osd.name;
		if (journal) {
			config.journal = journal.name;
		}
		ceph.cephAddOsd(config).then((data) => {
			notify.info(data);
			$scope.cephAddOsdProcessing = false;
			$scope.addOSD = null;
			$scope.reload();
		});
	}
	$scope.toggleRemoveOSD = (device = null) => {
		$scope.removeOSD = device;
	}
	$scope.cephRemoveOsd = (osd) => {
		$scope.cephRemoveOsdProcessing = true;
		config = {};
		config.osd = osd.name;
		ceph.cephRemoveOsd(config).then((data) => {
			notify.info(data);
			$scope.cephRemoveOsdProcessing = false;
			$scope.removeOSD = null;
			$scope.reload();
		});
	}
	
	$scope.setClusterAge = () => {
		ceph.getCephMonStat().then((monitors) => {
			if (monitors == "Root permission required") {
				return
			}
			$scope.monitors = monitors;
			var now = new Date();
			var today = new Date(now.getYear(),now.getMonth(),now.getDate());

			var yearNow = now.getYear();
			var monthNow = now.getMonth();
			var dateNow = now.getDate();

			var dob = new Date(Date.parse($scope.monitors.monmap.created))

			var yearDob = dob.getYear();
			var monthDob = dob.getMonth();
			var dateDob = dob.getDate();
			var age = {};
			var ageString = "";
			var yearString = "";
			var monthString = "";
			var dayString = "";


			yearAge = yearNow - yearDob;

			if (monthNow >= monthDob)
				monthAge = monthNow - monthDob;
			else {
				yearAge--;
				var monthAge = 12 + monthNow -monthDob;
			}

			if (dateNow >= dateDob)
				var dateAge = dateNow - dateDob;
			else {
				monthAge--;
				var dateAge = 31 + dateNow - dateDob;

				if (monthAge < 0) {
				  monthAge = 11;
				  yearAge--;
				}
			}

			age = {
			  years: yearAge,
			  months: monthAge,
			  days: dateAge
			  };

			if ( age.years > 1 ) yearString = " years";
			else yearString = " year";
			if ( age.months> 1 ) monthString = " months";
			else monthString = " month";
			if ( age.days > 1 ) dayString = " days";
			else dayString = " day";


			if ( (age.years > 0) && (age.months > 0) && (age.days > 0) )
			ageString = age.years + yearString + ", " + age.months + monthString + ", and " + age.days + dayString + " old.";
			else if ( (age.years == 0) && (age.months == 0) && (age.days > 0) )
			ageString = "Only " + age.days + dayString + " old!";
			else if ( (age.years > 0) && (age.months == 0) && (age.days == 0) )
			ageString = age.years + yearString + " old. Happy Birthday!!";
			else if ( (age.years > 0) && (age.months > 0) && (age.days == 0) )
			ageString = age.years + yearString + " and " + age.months + monthString + " old.";
			else if ( (age.years == 0) && (age.months > 0) && (age.days > 0) )
			ageString = age.months + monthString + " and " + age.days + dayString + " old.";
			else if ( (age.years > 0) && (age.months == 0) && (age.days > 0) )
			ageString = age.years + yearString + " and " + age.days + dayString + " old.";
			else if ( (age.years == 0) && (age.months > 0) && (age.days == 0) )
			ageString = age.months + monthString + " old.";
			else ageString = "Oops! Could not calculate age!";
			$scope.age = ageString;
		});
	}
	
	$scope.setCephPools = () => {
		ceph.getCephOsdPoolList().then((pools) => {
			if (pools == "Root permission required") {
				return
			}
			$scope.pools = [];
			pools.forEach(function(value, index) {
				ceph.getCephOsdPoolDetails(value).then((data) => {
					$scope.pools.push(data)
				});
			});
		});
	}
	$scope.cephRemovePool = (pool) => {
		ceph.cephOsdPoolRemove(pool).then((data) => {
			notify.info(data);
			$scope.setCephPools();
		});
	}
	$scope.setCephPgNum = () => {
		ceph.getCephOsdStat().then((data) => {
			if (data.num_osds < 5) {
				$scope.pg_num = 128;
			} else if (data.num_osds < 10) {
				$scope.pg_num = 512;
			} else if (data.num_osds < 50) {
				$scope.pg_num = 1024;
			} else {
				$scope.pg_num = "Use pgcalc.";
			}
			if ($scope.pg_num !== "Use pgcalc.") {
				$scope.cephAddPool.pg_num = $scope.pg_num;
			}
		});
	}
	$scope.cephCreatePool = (config) => {
		ceph.cephOsdPoolCreate(config).then((data) => {
			notify.info(data);
			$scope.setCephPools();
			$scope.cephAddPool.name = null;
		});
	}
});
