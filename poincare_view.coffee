{mooreNeighborhood} = require "./field.coffee"
M = require "./matrix3.coffee"
{unity, nodeMatrixRepr, node2array, NodeHashMap} = require "./vondyck_chain.coffee"


#determine cordinates of the cell, containing given point
exports.makeXYT2path = (group, appendRewrite, maxSteps=100) -> 
  getNeighbors = mooreNeighborhood group.n, group.m, appendRewrite
  cell2point = (cell) -> M.mulv nodeMatrixRepr(cell, group), [0.0,0.0,1.0]
  vectorDist = ([x1,y1,t1], [x2,y2,t2]) ->
    #actually, this is the correct way:
    # Math.acosh t1*t2 - x1*x2 - y1*y2
    #however, acosh is costy, and we need only comparisions...
    t1*t2 - x1*x2 - y1*y2 - 1

  nearestNeighbor = (cell, xyt) ->
    dBest = null
    neiBest = null
    for nei in getNeighbors cell
      dNei = vectorDist cell2point(nei), xyt
      if (dBest is null) or (dNei < dBest)
        dBest = dNei
        neiBest = nei
    return [neiBest, dBest]
    
  return (xyt) ->
    #FInally, search    
    cell = unity #start search at origin
    cellDist = vectorDist cell2point(cell), xyt
    #Just in case, avoid infinite iteration
    step = 0
    while step < maxSteps
      step += 1
      [nextNei, nextNeiDist] = nearestNeighbor cell, xyt
      if nextNeiDist > cellDist
        break
      else
        cell = nextNei
        cellDist = nextNeiDist
    return cell

#Convert poincare circle coordinates to hyperbolic (x,y,t) representation
exports.poincare2hyperblic = (x,y) ->
  # direct conversion:
  # x = xh / (th + 1)
  # y = yh / (th + 1)
  #
  #   when th^2 - xh^2 - yh^2 == 1
  #
  # r2 = x^2 + y^2 = (xh^2+yh^2)/(th+1)^2 = (th^2-1)/(th+1)^2 = (th-1)/(th+1)
  #
  # r2 th + r2 = th - 1
  # th (r2-1) = -1-r2
  # th = (r2+1)/(1-r2)
  r2 = x*x+y*y
  if r2 >= 1.0
    return null
    
  th = (r2+1)/(1-r2)
  # th + 1 = (r2+1)/(1-r2)+1 = (r2+1+1-r2)/(1-r2) = 2/(1-r2)
  return [x * (th+1), y*(th+1), th ]


    
# Create list of cells, that in Poincare projection are big enough.
exports.visibleNeighborhood = (tessellation, appendRewrite, minCellSize) ->
  #Visible size of the polygon far away
  getNeighbors = mooreNeighborhood tessellation.group.n, tessellation.group.m, appendRewrite
  cells = new NodeHashMap
  walk = (cell) ->
    return if cells.get(cell) isnt null
    cellSize = tessellation.visiblePolygonSize nodeMatrixRepr(cell, tessellation.group)
    cells.put cell, cellSize
    if cellSize > minCellSize
      for nei in getNeighbors cell
        walk nei
    return
  walk unity
  visibleCells = []
  cells.forItems (cell, size)->
    if size >= minCellSize
      visibleCells.push cell
  return visibleCells

