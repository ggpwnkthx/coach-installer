angular.module('coach').controller('CoachStorageCephController', function ($scope, notify, pageTitle, storage, ceph, bootstrap) {
	pageTitle.set('Storage');
	
	$scope.reload = () => {
		$scope.addOSD = null;
		$scope.blockDevices = null;
		$scope.cephOSDs = [];
		$scope.cephAddPool = {};
		$scope.pools = [];
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
				$scope.updateClusterStatus();
			}
		});
	}
	
	
	$scope.reload();
	
	$scope.MegaRAID_build = () => {
		storage.megaraidBuild().then((data) => {
			$scope.reload();
		});
	}
	
	$scope.updateClusterStatus = () => {
		ceph.getCephStat().then((data) => {
			$scope.ceph_status = data;
			$scope.getOSDTree();
			$scope.setClusterAge();
			$scope.setCephPools();
			$scope.setCephPgNum();
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
		var now = new Date();
		var today = new Date(now.getYear(),now.getMonth(),now.getDate());

		var yearNow = now.getYear();
		var monthNow = now.getMonth();
		var dateNow = now.getDate();

		var dob = new Date(Date.parse($scope.ceph_status.monmap.created))

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
	}
	$scope.getOSDTree = () => {
		var margin = {top: 10, right: 120, bottom: 20, left: 120},
			width = $("#osd_tree").parent().width() - margin.right - margin.left,
			height = $scope.ceph_status.osdmap.osdmap.num_osds * 20 - margin.top - margin.bottom;
		var color = d3.scale.category20c();
			
		var i = 0,
			duration = 0,
			root;
		var tree = d3.layout.tree()
			.size([height, width]);
		var diagonal = d3.svg.diagonal()
			.projection(function(d) { return [d.y, d.x]; });
		var svg = d3.select("[id='osd_tree']")
			.attr("width", width + margin.right + margin.left)
			.attr("height", height + margin.top + margin.bottom)
		  .append("g")
			.attr("transform", "translate(" + margin.left + "," + margin.top + ")");
		d3.json("/api/coach/storage/ceph/osd/tree", function(error, flare) {
		  root = flare;
		  root.x0 = height / 2;
		  root.y0 = 0;
		  function collapse(d) {
			if (d.children) {
			  d._children = d.children;
			  d._children.forEach(collapse);
			  d.children = null;
			}
		  }
		  //root.children.forEach(collapse);
		  update(root);
		  //click(root.children[1]);
		});
		d3.select(self.frameElement).style("height", "800px");
		function update(source) {
		  // Compute the new tree layout.
		  var nodes = tree.nodes(root).reverse(),
			  links = tree.links(nodes);
		  // Normalize for fixed-depth.
		  nodes.forEach(function(d) { d.y = d.depth * 180; });
		  // Update the nodes…
		  var node = svg.selectAll("g.node")
			  .data(nodes, function(d) { return d.id || (d.id = ++i); });
		  // Enter any new nodes at the parent's previous position.
		  var nodeEnter = node.enter().append("g")
			  .attr("class", "node")
			  .attr("transform", function(d) { return "translate(" + source.y0 + "," + source.x0 + ")"; })
			  .on("click", click);
		  nodeEnter.append("circle")
			  .attr("class", "node")
			  .attr("r", 5)
			  .style("fill", function(d) {
				switch (d.depth) {
					case 0: return "#5e6a71";
					case 1: return "#5e6a71";
					//case 1: return color(d.name);
					case 2: return (d.status == "up" ? "#00de00" : "#b51a00");
				}
			  });
			  
		  nodeEnter.append("text")
			  .attr("x", function(d) { return d.children || d._children ? -10 : 10; })
			  .attr("dy", ".35em")
			  .attr("text-anchor", function(d) { return d.children || d._children ? "end" : "start"; })
			  .text(function(d) {
				switch (d.depth) {
					case 0: return "ceph";
					default: return d.name;
				}
			  })
			  .style("fill-opacity", 1e-6);
		  // Transition nodes to their new position.
		  var nodeUpdate = node.transition()
			  .duration(duration)
			  .attr("transform", function(d) { return "translate(" + d.y + "," + d.x + ")"; });
		  nodeUpdate.select("rect")
			  .attr("width", 8)
			  .attr("height", 16)
			  .style("fill", function(d) {
				switch (d.depth) {
					case 0: return "#5e6a71";
					case 1: return "#5e6a71";
					//case 1: return color(d.name);
					case 2: return (d.status == "up" ? "#00de00" : "#b51a00");
				}
			  });
		  nodeUpdate.select("text")
			  .style("fill-opacity", 1);
		  // Transition exiting nodes to the parent's new position.
		  var nodeExit = node.exit().transition()
			  .duration(duration)
			  .attr("transform", function(d) { return "translate(" + source.y + "," + source.x + ")"; })
			  .remove();
		  nodeExit.select("square")
			  .attr("width", 1e-6)
			  .attr("height", 1e-6);
		  nodeExit.select("text")
			  .style("fill-opacity", 1e-6);
		  // Update the links…
		  var link = svg.selectAll("path.link")
			  .data(links, function(d) { return d.target.id; });
		  // Enter any new links at the parent's previous position.
		  link.enter().insert("path", "g")
			  .attr("class", "link")
			  .attr("d", function(d) {
				var o = {x: source.x0, y: source.y0};
				return diagonal({source: o, target: o});
			  });
		  // Transition links to their new position.
		  link.transition()
			  .duration(duration)
			  .attr("d", diagonal);
		  // Transition exiting nodes to the parent's new position.
		  link.exit().transition()
			  .duration(duration)
			  .attr("d", function(d) {
				var o = {x: source.x, y: source.y};
				return diagonal({source: o, target: o});
			  })
			  .remove();
		  // Stash the old positions for transition.
		  nodes.forEach(function(d) {
			d.x0 = d.x;
			d.y0 = d.y;
		  });
			if ($("#osd_tree").children().length > 1) {
				$("#osd_tree").children().first().remove();
			}
		}
		// Toggle children on click.
		function click(d) {
		  if (d.children) {
			d._children = d.children;
			d.children = null;
		  } else {
			d.children = d._children;
			d._children = null;
		  }
		  update(d);
		}
	}
	$scope.setCephPools = () => {
		ceph.getCephOsdPoolList().then((pools) => {
			if (pools == "Root permission required") {
				return
			}
			$scope.pools = pools;
			$scope.pools.sort(function(a, b) {
				return parseFloat(a.pool_id) - parseFloat(b.pool_id);
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
	if ($("#storage-ceph").length) {
		setInterval(function(){ $scope.updateClusterStatus(); }, 5000);
	}
});
