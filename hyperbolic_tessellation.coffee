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
    context.beginPath()
    for vertex, i in @cellShape
      [x0, y0, t0] = M.mulv(cellTransformMatrix, vertex)
      [x1, y1, t1] = M.mulv(cellTransformMatrix, @cellShape[(i+1) % @cellShape.length])

      #poincare coordinates
      xx0 = x0/(t0+1)
      yy0 = y0/(t0+1)

      xx1 = x1/(t1+1)
      yy1 = y1/(t1+1)


      #circular arc center
      #xc = (x1*t0-x0*t1)/(x0*y1-x1*y0)
      #yc = (y1*y0-y0*t1)/(x0*y1-x1*y0)
      xc = (y1*t0-y0*t1)/(x0*y1-x1*y0)
      yc = -(x1*t0-x0*t1)/(x0*y1-x1*y0)

      r0 = (xx0-xc)**2 + (yy0-yc)**2
      r1 = (xx1-xc)**2 + (yy1-yc)**2

      #if Math.abs(r0-r1) > 1e-2
      #  throw new Error "Bad center!"

      if i is 0
        context.moveTo xx0, yy0

      #@_drawCircularArc context, xx0, yy0, xx1, yy1, xc, yc
      #context.lineTo xx1, yy1
      @drawPoincareCircleTo context, xx0, yy0, xx1, yy1
      
      #else
      #  context.lineTo xx, yy
    context.closePath()
    
  drawPoincareCircleTo: (context, x0, y0, x1, y1) ->
    #Calculate radius of the circular arc.
    sq_l0 = len2( x0, y0 )
    sq_l1 = len2( x1, y1 )
    
    k0 = (1+1/sq_l0) * 0.5
    k1 = (1+1/sq_l1) * 0.5
    
    delta2 = len2( x0*k0 - x1*k1, y0*k0 - y1*k1 )
  
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
      d2 = (x0-x1)**2 +(y0-y1)**2
      d  = Math.sqrt( d2 )
      
      ct = Math.sqrt( 4*r*r - d2)*0.5
      if reverse
        ct = -ct
  
      #Main formulas for calculating bezier points. Math was used to get them.
      kx = 4.0/3.0*(r-ct)/d
      ky = 8.0/3.0*r*(ct - r)/d2 + 1.0/6.0
  
      #Get the bezier control point positions
      #vx is a perpendicular vector, vy is parallel
      vy_x = x1-x0
      vy_y = y1-y0
      vx_x = vy_y
      vx_y = -vy_x # #rotated by Pi/2
      
      p11x = (x0+x1)*0.5 + vx_x * kx + vy_x * ky
      p11y = (y0+y1)*0.5 + vx_y * kx + vy_y * ky
      
      p12x = (x0+x1)*0.5 + vx_x * kx - vy_x * ky
      p12y = (y0+y1)*0.5 + vx_y * kx - vy_y * ky
    
      context.bezierCurveTo p11x, p11y, p12x, p12y, x1, y1
                  
  makeCellShape: (cellTransformMatrix, context) ->
    #each cell is n-gon.
    
    context.beginPath()
    for vertex, i in @cellShape
      [x, y, t] = M.mulv(cellTransformMatrix, vertex)
      xx = x/t
      yy = y/t

      if i is 0
        context.moveTo xx, yy
      else
        context.lineTo xx, yy
    context.closePath()
    
