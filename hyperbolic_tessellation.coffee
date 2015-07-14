{CenteredVonDyck} = require "./triangle_group_representation.coffee"
M = require "./matrix3.coffee"

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
      context.lineTo xx1, yy1
      #else
      #  context.lineTo xx, yy
    context.closePath()
    
  _drawCircularArc1: (context, x1, y1, x4, y4, xc, yc)->
    a1 = Math.atan2(y1-yc, x1-xc)
    a2 = Math.atan2(y4-yc, x4-xc)
    r = Math.sqrt((y1-yc)**2 + (x1-xc)**2)
    context.arc xc, yc, r, a1, a2
    
  _drawCircularArc: (context, x1, y1, x4, y4, xc, yc)->
    #http://itc.ktu.lt/itc354/Riskus354.pdf
    ax = x1 - xc
    ay = y1 - yc
    bx = x4 - xc
    by_ = y4 - yc
    q1 = ax**2 + ay ** 2
    q2 = q1 + ax*bx + ay*by_
    k2 = 4.0/3.0*(Math.sqrt(2*q1*q2)-q2) / (ax*by_ - ay*bx)

    x2 = xc+x1 - k2*y1
    y2 = yc+y1 + k2*x1

    x3 = xc+x4 - k2*y4
    y3 = yc + y4 + k2*x4

    context.bezierCurveTo( x2, y2, x3, y3, x4, y4 )
    
                
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
    
