angular.module('coach').controller('CoachStorageController', function ($scope, notify, pageTitle, storage) {
	pageTitle.set('Storage');

	$scope.reload = () => {
		$scope.addOSD = null;
		$scope.blockDevices = null;
		$scope.cephOSDs = [];
		
		storage.megaraidExists().then((data) => {
			$scope.megaraidExists = data;
		});
		
		storage.getDriveBays().then((bays) => {
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
									storage.getCephOsdDetails(config).then((details) => {
										if (data == "Root permission required") {
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
        });
		if ($("#osd").length) {
			storage.getCephMonStat().then((monitors) => {
				if (data == "Root permission required") {
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
			
			storage.getCephOsdTree().then((osd_tree) => {
				if (data == "Root permission required") {
					return
				}
				$scope.cephOSDs = osd_tree;
			});
		}
    };
	
	$scope.reload();
	
	$scope.MegaRAID_build = () => {
		storage.megaraidBuild().then((data) => {
			$scope.reload();
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
		storage.cephAddOsd(config).then((data) => {
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
		storage.cephRemoveOsd(config).then((data) => {
			notify.info(data);
			$scope.cephRemoveOsdProcessing = false;
			$scope.removeOSD = null;
			$scope.reload();
		});
	}
	
	$scope.cephOsdTree = () => {
		id = "osd"
		$("#"+id).html("");
		var margin = {top: 0, right: 0, bottom: 0, left: 100},
			width = $("#"+id).parent().parent().parent().first().width() - margin.right - margin.left,
			height = $("#"+id).parent().parent().parent().parent().parent().parent().parent().height() - $("#"+id).parent().parent().parent().first().height() - $("#"+id).parent().parent().parent().parent().parent().parent().first().height() - margin.top - margin.bottom;
		var color = d3.scale.category20c();
			
		var i = 0,
			duration = 750,
			root;
		var tree = d3.layout.tree()
			.size([height, width]);
		var diagonal = d3.svg.diagonal()
			.projection(function(d) { return [d.y, d.x]; });
		var svg = d3.select("#osd").append("svg")
			.attr("width", width + margin.right + margin.left)
			.attr("height", height + margin.top + margin.bottom)
			.append("g")
			.attr("transform", "translate(" + margin.left + "," + margin.top + ")");
		d3.json("/api/coach/storage/ceph/osd/tree", function(error, flare) {
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
	$scope.cephPgStat = () => {
		id = "pgs"
		$("#"+id).html("");
		width = $("#"+id).parent().parent().parent().first().width(),
			height = $("#"+id).parent().parent().parent().parent().parent().parent().parent().height() - $("#"+id).parent().parent().parent().first().height() - $("#"+id).parent().parent().parent().parent().parent().parent().first().height(),
			radius = Math.min(width, height) / 2 - 1;
		var x = d3.scale.linear()
			.range([0, 2 * Math.PI]);
		var y = d3.scale.linear()
			.range([0, radius]);
		var color = d3.scale.category20c();
		var svg = d3.select("#pgs").append("svg")
			.attr("width", width)
			.attr("height", height+20)
		  .append("g")
			.attr("transform", "translate(" + width / 2 + "," + (height / 2 + 10) + ")");
		var partition = d3.layout.partition()
			.value(function(d) { return 1; });
		var arc = d3.svg.arc()
			.startAngle(function(d) { return Math.max(0, Math.min(2 * Math.PI, x(d.x))); })
			.endAngle(function(d) { return Math.max(0, Math.min(2 * Math.PI, x(d.x + d.dx))); })
			.innerRadius(function(d) { return Math.max(0, y(d.y)); })
			.outerRadius(function(d) { return Math.max(0, y(d.y + d.dy)); });
		d3.json("/api/coach/storage/ceph/pg/tree", function(error, root) {
		  var g = svg.selectAll("g")
			  .data(partition.nodes(root))
			.enter().append("g");
		  var path = g.append("path")
			.attr("d", arc)
			.attr("width", 0)
			.style("fill", function(d) {
			switch (d.depth) {
				case 0:
						return "#5E6A71";
				case 1:
						return color((d.children ? d : d.parent).name);
				case 2:
					switch (d.state) {
						case "active+clean": return "#00de00";
						case "active+recovery_wait": return "#959595";
						case "active+recovering": return "#aaaaaa";
						case "stale+active+clean": return "#106e09";
						case "stale+active+degraded": return "#c3bb00";
						case "active+degraded": return "#e2d900";
						case "active+clean+replay": return "#fff500";
						case "peering": return "#ba1f69";
						case "remapped+peering": return "#ba1f69";
						case "active+recovering+remapped": return "#aaaaaa";
						case "active+remapped": return "#00ac08";
						case "active+recovery_wait+remapped": return "#959595";
						case "creating": return "#80d2dc";
						default: console.log(d.state); return "#000000";
					}
				default:
						return color((d.children ? d : d.parent).name);
			}
			})
			.on("click", click);
		  var text = g.append("text")
			.attr("transform", function(d) {
			switch (d.depth) {
				case 0:
						return "rotate(0)";
				default:
					return "rotate(" + computeTextRotation(d) + ")";
			}
			})
			.attr("text-anchor", function(d) { return (d.depth == 0 ? "middle" : "start"); })
			.attr("x", function(d) { return y(d.y); })
			.attr("dx", "6") // margin
			.attr("dy", ".35em") // vertical-align
			.text(function(d) {
			switch (d.depth) {
				case 0:
						return "v"+d.version;
				case 1:
						return d.pool_name;
				default:
						return "";
			}
			});
		  var tooltips = g.append("svg:title").text(function(d) {
			switch (d.depth) {
				case 0:
						return "";
				case 1:
						return "";
				default:
					return d.objects+":"+d.state;
			}
			});
		  function click(d) {
			// fade out all text elements
			text.transition().attr("opacity", 0);
			path.transition()
			  .duration(750)
			  .attrTween("d", arcTween(d))
			  .each("end", function(e, i) {
				  // check if the animated element's data e lies within the visible angle span given in d
				  if (e.x >= d.x && e.x < (d.x + d.dx)) {
					// get a selection of the associated text element
					var arcText = d3.select(this.parentNode).select("text");
					// fade in the text element and recalculate positions
					arcText.transition().duration(300)
					  .attr("opacity", 1)
					  .attr("transform", function(d) {
						  switch (d.depth) {
							case 0:
							  return "rotate(0)";
							default:
							  return "rotate(" + computeTextRotation(d) + ")";
						  }
					  })
					  .attr("x", function(d) { return y(d.y); });
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
		  return function(d, i) {
			return i
				? function(t) { return arc(d); }
				: function(t) { x.domain(xd(t)); y.domain(yd(t)).range(yr(t)); return arc(d); };
		  };
		}
		function computeTextRotation(d) {
		  return (x(d.x + d.dx / 2) - Math.PI / 2) / Math.PI * 180;
		}
	}
	
});
