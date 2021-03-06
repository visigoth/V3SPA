    vespaControllers = angular.module('vespaControllers')

    vespaControllers.controller 'module_browserCtrl', ($scope, VespaLogger,
        IDEBackend, $timeout, $modal, PositionManager, $q, SockJSService) ->

      barHeight = 20
      barWidth = 300
      duration = 400
      root = {}
      svg = d3.select("svg.module_browserview").select("g.viewer")
      tree = d3.layout.tree()
        .nodeSize([0, 20])

      $scope.controls =
        showModuleSelect: true
        collapse: 'collapse-all'

      collapseAll = (node) ->
        if node.children
          node._children = node.children
          node.children = null
          node._children.forEach collapseAll
        if Array.isArray node._children
          node._children.forEach collapseAll

      openAll = (node) ->
        if node._children
          node.children = node._children
          node._children = null
          node.children.forEach openAll
        if Array.isArray node.children
          node.children.forEach openAll

      $scope.collapse = (value) ->
        if value == 'collapse-all'
          collapseAll(root)
        else if value == 'open-all'
          openAll(root)
        if value and root.name
          update(root)

      $scope.update_view = () ->
        $scope.policy = IDEBackend.current_policy

        if not $scope.policy?.modules?
          return

        modules_root = 
          name: (if $scope.policy?.id? then $scope.policy.id else "")
          children: []

        # Group the rules by directory and module
        for key, mod of $scope.policy.modules
          if not mod.te_file
            return
          
          path = mod.te_file.split('/')
          modDirectory = path[path.length - 2]
          directory = _.find(modules_root.children, {directory: modDirectory})
          if directory
            module = _.find(directory.children, {module: mod.name})
            if module
              #module.children.push d
            else
              directory.children.push {name: mod.name, module: mod.name}
          else
            child = {name: mod.name, module: mod.name}
            modules_root.children.push {name: modDirectory, directory: modDirectory, children: [child]}

        modules_root.x0 = 0
        modules_root.y0 = 0

        update(root = modules_root)

      update = (modules_root) ->
        nodes = tree.nodes(root)
        _.each nodes, (d,i) ->
          d.x = i * barHeight

        height = 500

        d3.select("svg.module_browserview").transition()
          .duration(duration)
          .attr("height", height)

        node = svg.selectAll("g.node")
          .data(nodes, (d,i) -> return d.id or (d.id = $scope.policy.id + "-" + i))

        nodeEnter = node.enter().append("g")
          .attr("class", "node")
          .attr("transform", (d) -> return "translate(#{modules_root.y0},#{modules_root.x0})")
          .style("opacity", 1e-6)

        nodeEnter.append("rect")
          .attr("y", -barHeight/2)
          .attr("height", barHeight)
          .attr("width", barWidth)
          .style("fill", color)
          .on("click", click)

        nodeEnter.append("text")
          .attr("dy", 3.5)
          .attr("dx", 5.5)
          .style("fill", '#333')
          .text((d) -> if d.children? then "#{d.name} (#{d.children.length})" else if d._children? then "#{d.name} (#{d._children.length})" else d.name)

        nodeEnter.transition()
          .duration(duration)
          .attr("transform", (d) -> "translate(#{d.y},#{d.x})")
          .style("opacity", 1)

        node.transition()
          .duration(duration)
          .attr("transform", (d) -> "translate(#{d.y},#{d.x})")
          .style("opacity", 1)
          .select("rect")
          .style("fill", color)

        node.exit().transition()
          .duration(duration)
          .attr("transform", (d) -> "translate(#{modules_root.y},#{modules_root.x})")
          .style("opacity", 1e-6)
          .remove()

        _.each nodes, (d) ->
          d.x0 = d.x
          d.y0 = d.y

      click = (d) ->
        if d.children
          d._children = d.children
          d.children = null
        else
          d.children = d._children
          d._children = null
        update(d)

      color = (d) ->
        if d._children
          return '#3182bd'
        else if d.children
          return '#c6dbef'
        else
          return '#fd8d3c'

Set up the viewport scroll

      positionMgr = PositionManager("tl.viewport::#{IDEBackend.current_policy._id}",
        {a: 0.7454701662063599, b: 0, c: 0, d: 0.7454701662063599, e: 200, f: 50}
      )

      svgPanZoom.init
        selector: '#surface svg'
        panEnabled: true
        zoomEnabled: true
        dragEnabled: false
        minZoom: 0.5
        maxZoom: 10
        onZoom: (scale, transform) ->
          positionMgr.update transform
        onPanComplete: (coords, transform) ->
          positionMgr.update transform

      $scope.$watch(
        () -> return (positionMgr.data)
        , 
        (newv, oldv) ->
          if not newv? or _.keys(newv).length == 0
            return
          g = svgPanZoom.getSVGViewport($("#surface svg")[0])
          svgPanZoom.set_transform(g, newv)
      )

      IDEBackend.add_hook "policy_load", $scope.update_view
      $scope.$on "$destroy", ->
        IDEBackend.unhook "policy_load", $scope.update_view

      $scope.policy = IDEBackend.current_policy

      # If policy already loaded, render it
      if $scope.policy?._id
        $scope.update_view()