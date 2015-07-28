"use strict"
{Tessellation} = require "./hyperbolic_tessellation.coffee"
{NodeHashMap, nodeMatrixRepr, newNode, showNode, chainEquals, nodeHash, node2array} = require "./vondyck_chain.coffee"
{makeAppendRewrite, makeAppendRewriteRef, makeAppendRewriteVerified, vdRule, eliminateFinalA} = require "./vondyck_rewriter.coffee"
{RewriteRuleset, knuthBendix} = require "./knuth_bendix.coffee"
{mooreNeighborhood, evaluateTotalisticAutomaton} = require "./field.coffee"
{getCanvasCursorPosition} = require "./canvas_util.coffee"


M = require "./matrix3.coffee"

E = (id) -> document.getElementById id


colors = ["red", "green", "blue", "yellow", "cyan", "magenta", "gray", "orange"]

class FieldObserver
  constructor: (@tessellation, @appendRewrite, @minCellSize=1.0/400.0)->
    @center = null
    @cells = visibleNeighborhood @tessellation, @appendRewrite, @minCellSize
    @cellOffsets = (node2array(c) for c in @cells)
    @cellTransforms = (nodeMatrixRepr(c, @tessellation.group) for c in @cells)
  rebuildAt: (newCenter) ->
    @center = newCenter
    @cells = for offset in @cellOffsets
      #it is important to make copy since AR empties the array!
      eliminateFinalA @appendRewrite(newCenter, offset[..]), @appendRewrite, @tessellation.group.n
    return
    
  translateBy: (appendArray) ->
    #console.log  "New center at #{showNode newCenter}"
    @rebuildAt @appendRewrite @center, appendArray
        
  draw: (cells, viewMatrix, context) ->
    context.fillStyle = "black"
    context.lineWidth = 1.0/400.0
    context.strokeStyle = "rgb(128,128,128)"

    #first borders
    context.beginPath()
    for cell, i in @cells
      unless cells.get cell
        cellTfm = @cellTransforms[i]
        mtx = M.mul viewMatrix, cellTfm
        @tessellation.makeCellShapePoincare mtx, context
    context.stroke()

    #then cells
    context.beginPath()
    for cell, i in @cells
      if cells.get cell
        cellTfm = @cellTransforms[i]
        mtx = M.mul viewMatrix, cellTfm
        @tessellation.makeCellShapePoincare  mtx, context        
    context.fill()
    return      
        
mooreNeighborhood = (n, m, appendRewrite)->(chain)->
  #reutrns Moore (vertex) neighborhood of the cell.
  # it contains N cells of von Neumann neighborhood
  #    and N*(M-3) cells, sharing single vertex.
  # In total, N*(M-2) cells.
  neighbors = []
  for powerA in [0...n] by 1
    for powerB in [1...m-1] by 1
      #adding truncateA to eliminate final rotation of the chain.
      nStep = if powerA
            [['b', powerB], ['a', powerA]]
        else
            [['b', powerB]]
      neigh = eliminateFinalA appendRewrite(chain, nStep), appendRewrite, n
      neighbors.push neigh
  return neighbors

neighborsSum = (cells, getNeighborhood)->
  sums = new NodeHashMap
  plus = (x,y)->x+y
  cells.forItems (cell, value)->
    if value isnt 1
      throw new Error "Value of #{showNode cell} is not 1: #{value}"
    for neighbor in getNeighborhood cell
      sums.putAccumulate neighbor, value, plus
  return sums

evaluateWithNeighbors = (cells, getNeighborhood, nextStateFunc)->
  newCells = new NodeHashMap
  sums = neighborsSum cells, getNeighborhood
  
  sums.forItems (cell, neighSum)->
    #console.log "#{showNode cell}, sum=#{neighSum}"
    cellState = cells.get(cell) ? 0
    nextState = nextStateFunc cellState, neighSum
    if nextState isnt 0
      newCells.put cell, nextState
  return newCells

#determine cordinates of the cell, containing given point
xyt2cell = (group, appendRewrite, maxSteps=100) -> 
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
    cell = null #start search at origin
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
poincare2hyperblic = (x,y) ->
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
visibleNeighborhood = (tessellation, appendRewrite, minCellSize) ->
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
  walk null
  visibleCells = []
  cells.forItems (cell, size)->
    if size >= minCellSize
      visibleCells.push cell
  console.log "VIsible neighborhood of null: #{visibleCells.length} cells"
  return visibleCells

class BinaryTransitionFunc
  constructor: ( @n, @m, bornAt, stayAt ) ->
    @numNeighbors = @n*(@m-2)
    @table = for arr in [bornAt, stayAt]
      for s in [0 .. @numNeighbors] by 1
        if s in arr then 1 else 0
  isStable: -> table[0][0] is 0
  evaluate: (state, sum) ->
    throw new Error "Bad state: #{state}" unless state in [0,1]
    throw new Error "Bad sum: #{sum}" if sum < 0 or sum > @numNeighbors
    @table[state][sum]

  toString: ->
    "B " + @_nonzeroIndices(@table[0]).join(" ") + " S " + @_nonzeroIndices(@table[1]).join(" ")
    
  _nonzeroIndices: (arr)-> (i for x, i in arr when x isnt 0)
    
# BxxxSxxx
parseTransitionFunction = (str, n, m) ->
  match = str.match /B([\d\s]+)S([\d\s]+)/
  throw new Error("Bad function string: #{str}") unless match?
  parseIntChecked = (s)->
    v = parseInt s, 10
    throw new Error("Bad number: #{s}") if Number.isNaN v
    v
    
  strings2array = (s)->
    for part in s.split ' ' when part
      parseIntChecked part

  bArray = strings2array match[1]
  sArray = strings2array match[2]

  return new BinaryTransitionFunc n, m, bArray, sArray
  
  return (state, sum) ->
    transitionTable[state][sum]

#putRandomBlob = (cells, radius, percent, n, m, appendRewrite)->
  
# ============================================  app code ===============
canvas = E "canvas"
context = canvas.getContext "2d"
minVisibleSize = 1/100
tessellation = new Tessellation 7,3
console.log "Running knuth-bendix algorithm...."
rewriteRuleset = knuthBendix vdRule tessellation.group.n, tessellation.group.m
console.log "Finished"
appendRewrite = makeAppendRewrite rewriteRuleset

getNeighbors = mooreNeighborhood tessellation.group.n, tessellation.group.m, appendRewrite
xytFromCell = xyt2cell tessellation.group, appendRewrite

viewCenter = null
#visibleCells = visibleNeighborhood tessellation, appendRewrite, minVisibleSize #farNeighborhood viewCenter, 5, appendRewrite, tessellation.group.n, tessellation.group.m

observer = new FieldObserver tessellation, appendRewrite, minVisibleSize

#console.log "Visible field contains #{visibleCells.length} cells"

transitionFunc = parseTransitionFunction "B 3 S 2 3", tessellation.group.n, tessellation.group.m
dragHandler = null

tfm = M.eye()
cells = new NodeHashMap
cells.put null, 1

doReset = ->
  cells = new NodeHashMap
  cells.put null, 1
  updatePopulation()
  redraw()

doStep = ->
  cells = evaluateWithNeighbors cells, getNeighbors, transitionFunc.evaluate.bind(transitionFunc)
  redraw()
  updatePopulation()

frameRequested = false
redraw = ->
  s = Math.min( canvas.width, canvas.height ) / 2
  #avoid spamming frame requests for smoother movement.
  unless frameRequested
    frameRequested = true
    window.requestAnimationFrame ->
      frameRequested = false
      context.clearRect 0, 0, canvas.width, canvas.height
      context.save()
      context.scale s, s
      context.translate 1, 1
      observer.draw cells, tfm, context
      context.restore()  

toggleCellAt = (x,y) ->
  s = Math.min( canvas.width, canvas.height ) * 0.5
  xp = x/s - 1
  yp = y/s - 1
  xyt = poincare2hyperblic xp, yp
  #inverse transform it...
  xyt = M.mulv (M.inv tfm), xyt
  if xyt isnt null
    visibleCell = xytFromCell xyt
    cell = eliminateFinalA appendRewrite(observer.center, node2array(visibleCell)), appendRewrite, tessellation.group.n
    #console.log showNode cell
    if cells.get(cell) isnt null
      cells.remove cell
    else
      cells.put cell, 1
    redraw()
    
doCanvasClick = (e) ->
  e.preventDefault()
  [x,y] = getCanvasCursorPosition e, canvas
  unless (e.button is 0) and not e.shiftKey
    toggleCellAt x, y
    updatePopulation()    
  else 
    cx = canvas.width*0.5
    cy = canvas.height*0.5
    r = Math.min(cx, cy)

    dx = x-cx
    dy = y-cy
    if dx*dx + dy*dy <= r*r*(0.8*0.8)
      dragHandler = new MouseToolPan x, y
    else
      dragHandler = new MouseToolRotate x, y

doCanvasMouseMove = (e) ->
  if dragHandler isnt null
    e.preventDefault()
    dragHandler.mouseMoved e

doCanvasMouseUp = (e) ->
  if dragHandler isnt null
    e.preventDefault()
    dragHandler?.mouseUp e
    dragHandler = null
            
doSetRule =  ->
  try
    transitionFunc = parseTransitionFunction E('rule-entry').value, tessellation.group.n, tessellation.group.m
  catch e
    alert "Failed to parse function: #{e}"

doSetGrid = ->
  try
    n = parseInt E('entry-n').value, 10
    m = parseInt E('entry-m').value, 10
    if Number.isNaN(n) or n <= 0
      throw new Error "Parameter N is bad"

    if Number.isNaN(m) or m <= 0
      throw new Error "Parameter M is bad"
    #if 1/n + 1/m <= 1/2
    if 2*(n+m) >= n*m
      throw new Error "Tessellation {#{n}; #{m}} is not hyperbolic and not supported."
    setGridImpl n, m
    doReset()
  catch e
    alert ""+e

setGridImpl = (n, m)->
  tessellation = new Tessellation n, m
  console.log "Running knuth-bendix algorithm for {#{n}, #{m}}...."
  rewriteRuleset = knuthBendix vdRule tessellation.group.n, tessellation.group.m
  console.log "Finished"
  appendRewrite = makeAppendRewrite rewriteRuleset
  getNeighbors = mooreNeighborhood tessellation.group.n, tessellation.group.m, appendRewrite
  xytFromCell = xyt2cell tessellation.group, appendRewrite
  transitionFunc = parseTransitionFunction transitionFunc.toString(), tessellation.group.n, tessellation.group.m
  observer = new FieldObserver tessellation, appendRewrite, minVisibleSize

moveView = (dx, dy) -> modifyView M.translationMatrix(dx, dy)        
rotateView = (angle) -> modifyView M.rotationMatrix angle
  
class MouseTool
  mouseMoved: ->
  mouseUp: ->
  mouseDown: ->
    

jumpLimit = 1.5
  
modifyView = (m) ->
  tfm = M.mul m, tfm
  checkViewMatrix()
  originDistance = viewDistanceToOrigin()
  if originDistance > jumpLimit
    rebaseView()
  redraw()  

viewDistanceToOrigin = ->
  #viewCenter = M.mulv tfm, [0.0,0.0,1.0]
  #Math.acosh(viewCenter[2])
  Math.acosh tfm[8]

#build new view around the cell which is currently at the center
rebaseView = ->
  centerCoord = M.mulv (M.inv tfm), [0.0, 0.0, 1.0]
  pathToCenterCell = xytFromCell centerCoord
  #console.log "Jump by #{showNode pathToCenterCell}"
  m = nodeMatrixRepr pathToCenterCell, tessellation.group

  #modifyView won't work, since it multiplies in different order.
  tfm = M.mul tfm, m
  checkViewMatrix()

  #move observation point
  observer.translateBy node2array pathToCenterCell

updatePopulation = ->
  E('population').innerHTML = ""+cells.count
    
redraw()
updatePopulation()

viewUpdates = 0
#precision falls from 1e-16 to 1e-9 in 1000 steps.
maxViewUpdatesBeforeCleanup = 500
checkViewMatrix = ->
  #me = [-1,0,0,  0,-1,0, 0,0,-1]
  #d = M.add( me, M.mul(tfm, M.hyperbolicInv tfm))
  #ad = (Math.abs(x) for x in d)
  #maxDiff = Math.max( ad ... )
  #console.log "Step: #{viewUpdates}, R: #{maxDiff}"
  if (viewUpdates+=1) > maxViewUpdatesBeforeCleanup
    viewUpdates = 0
    tfm = M.cleanupHyperbolicMoveMatrix tfm

class MouseToolPan extends MouseTool
  constructor: (@x0, @y0) ->
  mouseMoved: (e)->
    [x, y] = getCanvasCursorPosition e, canvas
    dx = x - @x0
    dy = y - @y0

    @x0 = x
    @y0 = y
    k = 2.0 / canvas.height
    moveView dx*k , dy*k
    
class MouseToolRotate extends MouseTool
  constructor: (x, y) ->
    @xc = canvas.width * 0.5
    @yc = canvas.width * 0.5
    @angle0 = @angle x, y 
    
  angle: (x,y) -> Math.atan2( x-@xc, y-@yc)
    
  mouseMoved: (e)->
    [x, y] = getCanvasCursorPosition e, canvas
    newAngle = @angle x, y
    dAngle = newAngle - @angle0
    @angle0 = newAngle
    rotateView dAngle
                      
# ============ Bind Events =================
E("btn-reset").addEventListener "click", doReset
E("btn-step").addEventListener "click", doStep
E("canvas").addEventListener "mousedown", doCanvasClick
E("canvas").addEventListener "mouseup", doCanvasMouseUp
E("canvas").addEventListener "mousemove", doCanvasMouseMove
E("canvas").addEventListener "mousedrag", doCanvasMouseMove
E("btn-set-rule").addEventListener "click", doSetRule
E("btn-set-grid").addEventListener "click", doSetGrid

E('rule-entry').value = transitionFunc.toString()
redraw()
