M = require "../core/matrix3.coffee"
{getCanvasCursorPosition} = require "./canvas_util.coffee"
{Debouncer} = require "./htmlutil.coffee"

exports.MouseTool = class MouseTool
  constructor: (@application) -> 
  mouseMoved: ->
  mouseUp: ->
  mouseDown: ->

  moveView: (dx, dy) ->
    @application.getObserver().modifyView M.translationMatrix(dx, dy)        
  rotateView: (angle) ->
    @application.getObserver().modifyView M.rotationMatrix angle
  


exports.MouseToolCombo = class MouseToolCombo extends MouseTool
  constructor: (application, x0, y0) ->
    super application
    [@x0, @y0] =  @application.canvas2relative x0, y0
    @angle0 = Math.atan2 @x0, @y0 
  mouseMoved: (e)->
    canvas = @application.getCanvas()    
    [x, y] = @application.canvas2relative getCanvasCursorPosition(e, canvas)...
    dx = x - @x0
    dy = y - @y0

    @x0 = x
    @y0 = y

    newAngle = Math.atan2 x, y
    dAngle = newAngle - @angle0
    #Wrap angle increment into -PI ... PI diapason.
    if dAngle > Math.PI
      dAngle = dAngle - Math.PI*2
    else if dAngle < -Math.PI
      dAngle = dAngle + Math.PI*2 
    @angle0 = newAngle 

    #determine mixing ratio
    r2 = x**2 + y**2
    #pure rotation at the edge,
    #pure pan at the center
    q = Math.min(1.0, r2**1.5)

    mv = M.translationMatrix(dx*(1-q) , dy*(1-q))
    rt = M.rotationMatrix dAngle*q
    @application.getObserver().modifyView M.mul(M.mul(mv,rt),mv)

###    
exports.MouseToolPan = class MouseToolPan extends MouseTool
  constructor: (application, @x0, @y0) ->
    super application
    @panEventDebouncer = new Debouncer 1000, =>
      @application.getObserver.rebaseView()
      
  mouseMoved: (e)->
    canvas = @application.getCanvas()
    [x, y] = getCanvasCursorPosition e, canvas
    dx = x - @x0
    dy = y - @y0

    @x0 = x
    @y0 = y
    k = 2.0 / canvas.height
    xc = (x - canvas.width*0.5)*k
    yc = (y - canvas.height*0.5)*k

    r2 = xc*xc + yc*yc
    s = 2 / Math.max(0.3, 1-r2)
    
    @moveView dx*k*s , dy*k*s
    @panEventDebouncer.fire()
    
exports.MouseToolRotate = class MouseToolRotate extends MouseTool
  constructor: (application, x, y) ->
    super application
    canvas = @application.getCanvas()
    @xc = canvas.width * 0.5
    @yc = canvas.width * 0.5
    @angle0 = @angle x, y 
    
  angle: (x,y) -> Math.atan2( x-@xc, y-@yc)
    
  mouseMoved: (e)->
    canvas = @application.getCanvas()
    [x, y] = getCanvasCursorPosition e, canvas
    newAngle = @angle x, y
    dAngle = newAngle - @angle0
    @angle0 = newAngle
    @rotateView dAngle

###
