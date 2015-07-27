"use strict"
{Tessellation} = require "./hyperbolic_tessellation.coffee"
{NodeHashMap, nodeMatrixRepr, newNode, showNode, chainEquals, nodeHash, node2array} = require "./vondyck_chain.coffee"
{makeAppendRewrite, makeAppendRewriteRef, makeAppendRewriteVerified, vdRule, eliminateFinalA} = require "./vondyck_rewriter.coffee"
{RewriteRuleset, knuthBendix} = require "./knuth_bendix.coffee"
{mooreNeighborhood, evaluateTotalisticAutomaton} = require "./field.coffee"
{getCanvasCursorPosition} = require "./canvas_util.coffee"
{runCommands}= require "./context_delegate.coffee"

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
        
class FieldObserverWithRemoreRenderer extends FieldObserver
  constructor: (tessellation, appendRewrite, minCellSize=1.0/400.0)->
    super tessellation, appendRewrite, minCellSize
    @worker = new Worker "./render_worker.js"
    console.log "Worker created: #{@worker}"
    @worker.onmessage = (e) => @onMessage e

    @cellShapes = null

    @workerReady = false

    @rendering = true
    @worker.postMessage ["I", [tessellation.group.n, tessellation.group.m, @cellTransforms]]
    
    @onFinish = null
    @postponedRenderRequest = null
    
  onMessage: (e) ->
    #console.log "message received: #{JSON.stringify e.data}"
    switch e.data[0]    
      when "I" then @onInitialized e.data[1] ...
      when "R" then @renderFinished e.data[1]
      else throw new Error "Unexpected answer from worker: #{JSON.stringify e.data}"
    return
    
  onInitialized: (n,m) ->
    if n is @tessellation.group.n and m is tessellation.group.m
      console.log "Worker initialized"
      @workerReady = true
      #now waiting for first rendered field.
    else
      console.log "Init OK message received, but mismatched. Probably, late message"
      
  _runPostponed: ->
    if @postponedRenderRequest isnt null
      @renderGrid @postponedRenderRequest
      @postponedRenderRequest = null
          
  renderFinished: (renderedCells) ->
    #console.log "worker finished rendering #{renderedCells.length} cells"
    @cellShapes = renderedCells
    @rendering = false
    
    @onFinish?()
    @_runPostponed()
    
  renderGrid: (viewMatrix) ->
    if @rendering or not @workerReady
      @postponedRenderRequest = viewMatrix
    else
      @rendering = true
      @worker.postMessage ["R", viewMatrix]

  draw: (cells, context) ->
    return false if (not @cellShapes) or (not @workerReady)
    context.fillStyle = "black"
    context.lineWidth = 1.0/400.0
    context.strokeStyle = "rgb(128,128,128)"

    #first borders
    context.beginPath()
    for cell, i in @cells
      unless cells.get cell
        runCommands context, @cellShapes[i]
    context.stroke()

    #then cells
    context.beginPath()
    for cell, i in @cells
      if cells.get cell
        runCommands context, @cellShapes[i]
    context.fill()
    return true
    
      
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
visibleNeighborhood = (tessellation, appendRewrite, minCellSize=1.0/400.0) ->
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
    
# BxxxSxxx
parseTransitionFunction = (str, n, m) ->
  match = str.match /B([\d\s]+)S([\d\s]+)/
  throw new Error("Bad function string: #{str}") unless match?
  numNeighbors = n*(m-2)
  parseIntChecked = (s)->
    v = parseInt s, 10
    throw new Error("Bad number: #{s}") if Number.isNaN v
    v
    
  strings2array = (s)->
    for part in s.split ' ' when part
      parseIntChecked part

  bArray = strings2array match[1]
  sArray = strings2array match[2]
  
  transitionTable = for arr in [bArray, sArray]
    for s in [0 .. numNeighbors] by 1
      if s in arr
        1
      else
        0
  console.log JSON.stringify transitionTable
  return (state, sum) ->
    throw new Error "Bad state: #{state}" if not (state in [0,1])
    throw new Error "Bad sum: #{sum}" if sum <0 or sum > numNeighbors
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

#observer = new FieldObserver tessellation, appendRewrite, minVisibleSize
# 
observer = new FieldObserverWithRemoreRenderer tessellation, appendRewrite, minVisibleSize
observer.onFinish = ->
  redraw()

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
  cells = evaluateWithNeighbors cells, getNeighbors, transitionFunc
  redraw()
  updatePopulation()

dirty = true
redraw = -> dirty = true

drawEverything = ->
  s = Math.min( canvas.width, canvas.height ) / 2 #
  context.clearRect 0, 0, canvas.width, canvas.height
  context.save()
  context.scale s, s
  context.translate 1, 1
  rval = observer.draw cells, context
  context.restore()
  return rval

lastTime = Date.now()
fpsMax = 60
dtMax = 1000.0/fpsMax #
redrawLoop = ->
  if dirty
    t = Date.now()
    if t - lastTime > dtMax
      if drawEverything()
        dirty = false
      lastTime = t
  requestAnimationFrame redrawLoop
    

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
      dragHandler = new MovingDragger x, y
    else
      dragHandler = new RotatingDragger x, y

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
    ruleElem = E 'rule-entry'
    transitionFunc = parseTransitionFunction ruleElem.value, tessellation.group.n, tessellation.group.m
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
    if 1/n + 1/m >= 1
      throw new Error "Tessellation {#{n}; #{m}} is not hyperbolic."

    setGridImpl n, m

    doReset()
    
  catch e
    alert "Failed to set grid parameters: #{e}"

setGridImpl = (n, m)->
  tessellation = new Tessellation n,m
  console.log "Running knuth-bendix algorithm for #{n}, #{m}...."
  rewriteRuleset = knuthBendix vdRule tessellation.group.n, tessellation.group.m
  console.log "Finished"
  appendRewrite = makeAppendRewrite rewriteRuleset

  getNeighbors = mooreNeighborhood tessellation.group.n, tessellation.group.m, appendRewrite
  xytFromCell = xyt2cell tessellation.group, appendRewrite

  transitionFunc = parseTransitionFunction "B 3 S 2 3", tessellation.group.n, tessellation.group.m
  observer = new FieldObserver tessellation, appendRewrite, minVisibleSize
  
###
#
###
moveMatrix = (dx, dy) ->
  r2 = dx*dx+dy*dy
  dt = Math.sqrt(r2+1)
  k = (dt-1)/r2

  xxk = dx*dx*k
  xyk = dx*dy*k
  yyk = dy*dy*k
  
  [xxk+1, xyk,   dx,
   xyk,   yyk+1, dy,
   dx,     dy,     dt]
              
rotateMatrix = (angle) ->
  s = Math.sin angle
  c = Math.cos angle
  [c,   s,   0.0,
   -s,  c,   0.0,
   0.0, 0.0, 1.0]

jumpLimit = 1.5
  
modifyView = (m) ->
  tfm = M.mul m, tfm
  checkViewMatrix()
  originDistance = viewDistanceToOrigin()
  if originDistance > jumpLimit
    rebaseView()

  observer.renderGrid tfm
  #redraw()   #redraw is called when observer is ready

rotateView = (angle) -> modifyView rotateMatrix angle
moveView = (dx, dy) -> modifyView moveMatrix(dx, dy)

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
    
#redraw()
updatePopulation()
redrawLoop()

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

class MovingDragger
  constructor: (@x0, @y0) ->
  mouseMoved: (e)->
    [x, y] = getCanvasCursorPosition e, canvas
    dx = x - @x0
    dy = y - @y0

    @x0 = x
    @y0 = y
    k = 2.0 / canvas.height
    moveView dx*k , dy*k
    
  mouseUp: (e)->
    console.log "up"
    
class RotatingDragger
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
    
  mouseUp: (e)->
  
                    
# ============ Bind Events =================
E("btn-reset").addEventListener "click", doReset
E("btn-step").addEventListener "click", doStep
E("canvas").addEventListener "mousedown", doCanvasClick
E("canvas").addEventListener "mouseup", doCanvasMouseUp
E("canvas").addEventListener "mousemove", doCanvasMouseMove
E("canvas").addEventListener "mousedrag", doCanvasMouseMove
E("btn-set-rule").addEventListener "click", doSetRule
E("btn-set-grid").addEventListener "click", doSetGrid

test_drawOrder2NMeighbors = ->
  coordsWithPaths = []
  
  #Initial cell
  cell = null
  
  for nei in getNeighbors cell
    for nei2 in getNeighbors nei
      if cells.get nei2
        console.log "already present! #{showNode nei2}"
      else
        cells.put nei2, 1
        cellCenter = M.mulv nodeMatrixRepr(nei2, tessellation.group), [0,0,1]
        found = false
        for [z, paths], i in coordsWithPaths
          if M.approxEqv z, cellCenter
            console.log "Path #{showNode nei2} already has equals:"
            for p, j in paths
              console.log "  #{j+1}) #{showNode p}"
              #throw new Error "Stop"
            paths.push nei2
            found = true
            break
        if not found
          console.log "First occurence of #{showNode nei2}"
          coordsWithPaths.push [cellCenter, [nei2]]
            

  console.log "Population is #{cells.count}"    
  console.log JSON.stringify rewriteRuleset
    
  #cells.put null, 1
  #cells.put newNode('a', 1, newNode('b',1,null)), 1
  #cells.put newNode('a', 1, newNode('b',1,newNode('a', 2, newNode('b',1,null)))), 1
                          

  context.save()
  s = Math.min( canvas.width, canvas.height ) / 2
  context.scale s, s
  context.translate 1, 1

  drawCells cells, tfm, tessellation, context
  context.restore()

#test_drawOrder2NMeighbors()
