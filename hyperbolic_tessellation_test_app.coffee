{Tessellation} = require "./hyperbolic_tessellation.coffee"
{NodeHashMap, nodeMatrixRepr, newNode, showNode, truncateA} = require "./vondyck_chain.coffee"
{makeAppendRewrite, vdRule} = require "./vondyck_rewriter.coffee"
{RewriteRuleset, knuthBendix} = require "./knuth_bendix.coffee"


M = require "./matrix3.coffee"

E = (id) -> document.getElementById id


colors = ["red", "green", "blue", "yellow", "cyan", "magenta", "gray", "orange"]


drawCells = (cells, viewMatrix, tessellation, context) ->
  iColor = 0
  cells.forItems  (chain, value) ->
    #console.log "Drawing #{showNode chain}, group os #{tessellation.group}"
    mtx = M.mul viewMatrix, nodeMatrixRepr(chain, tessellation.group)
    context.fillStyle = colors[iColor % colors.length]
    tessellation.makeCellShapePoincare( mtx, context )
    context.fill()
    iColor += 1

mooreNeighborhood = (chain, n, m, appendRewrite)->
  #reutrns Moore (vertex) neighborhood of the cell.
  # it contains N cells of von Neumann neighborhood
  #    and N*(M-3) cells, sharing single vertex.
  # In total, N*(M-2) cells.
  neighbors = []
  for powerA in [0...n] by 1
    for powerB in [1...m-1] by 1
      #adding truncateA to eliminate final rotation of the chain.
      neigh = truncateA appendRewrite chain, if powerA
            [['b', powerB], ['a', powerA]]
        else
            [['b', powerB]]
      neighbors.push neigh
  return neighbors


# ============================================  app code ===============
canvas = E "canvas"
context = canvas.getContext "2d"

tessellation = new Tessellation 5,4
console.log "Running knuth-bendix algorithm...."
rewriteRuleset = knuthBendix vdRule tessellation.group.n, tessellation.group.m
console.log "Finished"
console.log JSON.stringify rewriteRuleset
appendRewrite = makeAppendRewrite rewriteRuleset

tfm = M.eye()

cells = new NodeHashMap

coordsWithPaths = []

cell = null
for nei in mooreNeighborhood cell, tessellation.group.n, tessellation.group.m, appendRewrite
  for nei2 in mooreNeighborhood nei, tessellation.group.n, tessellation.group.m, appendRewrite
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
          paths.push nei2
          found = true
          break
      if not found
        console.log "First occurence of #{showNode nei2}"
        coordsWithPaths.push [cellCenter, [nei2]]
          

console.log "Population is #{cells.count}"    
  
#cells.put null, 1
#cells.put newNode('a', 1, newNode('b',1,null)), 1
#cells.put newNode('a', 1, newNode('b',1,newNode('a', 2, newNode('b',1,null)))), 1
                        

context.save()
s = Math.min( canvas.width, canvas.height ) / 2
context.scale s, s
context.translate 1, 1

drawCells cells, M.eye(), tessellation, context


context.restore()
