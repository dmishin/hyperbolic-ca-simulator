"use strict"
{Tessellation} = require "./hyperbolic_tessellation.coffee"
{unity, NodeHashMap, newNode, showNode, chainEquals, node2array} = require "./vondyck_chain.coffee"
{makeAppendRewrite, makeAppendRewriteRef, makeAppendRewriteVerified, vdRule, eliminateFinalA} = require "./vondyck_rewriter.coffee"
{RewriteRuleset, knuthBendix} = require "./knuth_bendix.coffee"
{mooreNeighborhood, evaluateTotalisticAutomaton, exportField, randomFill, randomStateGenerator} = require "./field.coffee"
{getCanvasCursorPosition} = require "./canvas_util.coffee"
{runCommands}= require "./context_delegate.coffee"
{lzw_encode} = require "./lzw.coffee"
{Navigator} = require "./navigator.coffee"
#{shortcut} = require "./shortcut.coffee"
{makeXYT2path, poincare2hyperblic, visibleNeighborhood} = require "./poincare_view.coffee"
{DomBuilder} = require "./dom_builder.coffee"
{ButtonGroup} = require "./htmlutil.coffee"

M = require "./matrix3.coffee"

E = (id) -> document.getElementById id






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
    @pattern = ["red", "black", "green", "blue", "yellow", "cyan", "magenta", "gray", "orange"]

    @onFinish = null
    
  getColorForState: (state) ->
    @pattern[ (state % @pattern.length + @pattern.length) % @pattern.length ]
    
  rebuildAt: (newCenter) ->
    @center = newCenter
    @cells = for offset in @cellOffsets
      #it is important to make copy since AR empties the array!
      eliminateFinalA @appendRewrite(newCenter, offset[..]), @appendRewrite, @tessellation.group.n
    @_observedCellsChanged()
    return

  navigateTo: (chain) ->
    console.log "navigated to #{showNode chain}"
    @rebuildAt chain
    @tfm = M.eye()
    @renderGrid @tfm
    return
        
  _observedCellsChanged: ->
    
  translateBy: (appendArray) ->
    #console.log  "New center at #{showNode newCenter}"
    @rebuildAt @appendRewrite @center, appendArray
  canDraw: -> true        
  draw: (cells, context) ->
    #first borders
    #cells grouped by state
    state2cellIndexList = {}
    
    for cell, i in @cells
      state = cells.get(cell) ? 0
      if (state isnt 0) or @drawEmpty
        stateCells = state2cellIndexList[state]
        unless stateCells?
          state2cellIndexList[state] = stateCells = []
        stateCells.push i
        
    for strState, cellIndices of state2cellIndexList
      state = parseInt strState, 10
      #console.log "Group: #{state}, #{JSON.stringify cellIndices}"
      
      context.beginPath()
      for cellIndex in cellIndices
        cellTfm = @cellTransforms[cellIndex]
        mtx = M.mul @tfm, cellTfm
        @tessellation.makeCellShapePoincare mtx, context
        
      if state is 0
        context.stroke()
      else
        context.fillStyle = @getColorForState state
        context.fill()
        
    #true because immediate-mode observer always finishes drawing.
    return true
  
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


class GenericTransitionFunc
  constructor: ( @numStates, @plus, @plusInitial, @evaluate ) ->
    if @numStates <= 0 then throw new Error "Number if states incorrect"
  toString: -> "GenericFunction( #{@numStates} states )"
  isStable: -> @evaluate(0,0) is 0
  
class BinaryTransitionFunc
  constructor: ( @n, @m, bornAt, stayAt ) ->
    @numNeighbors = @n*(@m-2)
    @table = for arr in [bornAt, stayAt]
      for s in [0 .. @numNeighbors] by 1
        if s in arr then 1 else 0
          
  isStable: -> table[0][0] is 0
  
  plus: (x,y) -> x+y
  plusInitial: 0
  
  numStates: 2
  
  evaluate: (state, sum) ->
    throw new Error "Bad state: #{state}" unless state in [0,1]
    throw new Error "Bad sum: #{sum}" if sum < 0 or sum > @numNeighbors
    @table[state][sum]

  toString: ->
    "B " + @_nonzeroIndices(@table[0]).join(" ") + " S " + @_nonzeroIndices(@table[1]).join(" ")
    
  _nonzeroIndices: (arr)-> (i for x, i in arr when x isnt 0)

#Generic TF is given by its code.
# Code is a JS object with 3 fields:
# states: N #integer
# sum: (r, x) -> r'  #default is (x,y) -> x+y
# sumInitial: value r0 #default is 0
# next: (sum, value) -> value
parseGenericTransitionFunction = (str) ->
  tfObject = eval('('+str+')')
  throw new Error("Numer of states not specified") unless tfObject.states?
  throw new Error("Transition function not specified") unless tfObject.next?
  
  #@numStates, @plus, @plusInitial, @evaluate )
  return new GenericTransitionFunc tfObject.states, (tfObject.sum ? ((x,y)->x+y)), (tfObject.sumInitial ? 0), tfObject.next

updateGenericRuleStatus = (status)->
  span = E 'generic-tf-status'
  span.innerHTML = status
  span.setAttribute('class', 'generic-tf-status-#{status.toLowerCase()}')  
      
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

class PaintStateSelector
  constructor: (@container, @buttonContainer)->
    @state = 1
    @numStates = 2
    
  update: (transitionFunc)->
    numStates = transitionFunc.numStates
    #only do something if number of states changed
    return if numStates == @numStates
    @numStates = numStates
    console.log "Num states changed to #{numStates}"
    if @state >= numStates
      @state = 1
    @buttonContainer.innerHTML = ''
    if numStates <= 2
      @container.style.display = 'none'
      @buttons = null
      @state2id = null
    else
      @container.style.display = ''
      dom = new DomBuilder()
      id2state = {}
      @state2id = {}
      for state in [1...numStates]
        color = observer.getColorForState state
        btnId = "select-state-#{state}"
        @state2id[state] = btnId
        id2state[btnId] = state
        dom.tag('button').store('btn')\
           .CLASS(if state is @state then 'btn-active' else '')\
           .ID(btnId)\
           .a('style', "background-color:#{color}")\
           .text(''+state)\
           .end()
        #dom.vars.btn.onclick = (e)->
      @buttonContainer.appendChild dom.finalize()
      @buttons = new ButtonGroup @buttonContainer, 'button'
      @buttons.addEventListener 'change', (e, btnId, oldBtn)=>
        if (state = id2state[btnId])?
          @state = state
  setState: (newState) ->
    return if newState is @state
    return unless @state2id[newState]?
    @state = newState
    if @buttons
      @buttons.setButton @state2id[newState]
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


paintStateSelector = new PaintStateSelector E("state-selector"), E("state-selector-buttons")

getNeighbors = mooreNeighborhood tessellation.group.n, tessellation.group.m, appendRewrite

#ObserverClass = FieldObserverWithRemoreRenderer
ObserverClass = FieldObserver

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
  cells = evaluateTotalisticAutomaton cells, getNeighbors, transitionFunc.evaluate.bind(transitionFunc), transitionFunc.plus, transitionFunc.plusInitial
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
    
  if cells.get(cell) is paintStateSelector.state
    cells.remove cell
  else
    cells.put cell, paintStateSelector.state
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
    paintStateSelector.update transitionFunc
    console.log transitionFunc
    E('controls-rule-simple').style.display=""
    E('controls-rule-generic').style.display="none"
  catch e
    alert "Failed to parse function: #{e}"

doOpenEditor = ->
  E('generic-tf-editor').style.display = ''

doCloseEditor = ->
  E('generic-tf-editor').style.display = 'none'


doSetRuleGeneric = ->
  try
    console.log "Set generic rule"
    transitionFunc = parseGenericTransitionFunction E('generic-tf-code').value
    updateGenericRuleStatus 'Compiled'
    paintStateSelector.update transitionFunc
    E('controls-rule-simple').style.display="none"
    E('controls-rule-generic').style.display=""
  catch e
    alert "Failed to parse function: #{e}"
    updateGenericRuleStatus 'Error'

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
  E('export-dialog').style.display = ''

doExportClose = ->
  E('export-dialog').style.display = 'none'
    
doSearch = ->
  navigator.search cells, tessellation.group.n, tessellation.group.m, appendRewrite

randomFillRadius = 5
randomFillPercent = 0.4
doRandomFill = ->
  randomFill cells, randomFillPercent, unity, randomFillRadius, appendRewrite, tessellation.group.n, tessellation.group.m, randomStateGenerator(transitionFunc.numStates)
  updatePopulation()
  redraw()

doEditAsGeneric = ->
  console.log "Generate code"
  unless transitionFunc instanceof BinaryTransitionFunc
    alert("Active transition function is not a binary")
    return
  E('generic-tf-code').value = binaryTransitionFunc2GenericCode(transitionFunc)
  updateGenericRuleStatus "modified"
  doSetRuleGeneric()

doDisableGeneric = ->
  doSetRule()

# ============ Bind Events =================
E("btn-reset").addEventListener "click", doReset
E("btn-step").addEventListener "click", doStep
E("canvas").addEventListener "mousedown", doCanvasClick
E("canvas").addEventListener "mouseup", doCanvasMouseUp
E("canvas").addEventListener "mousemove", doCanvasMouseMove
E("canvas").addEventListener "mousedrag", doCanvasMouseMove
E("btn-set-rule").addEventListener "click", doSetRule
E("btn-set-rule-generic").addEventListener "click", (e)->
  doSetRuleGeneric()
  doCloseEditor()
E("btn-rule-generic-close-editor").addEventListener "click", doCloseEditor
E("btn-set-grid").addEventListener "click", doSetGrid

E("btn-export").addEventListener "click", doExport
E('rule-entry').value = transitionFunc.toString()
E('btn-search').addEventListener 'click', doSearch
E('btn-random').addEventListener 'click', doRandomFill
E('btn-rule-make-generic').addEventListener 'click', doEditAsGeneric
E('btn-edit-rule').addEventListener 'click', doOpenEditor
E('btn-disable-generic-rule').addEventListener 'click', doDisableGeneric
E('btn-export-close').addEventListener 'click', doExportClose
#initialize
GENERIC_TF_TEMPLATE="""//Generic transistion function, coded in JS
{
  //number of states
  'states': 2,

  //Neighbors sum calculation. By default - sum of all.
  //'plus': function(s,x){ return s+x; },
  //'plusInitial': 0,

  //Transition function. Takes current state and sum, returns new state.
  'next': function(x, s){
    if (s==2) return x;
    if (s==3) return 1;
    return 0;
  }
}
"""

binaryTransitionFunc2GenericCode = (binTf) ->
  row2condition = (row) -> ("s==#{sum}" for nextValue, sum in row when nextValue).join(" || ")
  
  conditionBorn = row2condition binTf.table[0]
  conditionStay = row2condition binTf.table[1]
  
  code = ["""//Automatically generated code for binary rule #{binTf}
{
    //number of states
    'states': 2,

    //Neighbors sum calculation is default. Code for reference.
    //'plus': function(s,x){ return s+x; },
    //'plusInitial': 0,
    
    //Transition function. Takes current state and sum, returns new state.
    'next': function(x, s){
        if (x==1 && (#{conditionStay})) return 1;
        if (x==0 && (#{conditionBorn})) return 1;
        return 0;
     }
}"""]


if not E('generic-tf-code').value
  E('generic-tf-code').value = GENERIC_TF_TEMPLATE

shortcuts =
  'N': doStep
  'C': doReset
  'S': doSearch
  'R': doRandomFill
  '1': (e) -> paintStateSelector.setState 1
  '2': (e) -> paintStateSelector.setState 2
  '3': (e) -> paintStateSelector.setState 3
  '4': (e) -> paintStateSelector.setState 4
  '5': (e) -> paintStateSelector.setState 5
  
document.addEventListener "keydown", (e)->
  focused = document.activeElement
  if focused and focused.tagName.toLowerCase() in ['textarea', 'input']
    return
  keyCode = if e.keyCode > 32 and e.keyCode < 128
    String.fromCharCode e.keyCode
  else
    '#' + e.keyCode
  keyCode += "C" if e.ctrlKey
  keyCode += "A" if e.altKey
  keyCode += "S" if e.shiftKey
  console.log keyCode
  if (handler = shortcuts[keyCode])?
    e.preventDefault()
    handler(e)
redraw()
