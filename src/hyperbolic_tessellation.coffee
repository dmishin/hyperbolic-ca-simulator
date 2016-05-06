{CenteredVonDyck} = require "./triangle_group_representation.coffee"
M = require "./matrix3.coffee"

len2 = (x,y) -> x*x + y*y

exports.Tessellation = class Tessellation
  constructor: (n,m) ->
    @group = new CenteredVonDyck n, m
    @cellShape = @_generateNGon n, @group.sinh_r, @group.cosh_r


  #produces shape (array of 3-vectors)
  _generateNGon: (n, sinh_r, cosh_r) ->
    alpha = Math.PI*2/n
    for i in [0...n]
      angle = alpha*i
      [sinh_r*Math.cos(angle), sinh_r*Math.sin(angle), cosh_r]

  
  makeCellShapePoincare: (cellTransformMatrix, context) ->
    pPrev = null
    for vertex, i in @cellShape
      [x0, y0, t0] = pPrev ? M.mulv(cellTransformMatrix, vertex)
      [x1, y1, t1] = pPrev = M.mulv(cellTransformMatrix, @cellShape[(i+1) % @cellShape.length])

      #poincare coordinates
      inv_t0 = 1.0/(t0+1)
      xx0 = x0*inv_t0
      yy0 = y0*inv_t0

      inv_t1 = 1.0/(t1+1)
      xx1 = x1*inv_t1
      yy1 = y1*inv_t1
      
      if i is 0
        context.moveTo xx0, yy0
      @drawPoincareCircleTo context, xx0, yy0, xx1, yy1
    #context.closePath()
    return
    
  drawPoincareCircleTo: (context, x0, y0, x1, y1) ->
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
      @drawBezierApproxArcTo( context, x0, y0, x1, y1, r, r<0 )
    else
      context.lineTo x1, y1
      
  drawBezierApproxArcTo: (context, x0, y0, x1, y1, r, reverse) ->
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
                  
  visiblePolygonSize: (cellTransformMatrix) ->
    xmin = xmax = ymin = ymax = 0.0
    
    for vertex, i in @cellShape
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
                
