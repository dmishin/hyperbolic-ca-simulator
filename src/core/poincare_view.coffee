M = require "./matrix3.coffee"
{unity} = require "./vondyck_chain.coffee"
{NodeHashMap} = require "./chain_map.coffee"

len2 = (x,y) -> x*x + y*y

#determine cordinates of the cell, containing given point
exports.makeXYT2path = (tiling, maxSteps=100) -> 
  cell2point = (cell) -> M.mulv tiling.repr(cell), [0.0,0.0,1.0]
  vectorDist = ([x1,y1,t1], [x2,y2,t2]) ->
    #actually, this is the correct way:
    # Math.acosh t1*t2 - x1*x2 - y1*y2
    #however, acosh is costy, and we need only comparisions...
    t1*t2 - x1*x2 - y1*y2 - 1

  nearestNeighbor = (cell, xyt) ->
    dBest = null
    neiBest = null
    for nei in tiling.moore cell
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
exports.visibleNeighborhood = (tiling, minCellSize) ->
  #Visible size of the polygon far away
  cells = new NodeHashMap
  walk = (cell) ->
    return if cells.get(cell) isnt null
    cellSize = visiblePolygonSize tiling, tiling.repr cell
    cells.put cell, cellSize
    if cellSize > minCellSize
      for nei in tiling.moore cell
        walk nei
    return
  walk unity
  visibleCells = []
  cells.forItems (cell, size)->
    if size >= minCellSize
      visibleCells.push cell
  return visibleCells

exports.makeCellShapePoincare = (tiling, cellTransformMatrix, context) ->
  pPrev = null
  for vertex, i in tiling.cellShape
    [x0, y0, t0] = pPrev ? M.mulv(cellTransformMatrix, vertex)
    [x1, y1, t1] = pPrev = M.mulv(cellTransformMatrix, tiling.cellShape[(i+1) % tiling.cellShape.length])

    #poincare coordinates
    inv_t0 = 1.0/(t0+1)
    xx0 = x0*inv_t0
    yy0 = y0*inv_t0

    inv_t1 = 1.0/(t1+1)
    xx1 = x1*inv_t1
    yy1 = y1*inv_t1
    
    if i is 0
      context.moveTo xx0, yy0
    drawPoincareCircleTo context, xx0, yy0, xx1, yy1
  #context.closePath()
  return
  
exports.drawPoincareCircleTo = drawPoincareCircleTo = (context, x0, y0, x1, y1) ->
  #Calculate radius of the circular arc.

  sq_l0 = len2( x0, y0 )
  # (x0^2+y0^2)*inv_t0^2 = (t0^2-1)/(t0+1)^2 = (t0-1)/(t0+1) = 1-2/(t0+1)
  sq_l1 = len2( x1, y1 ) # = 1-2/(t1+1)
  
  k0 = (1+1/sq_l0) * 0.5 # = (1+(t0+1)/(t0-1)) * 0.5 = t0/(t0-1)
  k1 = (1+1/sq_l1) * 0.5 # = t1/(t1-1)
  
  delta2 = len2( x0*k0 - x1*k1, y0*k0 - y1*k1 )
  #x0*k0 = x0/(t0+1)*t0/(t0-1) = (x0t0)/(t0^2-1)

  #k_ is not needed anymore

  if delta2 < 1e-4 # 0.01^2 lenght of a path too small, create straight line instead to make it faster.
    context.lineTo( x1, y1 ) 
    return
  
  cross = (x0*y1 - x1*y0)
  r2 = ( sq_l0 * sq_l1 * delta2 ) / (cross*cross) - 1  
  
  r = - Math.sqrt( r2 )
  if cross < 0
    r = -r
  
  if Math.abs(r) < 100
    drawBezierApproxArcTo context, x0, y0, x1, y1, r, r<0 
  else
    context.lineTo x1, y1
    
exports.drawBezierApproxArcTo = drawBezierApproxArcTo = (context, x0, y0, x1, y1, r, reverse) ->
    d2 = len2(x0-x1, y0-y1)
    d  = Math.sqrt( d2 )
    
    ct = Math.sqrt(r*r - d2*0.25)
    if reverse
      ct = -ct

    #Main formulas for calculating bezier points. Math was used to get them.
    r_ct = r-ct
    kx = (4.0/3.0)*r_ct/d
    ky = -(8.0/3.0)*r*r_ct/d2 + 1.0/6.0

    #Get the bezier control point positions
    #vx is a perpendicular vector, vy is parallel
    vy_x = x1-x0
    vy_y = y1-y0
    vx_x = vy_y
    vx_y = -vy_x # #rotated by Pi/2

    xc = (x0+x1)*0.5
    yc = (y0+y1)*0.5
    
    p11x = xc + vx_x * kx + vy_x * ky
    p11y = yc + vx_y * kx + vy_y * ky
    
    #p12x = xc + vx_x * kx - vy_x * ky
    #p12y = yc + vx_y * kx - vy_y * ky
    p12x = xc +  vy_y * kx - vy_x * ky
    p12y = yc + -vy_x * kx - vy_y * ky
  
    context.bezierCurveTo p11x, p11y, p12x, p12y, x1, y1


exports.hyperbolic2poincare = ([x,y,t], dist) ->
  #poincare coordinates
  # t**2 - x**2 - y**2 = 1
  #
  # if scaled, 
  #  s = sqrt(t**2 - x**2 - y**2)
  #
  # xx = x/s, yy=y/s, tt=t/s, tt+1 = (t+s)/s
  #
  # xxx = xx/(tt+1) = x/s/(t+s)*s = x/(t+s)
  # yyy = y/(t+s)
  r2 = x**2+y**2
  s2 = t**2-r2
  if s2 <=0
    its = 1.0/Math.sqrt(r2)
  else
    its = 1.0/(t+Math.sqrt(s2))

  if dist
    # Length of a vector, might be denormalized
    # s2 = t**2 - x**2 - y**2
    # s = sqrt(s2)
    # 
    # xx = x/s
    # yy = y/s
    # tt = t/s
    #
    # d = acosh tt = acosh t/sqrt(t**2 - x**2 - y**2)
    #  = log( t/sqrt(t**2 - x**2 - y**2) + sqrt(t**2/(t**2 - x**2 - y**2) - 1) ) =
    #  = log( (t + sqrt(x**2 + y**2)) / sqrt(t**2 - x**2 - y**2) ) =
    # 
    #  = log(t + sqrt(x**2 + y**2)) - 0.5*log(t**2 - x**2 - y**2)
    d = if s2 <= 0
      Infinity
    else
      Math.acosh(t/Math.sqrt(s2))
    [x*its, y*its, d]
  else
    [x*its, y*its]

exports.visiblePolygonSize = visiblePolygonSize = (tiling, cellTransformMatrix) ->
  xmin = xmax = ymin = ymax = 0.0
  
  for vertex, i in tiling.cellShape
    [x, y, t] = M.mulv cellTransformMatrix, vertex
    xx = x/t
    yy = y/t
    if i is 0
      xmin = xmax = xx
      ymin = ymax = yy
    else
      xmin = Math.min xmin, xx
      xmax = Math.max xmax, xx

      ymin = Math.min ymin, yy
      ymax = Math.max ymax, yy
      
  return Math.max( xmax - xmin, ymax - ymin )
                
