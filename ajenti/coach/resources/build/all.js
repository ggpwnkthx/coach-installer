'use strict';

angular.module('coach', ['core', 'ajenti.dashboard']);


'use strict';

angular.module('coach').config(function ($routeProvider) {
    $routeProvider.when('/view/cluster/bootstrap', {
        templateUrl: '/coach:resources/partial/bootstrap.html',
        controller: 'CoachBootstrapController'
    });

    $routeProvider.when('/view/cluster/fabric', {
        templateUrl: '/coach:resources/partial/fabric.html',
        controller: 'CoachFabricController'
    });

    $routeProvider.when('/view/cluster/nodes', {
        templateUrl: '/coach:resources/partial/nodes.html',
        controller: 'CoachNodesController'
    });

    $routeProvider.when('/view/cluster/storage', {
        templateUrl: '/coach:resources/partial/storage.html',
        controller: 'CoachStorageController'
    });
});


'use strict';

angular.module('coach').controller('CoachBootstrapController', function ($scope, $location, notify, pageTitle, bootstrap, fabric, core) {
	pageTitle.set('Fabric');

	$scope.reload = function () {
		$scope.task = "fabric";
		bootstrap.isCephInstalled().then(function (data) {
			if (data) {
				$scope.task = "storage";
			}
		});
		bootstrap.isCephFS().then(function (data) {
			if (data) {
				$scope.task = "network";
				$scope.installNetworkServices();
			}
		});
		fabric.getFQDN().then(function (data) {
			$scope.fqdn = data;
		});
		$scope.links = null;
		$scope.gaterthingData = false;
		$scope.dhcpFoundBut = false;
		$scope.dhcpFound = false;
		$scope.dhcpNotFound = false;
		$scope.showBootstrap = false;
		$scope.creatingFabric = false;
		$scope.processingBootstrap = false;
		$scope.bootstrapDone = false;
		fabric.getLinks().then(function (data) {
			$scope.links = data;
		});
	};

	$scope.reload();

	$scope.dhcpSearch = function (iface) {
		$scope.gaterthingData = true;
		fabric.dhcpSearch(iface).then(function (data) {
			notify.info(data);
			$scope.gaterthingData = false;
			switch (data) {
				case "Dependancies were installed.":
					$scope.dhcpSearch(iface);
					break;
				case "Not ready.":
					$scope.dhcpFoundBut = true;
					break;
				case "Ready to add.":
					$scope.dhcpFound = true;
					break;
				case "Ready to create.":
					$scope.dhcpNotFound = true;
					break;
			}
		});
	};

	$scope.bootstrap = function () {
		$scope.gaterthingData = false;
		$scope.dhcpFoundBut = false;
		$scope.dhcpFound = false;
		$scope.dhcpNotFound = false;
		$scope.showBootstrap = true;
	};

	$scope.connectToFabric = function (iface, toFabric) {
		fabric.connectToFabric(iface, toFabric).then(function (data) {
			notify.info(data);
		});
	};

	$scope.createCluster = function (config) {
		$scope.showBootstrap = false;
		$scope.creatingFabric = true;
		$scope.processingBootstrap = true;
		bootstrap.start({ 'iface': config.name, 'cidr': config.ipv4[0], 'fqdn': config.fqdn }).then(function (data) {
			notify.info(data);
			switch (data) {
				case "Bootstrap completed.":
					$scope.reload();
					break;
				default:
					$scope.createCluster(config);
					break;
			}
		});
	};

	$scope.installCephFS = function () {
		var config = arguments.length > 0 && arguments[0] !== undefined ? arguments[0] : null;

		$scope.task = "cephfs";
		if (config == null) {
			config = {
				'cluster': 'ceph',
				'fs': 'cephfs'
			};
		}
		bootstrap.installCephFS(config).then(function (data) {
			notify.info(data);
			switch (data) {
				case "Clustered file system ready.":
					$scope.mountCephFS();
					break;
				default:
					$scope.installCephFS(config);
					break;
			}
		});
	};

	$scope.mountCephFS = function () {
		bootstrap.mountCephFS().then(function (data) {
			notify.info(data);
			switch (data) {
				case "CephFS Ready.":
					$scope.reload();
					break;
				default:
					$scope.mountCephFS(config);
					break;
			}
		});
	};

	$scope.installNetworkServices = function () {
		$scope.task = "network";
		bootstrap.installNetworkServices().then(function (data) {
			notify.info(data);
			switch (data) {
				case "Ready.":
					$scope.task = "done";
					break;
				default:
					$scope.installNetworkServices();
					break;
			}
		});
	};
});


'use strict';

angular.module('coach').controller('CoachFabricController', function ($scope, notify, pageTitle, fabric, config) {
    pageTitle.set('Fabric');

    $scope.reload = function () {
        $scope.links = null;
        fabric.getLinks().then(function (data) {
            $scope.links = data;
        });
    };

    $scope.reload();
});


'use strict';

angular.module('coach').controller('CoachNodesController', function ($scope, notify, pageTitle) {
	pageTitle.set('Nodes');

	$scope.counter = 0;

	$scope.click = function () {
		$scope.counter += 1;
		notify.info('+1');
	};
});


'use strict';

angular.module('coach').controller('CoachStorageController', function ($scope, notify, pageTitle, storage) {
	pageTitle.set('Storage');

	$scope.reload = function () {
		$scope.addOSD = null;
		$scope.blockDevices = null;
		$scope.cephOSDs = [];

		storage.megaraidExists().then(function (data) {
			$scope.megaraidExists = data;
		});

		storage.getDriveBays().then(function (bays) {
			if (data == "Root permission required") {
				return;
			}
			storage.getBlockDevices().then(function (data) {
				$scope.blockDevices = data.blockdevices;
				if ($scope.blockDevices.length) {
					$scope.blockDevices.forEach(function (device, index) {
						device.ceph = {};
						device.bay = "" + bays[device.name];
						if (typeof device.bay === 'undefined') {
							device.bay = null;
						}
						if (device.children) {
							device.available = false;
							device.children.forEach(function (partition, index) {
								if (partition.partlabel == "ceph data") {
									device.ceph.osd = true;
									config = {};
									config.osd = device;
									storage.getCephOsdDetails(config).then(function (details) {
										if (data == "Root permission required") {
											return;
										}
										device.ceph.details = details;
										$scope.blockDevices.forEach(function (deviceB, index) {
											if (deviceB.name == device.ceph.details.journal) {
												if (typeof deviceB.ceph.journalFor == "undefined") {
													deviceB.ceph.journalFor = [device.name];
												} else {
													deviceB.ceph.journalFor.push(device.name);
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
					$scope.blockDevices.sort(function (a, b) {
						return parseFloat(a.bay) - parseFloat(b.bay);
					});
				}
			});
		});
		if ($("#osd").length) {
			storage.getCephMonStat().then(function (monitors) {
				if (data == "Root permission required") {
					return;
				}
				$scope.monitors = monitors;
				var now = new Date();
				var today = new Date(now.getYear(), now.getMonth(), now.getDate());

				var yearNow = now.getYear();
				var monthNow = now.getMonth();
				var dateNow = now.getDate();

				var dob = new Date(Date.parse($scope.monitors.monmap.created));

				var yearDob = dob.getYear();
				var monthDob = dob.getMonth();
				var dateDob = dob.getDate();
				var age = {};
				var ageString = "";
				var yearString = "";
				var monthString = "";
				var dayString = "";

				yearAge = yearNow - yearDob;

				if (monthNow >= monthDob) monthAge = monthNow - monthDob;else {
					yearAge--;
					var monthAge = 12 + monthNow - monthDob;
				}

				if (dateNow >= dateDob) var dateAge = dateNow - dateDob;else {
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

				if (age.years > 1) yearString = " years";else yearString = " year";
				if (age.months > 1) monthString = " months";else monthString = " month";
				if (age.days > 1) dayString = " days";else dayString = " day";

				if (age.years > 0 && age.months > 0 && age.days > 0) ageString = age.years + yearString + ", " + age.months + monthString + ", and " + age.days + dayString + " old.";else if (age.years == 0 && age.months == 0 && age.days > 0) ageString = "Only " + age.days + dayString + " old!";else if (age.years > 0 && age.months == 0 && age.days == 0) ageString = age.years + yearString + " old. Happy Birthday!!";else if (age.years > 0 && age.months > 0 && age.days == 0) ageString = age.years + yearString + " and " + age.months + monthString + " old.";else if (age.years == 0 && age.months > 0 && age.days > 0) ageString = age.months + monthString + " and " + age.days + dayString + " old.";else if (age.years > 0 && age.months == 0 && age.days > 0) ageString = age.years + yearString + " and " + age.days + dayString + " old.";else if (age.years == 0 && age.months > 0 && age.days == 0) ageString = age.months + monthString + " old.";else ageString = "Oops! Could not calculate age!";
				$scope.age = ageString;
			});

			storage.getCephOsdTree().then(function (osd_tree) {
				if (data == "Root permission required") {
					return;
				}
				$scope.cephOSDs = osd_tree;
			});
		}
	};

	$scope.reload();

	$scope.MegaRAID_build = function () {
		storage.megaraidBuild().then(function (data) {
			$scope.reload();
		});
	};

	$scope.toggleAddOSD = function () {
		var device = arguments.length > 0 && arguments[0] !== undefined ? arguments[0] : null;

		$scope.addOSD = device;
	};
	$scope.cephAddOsd = function (osd) {
		var journal = arguments.length > 1 && arguments[1] !== undefined ? arguments[1] : null;

		$scope.cephAddOsdProcessing = true;
		config = {};
		config.osd = osd.name;
		if (journal) {
			config.journal = journal.name;
		}
		storage.cephAddOsd(config).then(function (data) {
			notify.info(data);
			$scope.cephAddOsdProcessing = false;
			$scope.addOSD = null;
			$scope.reload();
		});
	};
	$scope.toggleRemoveOSD = function () {
		var device = arguments.length > 0 && arguments[0] !== undefined ? arguments[0] : null;

		$scope.removeOSD = device;
	};
	$scope.cephRemoveOsd = function (osd) {
		$scope.cephRemoveOsdProcessing = true;
		config = {};
		config.osd = osd.name;
		storage.cephRemoveOsd(config).then(function (data) {
			notify.info(data);
			$scope.cephRemoveOsdProcessing = false;
			$scope.removeOSD = null;
			$scope.reload();
		});
	};

	$scope.cephOsdTree = function () {
		id = "osd";
		$("#" + id).html("");
		var margin = { top: 0, right: 0, bottom: 0, left: 100 },
		    width = $("#" + id).parent().parent().parent().first().width() - margin.right - margin.left,
		    height = $("#" + id).parent().parent().parent().parent().parent().parent().parent().height() - $("#" + id).parent().parent().parent().first().height() - $("#" + id).parent().parent().parent().parent().parent().parent().first().height() - margin.top - margin.bottom;
		var color = d3.scale.category20c();

		var i = 0,
		    duration = 750,
		    root;
		var tree = d3.layout.tree().size([height, width]);
		var diagonal = d3.svg.diagonal().projection(function (d) {
			return [d.y, d.x];
		});
		var svg = d3.select("#osd").append("svg").attr("width", width + margin.right + margin.left).attr("height", height + margin.top + margin.bottom).append("g").attr("transform", "translate(" + margin.left + "," + margin.top + ")");
		d3.json("/api/coach/storage/ceph/osd/tree", function (error, flare) {
			root = flare;
			console.log(root);
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
			nodes.forEach(function (d) {
				d.y = d.depth * 180;
			});
			// Update the nodes…
			var node = svg.selectAll("g.node").data(nodes, function (d) {
				return d.id || (d.id = ++i);
			});
			// Enter any new nodes at the parent's previous position.
			var nodeEnter = node.enter().append("g").attr("class", "node").attr("transform", function (d) {
				return "translate(" + source.y0 + "," + source.x0 + ")";
			}).on("click", click);
			nodeEnter.append("circle").attr("class", "node").attr("r", 5).style("fill", function (d) {
				switch (d.depth) {
					case 0:
						return "#5e6a71";
					case 1:
						return "#5e6a71";
					//case 1: return color(d.name);
					case 2:
						return d.status == "up" ? "#00de00" : "#b51a00";
				}
			});

			nodeEnter.append("text").attr("x", function (d) {
				return d.children || d._children ? -10 : 10;
			}).attr("dy", ".35em").attr("text-anchor", function (d) {
				return d.children || d._children ? "end" : "start";
			}).text(function (d) {
				switch (d.depth) {
					case 0:
						return "ceph";
					default:
						return d.name;
				}
			}).style("fill-opacity", 1e-6);
			// Transition nodes to their new position.
			var nodeUpdate = node.transition().duration(duration).attr("transform", function (d) {
				return "translate(" + d.y + "," + d.x + ")";
			});
			nodeUpdate.select("rect").attr("width", 8).attr("height", 16).style("fill", function (d) {
				switch (d.depth) {
					case 0:
						return "#5e6a71";
					case 1:
						return "#5e6a71";
					//case 1: return color(d.name);
					case 2:
						return d.status == "up" ? "#00de00" : "#b51a00";
				}
			});
			nodeUpdate.select("text").style("fill-opacity", 1);
			// Transition exiting nodes to the parent's new position.
			var nodeExit = node.exit().transition().duration(duration).attr("transform", function (d) {
				return "translate(" + source.y + "," + source.x + ")";
			}).remove();
			nodeExit.select("square").attr("width", 1e-6).attr("height", 1e-6);
			nodeExit.select("text").style("fill-opacity", 1e-6);
			// Update the links…
			var link = svg.selectAll("path.link").data(links, function (d) {
				return d.target.id;
			});
			// Enter any new links at the parent's previous position.
			link.enter().insert("path", "g").attr("class", "link").attr("d", function (d) {
				var o = { x: source.x0, y: source.y0 };
				return diagonal({ source: o, target: o });
			});
			// Transition links to their new position.
			link.transition().duration(duration).attr("d", diagonal);
			// Transition exiting nodes to the parent's new position.
			link.exit().transition().duration(duration).attr("d", function (d) {
				var o = { x: source.x, y: source.y };
				return diagonal({ source: o, target: o });
			}).remove();
			// Stash the old positions for transition.
			nodes.forEach(function (d) {
				d.x0 = d.x;
				d.y0 = d.y;
			});
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
	};
	$scope.cephPgStat = function () {
		id = "pgs";
		$("#" + id).html("");
		width = $("#" + id).parent().parent().parent().first().width(), height = $("#" + id).parent().parent().parent().parent().parent().parent().parent().height() - $("#" + id).parent().parent().parent().first().height() - $("#" + id).parent().parent().parent().parent().parent().parent().first().height(), radius = Math.min(width, height) / 2 - 1;
		var x = d3.scale.linear().range([0, 2 * Math.PI]);
		var y = d3.scale.linear().range([0, radius]);
		var color = d3.scale.category20c();
		var svg = d3.select("#pgs").append("svg").attr("width", width).attr("height", height + 20).append("g").attr("transform", "translate(" + width / 2 + "," + (height / 2 + 10) + ")");
		var partition = d3.layout.partition().value(function (d) {
			return 1;
		});
		var arc = d3.svg.arc().startAngle(function (d) {
			return Math.max(0, Math.min(2 * Math.PI, x(d.x)));
		}).endAngle(function (d) {
			return Math.max(0, Math.min(2 * Math.PI, x(d.x + d.dx)));
		}).innerRadius(function (d) {
			return Math.max(0, y(d.y));
		}).outerRadius(function (d) {
			return Math.max(0, y(d.y + d.dy));
		});
		d3.json("/api/coach/storage/ceph/pg/tree", function (error, root) {
			var g = svg.selectAll("g").data(partition.nodes(root)).enter().append("g");
			var path = g.append("path").attr("d", arc).attr("width", 0).style("fill", function (d) {
				switch (d.depth) {
					case 0:
						return "#5E6A71";
					case 1:
						return color((d.children ? d : d.parent).name);
					case 2:
						switch (d.state) {
							case "active+clean":
								return "#00de00";
							case "active+recovery_wait":
								return "#959595";
							case "active+recovering":
								return "#aaaaaa";
							case "stale+active+clean":
								return "#106e09";
							case "stale+active+degraded":
								return "#c3bb00";
							case "active+degraded":
								return "#e2d900";
							case "active+clean+replay":
								return "#fff500";
							case "peering":
								return "#ba1f69";
							case "remapped+peering":
								return "#ba1f69";
							case "active+recovering+remapped":
								return "#aaaaaa";
							case "active+remapped":
								return "#00ac08";
							case "active+recovery_wait+remapped":
								return "#959595";
							case "creating":
								return "#80d2dc";
							default:
								console.log(d.state);return "#000000";
						}
					default:
						return color((d.children ? d : d.parent).name);
				}
			}).on("click", click);
			var text = g.append("text").attr("transform", function (d) {
				switch (d.depth) {
					case 0:
						return "rotate(0)";
					default:
						return "rotate(" + computeTextRotation(d) + ")";
				}
			}).attr("text-anchor", function (d) {
				return d.depth == 0 ? "middle" : "start";
			}).attr("x", function (d) {
				return y(d.y);
			}).attr("dx", "6") // margin
			.attr("dy", ".35em") // vertical-align
			.text(function (d) {
				switch (d.depth) {
					case 0:
						return "v" + d.version;
					case 1:
						return d.pool_name;
					default:
						return "";
				}
			});
			var tooltips = g.append("svg:title").text(function (d) {
				switch (d.depth) {
					case 0:
						return "";
					case 1:
						return "";
					default:
						return d.objects + ":" + d.state;
				}
			});
			function click(d) {
				// fade out all text elements
				text.transition().attr("opacity", 0);
				path.transition().duration(750).attrTween("d", arcTween(d)).each("end", function (e, i) {
					// check if the animated element's data e lies within the visible angle span given in d
					if (e.x >= d.x && e.x < d.x + d.dx) {
						// get a selection of the associated text element
						var arcText = d3.select(this.parentNode).select("text");
						// fade in the text element and recalculate positions
						arcText.transition().duration(300).attr("opacity", 1).attr("transform", function (d) {
							switch (d.depth) {
								case 0:
									return "rotate(0)";
								default:
									return "rotate(" + computeTextRotation(d) + ")";
							}
						}).attr("x", function (d) {
							return y(d.y);
						});
					}
				});
			}
		});
		d3.select(self.frameElement).style("height", height + "px");
		// Interpolate the scales!
		function arcTween(d) {
			var xd = d3.interpolate(x.domain(), [d.x, d.x + d.dx]),
			    yd = d3.interpolate(y.domain(), [d.y, 1]),
			    yr = d3.interpolate(y.range(), [d.y ? 20 : 0, radius]);
			return function (d, i) {
				return i ? function (t) {
					return arc(d);
				} : function (t) {
					x.domain(xd(t));y.domain(yd(t)).range(yr(t));return arc(d);
				};
			};
		}
		function computeTextRotation(d) {
			return (x(d.x + d.dx / 2) - Math.PI / 2) / Math.PI * 180;
		}
	};
});


'use strict';

angular.module('coach').controller('CephPagesController', function ($scope, storage) {
	$scope.$on('widget-update', function ($event, id, data) {
		if (id !== $scope.widget.id) {
			return;
		}
		var width = $("#" + id).parent().width(),
		    height = $("#" + id).parent().width(),
		    radius = Math.min(width, height) / 2 - 1;
		var x = d3.scale.linear().range([0, 2 * Math.PI]);
		var y = d3.scale.linear().range([0, radius]);
		var color = d3.scale.category20c();
		var svg = d3.select("[id='" + id + "']").attr("width", width).attr("height", height + 20).append("g").attr("transform", "translate(" + width / 2 + "," + (height / 2 + 10) + ")");
		var partition = d3.layout.partition().value(function (d) {
			return 1;
		});
		var arc = d3.svg.arc().startAngle(function (d) {
			return Math.max(0, Math.min(2 * Math.PI, x(d.x)));
		}).endAngle(function (d) {
			return Math.max(0, Math.min(2 * Math.PI, x(d.x + d.dx)));
		}).innerRadius(function (d) {
			return Math.max(0, y(d.y));
		}).outerRadius(function (d) {
			return Math.max(0, y(d.y + d.dy));
		});
		d3.json("/api/coach/storage/ceph/pg/tree", function (error, root) {
			var g = svg.selectAll("g").data(partition.nodes(root)).enter().append("g");
			var path = g.append("path").attr("d", arc).attr("width", 0).style("fill", function (d) {
				switch (d.depth) {
					case 0:
						return "#5E6A71";
					case 1:
						return color((d.children ? d : d.parent).name);
					case 2:
						switch (d.state) {
							case "active+clean":
								return "#00de00";
							case "active+recovery_wait":
								return "#959595";
							case "active+recovering":
								return "#aaaaaa";
							case "stale+active+clean":
								return "#106e09";
							case "stale+active+degraded":
								return "#c3bb00";
							case "active+degraded":
								return "#e2d900";
							case "active+clean+replay":
								return "#fff500";
							case "peering":
								return "#ba1f69";
							case "remapped+peering":
								return "#ba1f69";
							case "active+recovering+remapped":
								return "#aaaaaa";
							case "active+remapped":
								return "#00ac08";
							case "active+recovery_wait+remapped":
								return "#959595";
							case "creating":
								return "#80d2dc";
							default:
								return "#000000";
						}
					default:
						return color((d.children ? d : d.parent).name);
				}
			}).on("click", click);
			var text = g.append("text").attr("transform", function (d) {
				switch (d.depth) {
					case 0:
						return "rotate(0)";
					default:
						return "rotate(" + computeTextRotation(d) + ")";
				}
			}).attr("text-anchor", function (d) {
				return d.depth == 0 ? "middle" : "start";
			}).attr("x", function (d) {
				return y(d.y);
			}).attr("dx", "6") // margin
			.attr("dy", ".35em") // vertical-align
			.text(function (d) {
				switch (d.depth) {
					case 0:
						return "v" + d.version;
					case 1:
						return d.pool_name;
					default:
						return "";
				}
			});
			var tooltips = g.append("svg:title").text(function (d) {
				switch (d.depth) {
					case 0:
						return "";
					case 1:
						return "";
					default:
						return d.objects + ":" + d.state;
				}
			});
			function click(d) {
				// fade out all text elements
				text.transition().attr("opacity", 0);
				path.transition().duration(750).attrTween("d", arcTween(d)).each("end", function (e, i) {
					// check if the animated element's data e lies within the visible angle span given in d
					if (e.x >= d.x && e.x < d.x + d.dx) {
						// get a selection of the associated text element
						var arcText = d3.select(this.parentNode).select("text");
						// fade in the text element and recalculate positions
						arcText.transition().duration(300).attr("opacity", 1).attr("transform", function (d) {
							switch (d.depth) {
								case 0:
									return "rotate(0)";
								default:
									return "rotate(" + computeTextRotation(d) + ")";
							}
						}).attr("x", function (d) {
							return y(d.y);
						});
					}
				});
			}
			if ($("#" + id).children().length > 1) {
				$("#" + id).children().first().remove();
			}
		});
		d3.select(self.frameElement).style("height", height + "px");
		// Interpolate the scales!
		function arcTween(d) {
			var xd = d3.interpolate(x.domain(), [d.x, d.x + d.dx]),
			    yd = d3.interpolate(y.domain(), [d.y, 1]),
			    yr = d3.interpolate(y.range(), [d.y ? 20 : 0, radius]);
			return function (d, i) {
				return i ? function (t) {
					return arc(d);
				} : function (t) {
					x.domain(xd(t));y.domain(yd(t)).range(yr(t));return arc(d);
				};
			};
		}
		function computeTextRotation(d) {
			return (x(d.x + d.dx / 2) - Math.PI / 2) / Math.PI * 180;
		}
	});
});

angular.module('coach').controller('CephPagesConfigController', function ($scope) {
	$scope.configuredWidget.config.name = "ceph";
});


'use strict';

angular.module('coach').service('bootstrap', function ($http, $q, tasks) {

	this.start = function (config) {
		return $http.post("/api/coach/bootstrap", config).then(function (response) {
			return response.data;
		});
	};
	this.isCephInstalled = function () {
		return $http.get("/api/coach/isCephInstalled").then(function (response) {
			return response.data;
		});
	};
	this.isCephFS = function () {
		return $http.get("/api/coach/isCephFS").then(function (response) {
			return response.data;
		});
	};
	this.installCephFS = function (config) {
		return $http.post("/api/coach/storage/ceph/fs/add", config).then(function (response) {
			return response.data;
		});
	};
	this.mountCephFS = function (config) {
		return $http.get("/api/coach/storage/ceph/fs/mount").then(function (response) {
			return response.data;
		});
	};

	this.installNetworkServices = function () {
		return $http.get("/api/coach/installNetworkServices").then(function (response) {
			return response.data;
		});
	};

	return this;
});


'use strict';

angular.module('coach').service('fabric', function ($http, $q, tasks) {
				this.getLinks = function () {
								return $http.get("/api/coach/fabric/get/links").then(function (response) {
												return response.data;
								});
				};
				this.getFQDN = function () {
								return $http.get("/api/coach/fabric/get/fqdn").then(function (response) {
												return response.data;
								});
				};

				this.dhcpSearch = function (iface) {
								return $http.get("/api/coach/fabric/dhcp_search/" + iface).then(function (response) {
												return response.data;
								});
				};

				this.connectToFabric = function (iface, fabric) {
								return $http.get("/api/coach/fabric/connect/" + iface + "/" + fabric).then(function (response) {
												return response.data;
								});
				};

				return this;
});


'use strict';

angular.module('coach').service('storage', function ($http, $q, tasks) {

	this.getBlockDevices = function () {
		return $http.get("/api/coach/storage/local/list/block_devices").then(function (response) {
			return response.data;
		});
	};
	this.getDriveBays = function () {
		return $http.get("/api/coach/storage/local/list/bays").then(function (response) {
			return response.data;
		});
	};

	this.getCephMonStat = function () {
		return $http.get("/api/coach/storage/ceph/mon/status").then(function (response) {
			return response.data;
		});
	};
	this.getCephOsdDetails = function (config) {
		return $http.post("/api/coach/storage/ceph/osd/details", config).then(function (response) {
			return response.data;
		});
	};
	this.getCephOsdTree = function (config) {
		return $http.get("/api/coach/storage/ceph/osd/tree", config).then(function (response) {
			return response.data;
		});
	};
	this.cephAddOsd = function (config) {
		return $http.post("/api/coach/storage/ceph/osd/add", config).then(function (response) {
			return response.data;
		});
	};
	this.cephRemoveOsd = function (config) {
		return $http.post("/api/coach/storage/ceph/osd/remove", config).then(function (response) {
			return response.data;
		});
	};
	this.getCephPgTree = function () {
		return $http.get("/api/coach/storage/ceph/pg/tree").then(function (response) {
			return response.data;
		});
	};
	this.getCephPgMap = function () {
		return $http.get("/api/coach/storage/ceph/pg/map").then(function (response) {
			return response.data;
		});
	};
	this.getCephIops = function () {
		return $http.get("/api/coach/storage/ceph/iops").then(function (response) {
			return response.data;
		});
	};

	this.megaraidExists = function () {
		return $http.get("/api/coach/storage/local/megaraid/exists").then(function (response) {
			return response.data;
		});
	};
	this.megaraidBuild = function () {
		return $http.get("/api/coach/storage/local/megaraid/build").then(function (response) {
			return response.data;
		});
	};

	return this;
});


