"use strict"
{Tessellation} = require "./hyperbolic_tessellation.coffee"
{NodeHashMap, nodeMatrixRepr, newNode, showNode, chainEquals, nodeHash} = require "./vondyck_chain.coffee"
{makeAppendRewrite, makeAppendRewriteRef, makeAppendRewriteVerified, vdRule, eliminateFinalA} = require "./vondyck_rewriter.coffee"
{RewriteRuleset, knuthBendix} = require "./knuth_bendix.coffee"
{mooreNeighborhood, evaluateTotalisticAutomaton, farNeighborhood} = require "./field.coffee"
{getCanvasCursorPosition} = require "./canvas_util.coffee"


M = require "./matrix3.coffee"

E = (id) -> document.getElementById id


colors = ["red", "green", "blue", "yellow", "cyan", "magenta", "gray", "orange"]


drawVisibleCells = (visibleCells, cells, viewMatrix, tessellation, context) ->
  context.fillStyle = "black"
  context.lineWidth = 1.0/400.0
  for cell in visibleCells
    mtx = M.mul viewMatrix, nodeMatrixRepr(cell, tessellation.group)
    tessellation.makeCellShapePoincare( mtx, context )
    if cells.get cell
      context.fill()
    else
      context.stroke()
  return      
  
drawCells = (cells, viewMatrix, tessellation, context) ->
  cells.forItems  (chain, value) ->
    #console.log "Drawing #{showNode chain}"
    mtx = M.mul viewMatrix, nodeMatrixRepr(chain, tessellation.group)
    #console.log "Matrix is #{JSON.stringify mtx}"
    h = nodeHash(chain)
    #console.log "node #{showNode chain}, hash = #{h}"
    context.fillStyle = colors[ ((h % colors.length) + colors.length) % colors.length]
    tessellation.makeCellShapePoincare( mtx, context )
    context.fill()

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
xyt2cell = (group, appendRewrite) -> 
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
    while true
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

tessellation = new Tessellation 7,3
console.log "Running knuth-bendix algorithm...."
rewriteRuleset = knuthBendix vdRule tessellation.group.n, tessellation.group.m
console.log "Finished"
appendRewrite = makeAppendRewrite rewriteRuleset

getNeighbors = mooreNeighborhood tessellation.group.n, tessellation.group.m, appendRewrite
xytFromCell = xyt2cell tessellation.group, appendRewrite

viewCenter = null
visibleCells = farNeighborhood viewCenter, 5, appendRewrite, tessellation.group.n, tessellation.group.m
console.log "Visible field contains #{visibleCells.length} cells"

transitionFunc = parseTransitionFunction "B 3 S 2 3", tessellation.group.n, tessellation.group.m

tfm = M.eye()
cells = new NodeHashMap
cells.put null, 1

doReset = ->
  cells = new NodeHashMap
  cells.put null, 1
  redraw()

doStep = ->
  cells = evaluateWithNeighbors cells, getNeighbors, transitionFunc
  redraw()

redraw = ->
  context.clearRect 0, 0, canvas.width, canvas.height
  context.save()
  s = Math.min( canvas.width, canvas.height ) / 2
  context.scale s, s
  context.translate 1, 1
  drawVisibleCells visibleCells, cells, tfm, tessellation, context
  context.restore()  
  console.log "Redraw. Population is #{cells.count}"
  E("population").innerHTML = ""+cells.count

doCanvasClick = (e) ->
  [x,y] = getCanvasCursorPosition e, canvas
  s = Math.min( canvas.width, canvas.height ) * 0.5
  xp = x/s - 1
  yp = y/s - 1
  xyt = poincare2hyperblic xp, yp
  if xyt is null
    #console.log "Outside of circle"
  else
    cell = xytFromCell xyt
    #console.log showNode cell
    if cells.get(cell) isnt null
      cells.remove cell
    else
      cells.put cell, 1
    redraw()
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
                  
  
redraw()
    
# ============ Bind Events =================
E("btn-reset").addEventListener "click", doReset
E("btn-step").addEventListener "click", doStep
E("canvas").addEventListener "mousedown", doCanvasClick
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
