"use strict"
{Tessellation} = require "./hyperbolic_tessellation.coffee"
{unity, inverseChain, appendChain, appendInverseChain, NodeHashMap, newNode, showNode, chainEquals, node2array} = require "./vondyck_chain.coffee"
{makeAppendRewrite, vdRule, eliminateFinalA} = require "./vondyck_rewriter.coffee"
{RewriteRuleset, knuthBendix} = require "./knuth_bendix.coffee"

{stringifyFieldData, parseFieldData, mooreNeighborhood, evaluateTotalisticAutomaton, exportField, importField, randomFill, mooreNeighborhood, evaluateTotalisticAutomaton, exportField, randomFill, randomStateGenerator} = require "./field.coffee"

{getCanvasCursorPosition} = require "./canvas_util.coffee"
{lzw_encode} = require "./lzw.coffee"
{Navigator} = require "./navigator.coffee"
#{shortcut} = require "./shortcut.coffee"
{makeXYT2path, poincare2hyperblic, visibleNeighborhood} = require "./poincare_view.coffee"
{DomBuilder} = require "./dom_builder.coffee"
{E, ButtonGroup, windowWidth, windowHeight, documentWidth, removeClass, addClass} = require "./htmlutil.coffee"
{FieldObserver} = require "./observer.coffee"
{FieldObserverWithRemoreRenderer} = require "./observer_remote.coffee"
{parseIntChecked} = require "./utils.coffee"
{Animator} = require "./animator.coffee"
M = require "./matrix3.coffee"

MIN_WIDTH = 100

canvasSizeUpdateBlocked = false
randomFillRadius = 5
randomFillPercent = 0.4

class Application
  constructor: ->

  getAppendRewrite: -> appendRewrite
  setCanvasResize: (enable) -> canvasSizeUpdateBlocked = enable
  getCanvasResize: -> canvasSizeUpdateBlocked
  redraw: -> redraw()
  getObserver: -> observer
  drawEverything: -> drawEverything()
  uploadToServer: (name, cb) -> uploadToServer name, cb
  doStep: -> doStep()
  getCanvas: -> canvas
  getGroup: -> tessellation.group
  
updateCanvasSize = ->
  return if canvasSizeUpdateBlocked
  
  docW = documentWidth()
  winW = windowWidth()
  
  if docW > winW
    console.log "overflow"
    usedWidth = docW - canvas.width
    #console.log "#Win: #{windowWidth()}, doc: #{documentWidth()}, used: #{usedWidth}"
    w = winW - usedWidth
  else
    #console.log "underflow"
    containerAvail=E('canvas-container').clientWidth
    #console.log "awail width: #{containerAvail}"
    w = containerAvail

  #now calculae available height
  canvasRect = canvas.getBoundingClientRect()
  winH = windowHeight()
  h = winH - canvasRect.top

  navWrap = E('navigator-wrap')
  navWrap.style.height = "#{winH - navWrap.getBoundingClientRect().top - 16}px"

  #get the smaller of both
  w = Math.min(w,h) 
  #reduce it a bit
  w -= 16
  
  #make width multiple of 16
  w = w & ~ 15
  
  #console.log "New w is #{w}"
  if w <= MIN_WIDTH
    w = MIN_WIDTH

  if canvas.width isnt w
    canvas.width = canvas.height = w
    redraw()
    E('image-size').value = ""+w
  return

doSetFixedSize = (isFixed) ->
  if isFixed
    size = parseIntChecked E('image-size').value
    if size <= 0 or size >=65536
      throw new Error "Bad size: #{size}"
    canvasSizeUpdateBlocked = true
    canvas.width = canvas.height = size
    redraw()
  else
    canvasSizeUpdateBlocked = false
    updateCanvasSize()

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
           .CLASS(if state is @state then 'btn-selected' else '')\
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

serverSupportsUpload = -> ((""+window.location).match /:8000\//) and true
# ============================================  app code ===============
#
if serverSupportsUpload()
  console.log "Enable upload"
  E('animate-controls').style.display=''

application = new Application
animator = new Animator application
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

generation = 0
cells = new NodeHashMap
cells.put unity, 1

doReset = ->
  cells = new NodeHashMap
  generation = 0
  cells.put unity, 1
  updatePopulation()
  updateGeneration()
  redraw()

doStep = (onFinish)->
  cells = evaluateTotalisticAutomaton cells, getNeighbors, transitionFunc.evaluate.bind(transitionFunc), transitionFunc.plus, transitionFunc.plusInitial
  generation += 1
  redraw()
  updatePopulation()
  updateGeneration()
  onFinish?()

player = null
playerTimeout = 500
autoplayCriticalPopulation = 90000
doStartPlayer = ->
  return if player?

  runPlayerStep = ->
    if cells.count >= autoplayCriticalPopulation
      alert "Population reached #{cells.count}, stopping auto-play"
      player = null
    else
      player = setTimeout( (-> doStep(runPlayerStep)), playerTimeout )
    updatePlayButtons()

  runPlayerStep()
  
doStopPlayer = ->
  if player
    clearTimeout player
    player = null
    updatePlayButtons()

doTogglePlayer = ->
  if player
    doStopPlayer()
  else
    doStartPlayer()

updatePlayButtons = ->
  E('btn-play-start').style.display = if player then "none" else ''
  E('btn-play-stop').style.display = unless player then "none" else ''

dirty = true
redraw = -> dirty = true

drawEverything = ->
  return false unless observer.canDraw()
  context.fillStyle = "white"  
  #context.clearRect 0, 0, canvas.width, canvas.height
  context.fillRect 0, 0, canvas.width, canvas.height
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

fpsLimiting = true
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

isPanMode = true
doCanvasMouseDown = (e) ->
  #Allow normal right-click to support image sacing
  E('canvas-container').focus()
  return if e.button is 2

  #Only in mozilla?
  canvas.setCapture? true
  
  e.preventDefault()
  [x,y] = getCanvasCursorPosition e, canvas

  isPanAction = (e.button is 1) ^ (e.shiftKey) ^ (isPanMode)
  console.log "Pan: #{isPanAction}"
  unless isPanAction
    toggleCellAt x, y
    updatePopulation()    
  else
    dragHandler = new MouseToolCombo x, y

doSetPanMode = (mode) ->
  isPanMode = mode

  bpan = E('btn-mode-pan')
  bedit = E('btn-mode-edit')
  removeClass bpan, 'button-active'
  removeClass bedit, 'button-active'

  addClass (if isPanMode then bpan else bedit), 'button-active'
  
doCanvasMouseMove = (e) ->
  
  isPanAction = (e.shiftKey) ^ (isPanMode)
  E('canvas-container').style.cursor = if isPanAction then 'move' else 'default'
    
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
    animator.reset()
  catch e
    alert ""+e

updateGrid = ->
  E('entry-n').value = "" + tessellation.group.n
  E('entry-m').value = "" + tessellation.group.m
  return

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
  navigator.clear()
  doClearMemory()
  doStopPlayer()

moveView = (dx, dy) -> observer.modifyView M.translationMatrix(dx, dy)        
rotateView = (angle) -> observer.modifyView M.rotationMatrix angle
  
class MouseTool
  mouseMoved: ->
  mouseUp: ->
  mouseDown: ->

updatePopulation = ->
  E('population').innerHTML = ""+cells.count
updateGeneration = ->
  E('generation').innerHTML = ""+generation    

class MouseToolCombo extends MouseTool
  constructor: (@x0, @y0) ->
    @xc = canvas.width * 0.5
    @yc = canvas.width * 0.5
    @angle0 = @angle @x0, @y0 
  angle: (x,y) -> Math.atan2( x-@xc, y-@yc)
  mouseMoved: (e)->
    [x, y] = getCanvasCursorPosition e, canvas
    dx = x - @x0
    dy = y - @y0

    @x0 = x
    @y0 = y
    k = 2.0 / canvas.height
    newAngle = @angle x, y
    dAngle = newAngle - @angle0
    #Wrap angle increment into -PI ... PI diapason.
    if dAngle > Math.PI
      dAngle = dAngle - Math.PI*2
    else if dAngle < -Math.PI
      dAngle = dAngle + Math.PI*2 
    @angle0 = newAngle 

    #determine mixing ratio
    r = Math.min(@xc, @yc)

    r2 = ((x-@xc)**2 + (y-@yc)**2) / (r**2)
    #pure rotation at the edge,
    #pure pan at the center
    q = Math.min(1.0, r2)

    mv = M.translationMatrix(dx*k*(1-q) , dy*k*(1-q))
    rt = M.rotationMatrix dAngle*q
    observer.modifyView M.mul(M.mul(mv,rt),mv)
  
class MouseToolPan extends MouseTool
  constructor: (@x0, @y0) ->
    @panEventDebouncer = new Debouncer 1000, =>
      observer.rebaseView()
      
  mouseMoved: (e)->
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
    
    moveView dx*k*s , dy*k*s
    @panEventDebouncer.fire()
    
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

exportTrivial = (cells) ->
  parts = []
  cells.forItems (cell, value)->
    parts.push showNode cell
    parts.push ""+value
  return parts.join " "
  
doExport = ->
  #data = JSON.stringify(exportField(cells))
  data = stringifyFieldData exportField cells
  #edata = lzw_encode data

  #data1 = exportTrivial cells
  #edata1 = lzw_encode data1
  
  #console.log "Data len before compression: #{data.length}, after compression: #{edata.length}, ratio: #{edata.length/data.length}"
  showExporDialog data

doExportClose = ->
  E('export-dialog').style.display = 'none'

getAjax = ->
  if window.XMLHttpRequest?
    return new XMLHttpRequest()
  else if window.ActiveXObject?
    return new ActiveXObject("Microsoft.XMLHTTP")
  
doUpload = ->
  uploadToServer "canvas.png", (e)->
    console.log e
    
uploadToServer = (imgname, callback)->
  dataURL = canvas.toDataURL();  
  cb = (blob) ->
    formData = new FormData()
    formData.append "file", blob, imgname
    ajax = getAjax()
    ajax.open 'POST', '/uploads/', false
    ajax.onreadystatechange = -> callback(ajax)
    ajax.send(formData)
  canvas.toBlob cb, "image/png"


doSearch = ->
  navigator.search cells, tessellation.group.n, tessellation.group.m, appendRewrite
  updateCanvasSize()

memo = null
doMemorize = ->
  memo =
    cells: cells.copy()
    viewCenter: observer.getViewCenter()
    viewOffset: observer.getViewOffsetMatrix()
    generation: generation
  console.log "Position memoized"
  updateMemoryButtons()
  
doRemember = ->
  if memo is null
    console.log "nothing to remember"
  else
    cells = memo.cells.copy()
    generation = memo.generation
    observer.navigateTo memo.viewCenter, memo.viewOffset
    updatePopulation()
    updateGeneration()

doClearMemory = ->
  memo = null        
  updateMemoryButtons()
  
updateMemoryButtons = ->
  E('btn-mem-get').disabled = E('btn-mem-clear').disabled = memo is null

encodeVisible = ->
  iCenter = inverseChain observer.cellFromPoint(0,0), appendRewrite
  visibleCells = new NodeHashMap
  for [cell, state] in observer.visibleCells cells
    translatedCell = appendChain iCenter, cell, appendRewrite
    translatedCell = eliminateFinalA translatedCell, appendRewrite, tessellation.group.n
    visibleCells.put translatedCell, state
  return exportField visibleCells

showExporDialog = (sdata) ->
  E('export').value = sdata
  E('export-dialog').style.display = ''
  E('export').focus()
  E('export').select()
  
doExportVisible = ->
  showExporDialog stringifyFieldData encodeVisible()
  
doShowImport = ->
  E('import-dialog').style.display = ''
  E('import').focus()
  
doImportCancel = ->
  E('import-dialog').style.display = 'none'
  E('import').value=''
doImport = ->
  try
    data = parseFieldData E('import').value
    cells = importField data 
    updatePopulation()
    redraw()
    E('import-dialog').style.display = 'none'
    E('import').value=''
  catch e
    alert "Error parsing: #{e}"
    
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

doNavigateHome = ->
  observer.navigateTo unity

doStraightenView = ->
  observer.setViewOffsetMatrix M.eye()
  
class Debouncer
  constructor: (@timeout, @callback) ->
    @timer = null
  fire:  ->
    if @timer
      clearTimeout @timer
    @timer = setTimeout (=>@onTimer()), @timeout
  onTimer: ->
    @timer = null
    @callback()

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

# ============ Bind Events =================
E("btn-reset").addEventListener "click", doReset
E("btn-step").addEventListener "click", doStep
mouseMoveReceiver = E("canvas-container")
mouseMoveReceiver.addEventListener "mousedown", doCanvasMouseDown
mouseMoveReceiver.addEventListener "mouseup", doCanvasMouseUp
mouseMoveReceiver.addEventListener "mousemove", doCanvasMouseMove
mouseMoveReceiver.addEventListener "mousedrag", doCanvasMouseMove

E("btn-set-rule").addEventListener "click", doSetRule
E("rule-entry").addEventListener "change", doSetRule
E("btn-set-rule-generic").addEventListener "click", (e)->
  doSetRuleGeneric()
  doCloseEditor()
E("btn-rule-generic-close-editor").addEventListener "click", doCloseEditor
E("btn-set-grid").addEventListener "click", doSetGrid

E("btn-export").addEventListener "click", doExport
E('btn-search').addEventListener 'click', doSearch
E('btn-random').addEventListener 'click', doRandomFill
E('btn-rule-make-generic').addEventListener 'click', doEditAsGeneric
E('btn-edit-rule').addEventListener 'click', doOpenEditor
E('btn-disable-generic-rule').addEventListener 'click', doDisableGeneric
E('btn-export-close').addEventListener 'click', doExportClose
E('btn-import').addEventListener 'click', doShowImport
E('btn-import-cancel').addEventListener 'click', doImportCancel
E('btn-import-run').addEventListener 'click', doImport
#initialize
if not E('generic-tf-code').value
  E('generic-tf-code').value = GENERIC_TF_TEMPLATE

E('btn-mem-set').addEventListener 'click', doMemorize
E('btn-mem-get').addEventListener 'click', doRemember
E('btn-mem-clear').addEventListener 'click', doClearMemory
E('btn-exp-visible').addEventListener 'click', doExportVisible
E('btn-nav-home').addEventListener 'click', doNavigateHome
window.addEventListener 'resize', updateCanvasSize
E('btn-nav-clear').addEventListener 'click', (e) -> navigator.clear()
E('btn-play-start').addEventListener 'click', doTogglePlayer
E('btn-play-stop').addEventListener 'click', doTogglePlayer

E('animate-set-start').addEventListener 'click', -> animator.setStart observer
E('animate-set-end').addEventListener 'click', -> animator.setEnd observer

E('animate-view-start').addEventListener 'click', -> animator.viewStart observer
E('animate-view-end').addEventListener 'click', -> animator.viewEnd observer

E('btn-upload-animation').addEventListener 'click', (e)->
  animator.animate observer, parseIntChecked(E('animate-frame-per-generation').value), parseIntChecked(E('animate-generations').value), (-> null)
E('btn-animate-cancel').addEventListener 'click', (e)->animator.cancelWork()

E('view-straighten').addEventListener 'click', (e)-> observer.straightenView()

E('view-straighten').addEventListener 'click', (e)-> observer.straightenView()
E('image-fix-size').addEventListener 'click', (e)-> doSetFixedSize E('image-fix-size').checked
E('image-size').addEventListener 'change', (e) ->
  E('image-fix-size').checked=true
  doSetFixedSize true
E('btn-mode-edit').addEventListener 'click', (e) -> doSetPanMode false
E('btn-mode-pan').addEventListener 'click', (e) -> doSetPanMode true
  
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
  'M': doMemorize
  'U': doRemember
  'UA': doClearMemory
  'H': doNavigateHome
  'HS': doStraightenView
  'G': doTogglePlayer
  'SA': (e) -> observer.straightenView()
  '#32': doTogglePlayer
  'P': (e) -> doSetPanMode true
  'E': (e) -> doSetPanMode false
  
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
    
##Application startup    
E('rule-entry').value = transitionFunc.toString()
doSetPanMode true
updatePopulation()
updateGeneration()
updateCanvasSize()
updateGrid()
updateMemoryButtons()
updatePlayButtons()
redrawLoop()
#redraw()
