{Tessellation} = require "./hyperbolic_tessellation.coffee"
{NodeHashMap, nodeMatrixRepr, newNode, showNode, chainEquals} = require "./vondyck_chain.coffee"
{makeAppendRewrite, makeAppendRewriteRef, makeAppendRewriteVerified, vdRule, eliminateFinalA} = require "./vondyck_rewriter.coffee"
{RewriteRuleset, knuthBendix} = require "./knuth_bendix.coffee"


M = require "./matrix3.coffee"

E = (id) -> document.getElementById id


colors = ["red", "green", "blue", "yellow", "cyan", "magenta", "gray", "orange"]


drawCells = (cells, viewMatrix, tessellation, context) ->
  iColor = 0
  cells.forItems  (chain, value) ->
    #console.log "Drawing #{showNode chain}"
    mtx = M.mul viewMatrix, nodeMatrixRepr(chain, tessellation.group)
    #console.log "Matrix is #{JSON.stringify mtx}"
    context.fillStyle = colors[iColor % colors.length]
    tessellation.makeCellShapePoincare( mtx, context )
    context.fill()
    iColor += 1

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

# ============================================  app code ===============
canvas = E "canvas"
context = canvas.getContext "2d"

tessellation = new Tessellation 3,7
console.log "Running knuth-bendix algorithm...."
rewriteRuleset = knuthBendix vdRule tessellation.group.n, tessellation.group.m
console.log "Finished"
appendRewrite = makeAppendRewrite rewriteRuleset

getNeighbors = mooreNeighborhood tessellation.group.n, tessellation.group.m, appendRewrite

tfm = M.eye()
cells = new NodeHashMap
cells.put null, 1

doReset = ->
  cells = new NodeHashMap
  cells.put null, 1
  redraw()

doStep = ->
  cells = evaluateWithNeighbors cells, getNeighbors, (state, sum)->
    if state is 0
      if sum in [1, 15]
        return 1
    else if state is 1
      if sum in [10]
        return 1
    return 0
  redraw()

redraw = ->
  context.clearRect 0, 0, canvas.width, canvas.height
  context.save()
  s = Math.min( canvas.width, canvas.height ) / 2
  context.scale s, s
  context.translate 1, 1
  drawCells cells, tfm, tessellation, context
  context.restore()
  
  console.log "Redraw. Population is #{cells.count}"

redraw()
    
# ============ Bind Events =================
E("btn-reset").addEventListener "click", doReset
E("btn-step").addEventListener "click", doStep


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
