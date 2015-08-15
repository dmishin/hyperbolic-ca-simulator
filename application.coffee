"use strict"
{Tessellation} = require "./hyperbolic_tessellation.coffee"
{unity, inverseChain, appendChain, NodeHashMap, newNode, showNode, chainEquals, node2array} = require "./vondyck_chain.coffee"
{makeAppendRewrite, makeAppendRewriteRef, makeAppendRewriteVerified, vdRule, eliminateFinalA} = require "./vondyck_rewriter.coffee"
{RewriteRuleset, knuthBendix} = require "./knuth_bendix.coffee"
{mooreNeighborhood, evaluateTotalisticAutomaton, exportField, randomFill} = require "./field.coffee"
{getCanvasCursorPosition} = require "./canvas_util.coffee"
{runCommands}= require "./context_delegate.coffee"
{lzw_encode} = require "./lzw.coffee"
{Navigator} = require "./navigator.coffee"
#{shortcut} = require "./shortcut.coffee"
{makeXYT2path, poincare2hyperblic, visibleNeighborhood} = require "./poincare_view.coffee"

M = require "./matrix3.coffee"

E = (id) -> document.getElementById id


colors = ["red", "green", "blue", "yellow", "cyan", "magenta", "gray", "orange"]

class FieldObserver
  constructor: (@tessellation, @appendRewrite, @minCellSize=1.0/400.0)->
    @center = unity
    @cells = visibleNeighborhood @tessellation, @appendRewrite, @minCellSize
    @cellOffsets = (node2array(c) for c in @cells)
    @cellTransforms = (c.repr(@tessellation.group) for c in @cells)
    @drawEmpty = true
    @jumpLimit = 1.5
    @tfm = M.eye()
    
    @viewUpdates = 0
    #precision falls from 1e-16 to 1e-9 in 1000 steps.
    @maxViewUpdatesBeforeCleanup = 500
    @xyt2path = makeXYT2path @tessellation.group, @appendRewrite

    @onFinish = null
    
  getViewCenter: ->@center
  getViewOffsetMatrix: ->@tfm
  
  rebuildAt: (newCenter) ->
    @center = newCenter
    @cells = for offset in @cellOffsets
      #it is important to make copy since AR empties the array!
      eliminateFinalA @appendRewrite(newCenter, offset[..]), @appendRewrite, @tessellation.group.n
    @_observedCellsChanged()
    return

  navigateTo: (chain, offsetMatrix=M.eye()) ->
    console.log "navigated to #{showNode chain}"
    @rebuildAt chain
    @tfm = offsetMatrix
    @renderGrid @tfm
    return
        
  _observedCellsChanged: ->
    
  translateBy: (appendArray) ->
    #console.log  "New center at #{showNode newCenter}"
    @rebuildAt @appendRewrite @center, appendArray
  canDraw: -> true        
  draw: (cells, context) ->
    #first borders
    if @drawEmpty
      context.beginPath()
      for cell, i in @cells
        unless cells.get cell
          cellTfm = @cellTransforms[i]
          mtx = M.mul @tfm, cellTfm
          @tessellation.makeCellShapePoincare mtx, context
      context.stroke()

    #then cells
    context.beginPath()
    for cell, i in @cells
      if cells.get cell
        cellTfm = @cellTransforms[i]
        mtx = M.mul @tfm, cellTfm
        @tessellation.makeCellShapePoincare  mtx, context        
    context.fill()
    #true because immediate-mode observer always finishes drawing.
    return true
    
  visibleCells: (cells) ->
    for cell in @cells when (value=cells.get(cell)) isnt null
      [cell, value]
        
  checkViewMatrix: ->
    #me = [-1,0,0,  0,-1,0, 0,0,-1]
    #d = M.add( me, M.mul(tfm, M.hyperbolicInv tfm))
    #ad = (Math.abs(x) for x in d)
    #maxDiff = Math.max( ad ... )
    #console.log "Step: #{viewUpdates}, R: #{maxDiff}"
    if (@viewUpdates+=1) > @maxViewUpdatesBeforeCleanup
      @viewUpdates = 0
      @tfm = M.cleanupHyperbolicMoveMatrix @tfm
    
  modifyView: (m) ->
    @tfm = M.mul m, @tfm
    @checkViewMatrix()
    originDistance = @viewDistanceToOrigin()
    if originDistance > @jumpLimit
      @rebaseView()
    @renderGrid @tfm
    
  renderGrid: (viewMatrix) ->
    #for immediaet mode observer, grid is rendered while drawing.
    @onFinish?()
    
  viewDistanceToOrigin: ->
    #viewCenter = M.mulv tfm, [0.0,0.0,1.0]
    #Math.acosh(viewCenter[2])
    Math.acosh @tfm[8]
    
  #build new view around the cell which is currently at the center
  rebaseView: ->
    centerCoord = M.mulv (M.inv @tfm), [0.0, 0.0, 1.0]
    pathToCenterCell = @xyt2path centerCoord
    #console.log "Jump by #{showNode pathToCenterCell}"
    m = pathToCenterCell.repr @tessellation.group

    #modifyView won't work, since it multiplies in different order.
    @tfm = M.mul @tfm, m
    @checkViewMatrix()

    #move observation point
    @translateBy node2array pathToCenterCell

  #xp, yp in range [-1..1]
  cellFromPoint:(xp,yp) ->
    xyt = poincare2hyperblic xp, yp
    throw new Error("point outside") if xyt is null
    #inverse transform it...
    xyt = M.mulv (M.inv @tfm), xyt
    visibleCell = @xyt2path xyt
    eliminateFinalA @appendRewrite(@center, node2array(visibleCell)), @appendRewrite, @tessellation.group.n
    
  shutdown: -> #nothing to do.
  
class FieldObserverWithRemoreRenderer extends FieldObserver
  constructor: (tessellation, appendRewrite, minCellSize=1.0/400.0)->
    super tessellation, appendRewrite, minCellSize
    @worker = new Worker "./render_worker.js"
    console.log "Worker created: #{@worker}"
    @worker.onmessage = (e) => @onMessage e

    @cellShapes = null

    @workerReady = false

    @rendering = true
    @cellSetState = 0
    @worker.postMessage ["I", [tessellation.group.n, tessellation.group.m, @cellTransforms]]
    
    @postponedRenderRequest = null

      
  _observedCellsChanged: ->
    console.log "Ignore all responces before answer..."
    @cellShapes = null
    @cellSetState+= 1
    return
        
  onMessage: (e) ->
    #console.log "message received: #{JSON.stringify e.data}"
    switch e.data[0]    
      when "I" then @onInitialized e.data[1] ...
      when "R" then @renderFinished e.data[1], e.data[2]
      else throw new Error "Unexpected answer from worker: #{JSON.stringify e.data}"
    return
    
  onInitialized: (n,m) ->
    if (n is @tessellation.group.n) and (m is @tessellation.group.m)
      console.log "Worker initialized"
      @workerReady = true
      #now waiting for first rendered field.
    else
      console.log "Init OK message received, but mismatched. Probably, late message"
      
  _runPostponed: ->
    if @postponedRenderRequest isnt null
      @renderGrid @postponedRenderRequest
      @postponedRenderRequest = null
          
  renderFinished: (renderedCells, cellSetState) ->
    #console.log "worker finished rendering #{renderedCells.length} cells"
    @rendering = false
    if cellSetState is @cellSetState
      @cellShapes = renderedCells
      @onFinish?()
    #else
    #  console.log "mismatch cell states: answer for #{cellSetState}, but current is #{@cellSetState}"
    @_runPostponed()
    
  renderGrid: (viewMatrix) ->
    if @rendering or not @workerReady
      @postponedRenderRequest = viewMatrix
    else
      @rendering = true
      @worker.postMessage ["R", viewMatrix, @cellSetState]
      
  canDraw: -> @cellShapes and @workerReady
  
  draw: (cells, context) ->
    if @cellShapes is null
      console.log "cell shapes null"
    return false if (not @cellShapes) or (not @workerReady)
    #first borders
    if @drawEmpty
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
  shutdown: ->
    @worker.terminate()
    

  
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
#

canvas = E "canvas"
context = canvas.getContext "2d"
minVisibleSize = 1/100
tessellation = new Tessellation 7,3
console.log "Running knuth-bendix algorithm...."
rewriteRuleset = knuthBendix vdRule tessellation.group.n, tessellation.group.m
console.log "Finished"
appendRewrite = makeAppendRewrite rewriteRuleset

getNeighbors = mooreNeighborhood tessellation.group.n, tessellation.group.m, appendRewrite

ObserverClass = FieldObserverWithRemoreRenderer
#ObserverClass = FieldObserver

observer = new ObserverClass tessellation, appendRewrite, minVisibleSize
observer.onFinish = -> redraw()

navigator = new Navigator observer

transitionFunc = parseTransitionFunction "B 3 S 2 3", tessellation.group.n, tessellation.group.m
dragHandler = null

cells = new NodeHashMap
cells.put unity, 1

doReset = ->
  cells = new NodeHashMap
  cells.put unity, 1
  updatePopulation()
  redraw()

doStep = ->
  cells = evaluateTotalisticAutomaton cells, getNeighbors, transitionFunc.evaluate.bind(transitionFunc)
  redraw()
  updatePopulation()

dirty = true
redraw = -> dirty = true

drawEverything = ->
  return false unless observer.canDraw()
  
  context.clearRect 0, 0, canvas.width, canvas.height
  context.save()
  s = Math.min( canvas.width, canvas.height ) / 2 #
  context.scale s, s
  context.translate 1, 1
  context.fillStyle = "black"
  context.lineWidth = 1.0/s
  context.strokeStyle = "rgb(128,128,128)"
  observer.draw cells, context
  context.restore()
  return true

fpsLimiting = false
lastTime = Date.now()
fpsDefault = 30
dtMax = 1000.0/fpsDefault #

redrawLoop = ->
  if dirty
    if not fpsLimiting or ((t=Date.now()) - lastTime > dtMax)
      if drawEverything()
        tDraw = Date.now() - t
        #adaptively update FPS
        dtMax = dtMax*0.9 + tDraw*2*0.1
        dirty = false
      lastTime = t
  requestAnimationFrame redrawLoop
    

toggleCellAt = (x,y) ->
  s = Math.min( canvas.width, canvas.height ) * 0.5
  xp = x/s - 1
  yp = y/s - 1
  try
    cell = observer.cellFromPoint xp, yp
  catch e
    return
    
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
  transitionFunc = parseTransitionFunction transitionFunc.toString(), tessellation.group.n, tessellation.group.m
  observer?.shutdown()
  observer = new ObserverClass tessellation, appendRewrite, minVisibleSize
  observer.onFinish = -> redraw()
  navigator.setObserver observer

moveView = (dx, dy) -> observer.modifyView M.translationMatrix(dx, dy)        
rotateView = (angle) -> observer.modifyView M.rotationMatrix angle
  
class MouseTool
  mouseMoved: ->
  mouseUp: ->
  mouseDown: ->
    



updatePopulation = ->
  E('population').innerHTML = ""+cells.count
    
#redraw()
updatePopulation()
redrawLoop()

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

doExport = ->
  data = JSON.stringify(exportField(cells))
  edata = lzw_encode data
  alert "Data len before compression: #{data.length}, after compression: #{edata.length}, ratio: #{edata.length/data.length}"
  E('export').value = edata
doSearch = ->
  navigator.search cells, tessellation.group.n, tessellation.group.m, appendRewrite

memo = null
doMemorize = ->
  memo =
    cells: cells.copy()
    viewCenter: observer.getViewCenter()
    viewOffset: observer.getViewOffsetMatrix()
  console.log "Position memoized"

doRemember = ->
  if memo is null
    console.log "nothing to remember"
  else
    cells = memo.cells.copy()
    observer.navigateTo memo.viewCenter, memo.viewOffset

doClearMemory = ->
  memo = null        
  

encodeVisible = ->
  iCenter = inverseChain observer.getViewCenter(), appendRewrite
  visibleCells = new NodeHashMap
  for [cell, state] in observer.visibleCells cells
    translatedCell = appendChain iCenter, cell, appendRewrite
    visibleCells.put translatedCell, state
  return exportField visibleCells

doExportVisible = ->
  alert JSON.stringify encodeVisible()            

randomFillRadius = 5
randomFillPercent = 0.4
doRandomFill = ->
  randomFill cells, randomFillPercent, unity, randomFillRadius, appendRewrite, tessellation.group.n, tessellation.group.m
  updatePopulation()
  redraw()
  
# ============ Bind Events =================
E("btn-reset").addEventListener "click", doReset
E("btn-step").addEventListener "click", doStep
E("canvas").addEventListener "mousedown", doCanvasClick
E("canvas").addEventListener "mouseup", doCanvasMouseUp
E("canvas").addEventListener "mousemove", doCanvasMouseMove
E("canvas").addEventListener "mousedrag", doCanvasMouseMove
E("btn-set-rule").addEventListener "click", doSetRule
E("btn-set-grid").addEventListener "click", doSetGrid
E("btn-export").addEventListener "click", doExport
E('rule-entry').value = transitionFunc.toString()
E('btn-search').addEventListener 'click', doSearch
E('btn-random').addEventListener 'click', doRandomFill

E('btn-mem-set').addEventListener 'click', doMemorize
E('btn-mem-get').addEventListener 'click', doRemember
E('btn-mem-clear').addEventListener 'click', doClearMemory
E('btn-exp-visible').addEventListener 'click', doExportVisible

shortcuts =
  #N
  '78': doStep
  #C
  '67': doReset
  #S
  '83': doSearch
  #R
  '82': doRandomFill

  #M
  '77': doMemorize
  #U
  '85': doRemember
  '77A': doClearMemory
  
  
document.addEventListener "keydown", (e)->
  keyCode = "" + e.keyCode
  keyCode += "C" if e.ctrlKey
  keyCode += "A" if e.altKey
  keyCode += "S" if e.shiftKey
  #console.log keyCode
  if (handler = shortcuts[keyCode])?
    e.preventDefault()
    handler(e)
redraw()
