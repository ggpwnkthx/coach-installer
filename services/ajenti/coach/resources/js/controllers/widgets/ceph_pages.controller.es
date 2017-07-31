angular.module('coach').controller('CephPagesController', ($scope, storage)  => {
	$scope.$on('widget-update', ($event, id, data) => {
        if (id !== $scope.widget.id) {
            return;
        }
		var width = $("#"+id).parent().width(),
			height = $("#"+id).parent().width(),
			radius = Math.min(width, height) / 2 - 1;
		var x = d3.scale.linear()
			.range([0, 2 * Math.PI]);
		var y = d3.scale.linear()
			.range([0, radius]);
		var color = d3.scale.category20c();
		var svg = d3.select("[id='" + id + "']")
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
						default: return "#000000";
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
		  if ($("#"+id).children().length > 1) {
			$("#"+id).children().first().remove()
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
	});
});

angular.module('coach').controller('CephPagesConfigController', ($scope) => {
	$scope.configuredWidget.config.name = "ceph"
});