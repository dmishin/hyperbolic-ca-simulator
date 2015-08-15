#{Tessellation} = require "./hyperbolic_tessellation.coffee"
{unity, NodeHashMap, newNode, showNode, node2array} = require "./vondyck_chain.coffee"
{makeAppendRewrite, eliminateFinalA} = require "./vondyck_rewriter.coffee"
#{RewriteRuleset, knuthBendix} = require "./knuth_bendix.coffee"

#High-level utils for working with hyperbolic cellular fields



exports.mooreNeighborhood = mooreNeighborhood = (n, m, appendRewrite)->(chain)->
  #reutrns Moore (vertex) neighborhood of the cell.
  # it contains N cells of von Neumann neighborhood
  #    and N*(M-3) cells, sharing single vertex.
  # In total, N*(M-2) cells.
  neighbors = new Array(n*(m-2))
  i = 0
  for powerA in [0...n] by 1
    for powerB in [1...m-1] by 1
      #adding truncateA to eliminate final rotation of the chain.
      nStep = if powerA
            [['b', powerB], ['a', powerA]]
        else
            [['b', powerB]]
      neigh = eliminateFinalA appendRewrite(chain, nStep), appendRewrite, n
      neighbors[i] = neigh
      i += 1
  return neighbors


exports.neighborsSum = neighborsSum = (cells, getNeighbors)->
  sums = new NodeHashMap
  plus = (x,y)->x+y
  cells.forItems (cell, value)->
    for neighbor in getNeighbors cell
      sums.putAccumulate neighbor, value, plus
  return sums

exports.evaluateTotalisticAutomaton = evaluateTotalisticAutomaton = (cells, getNeighborhood, nextStateFunc)->
  newCells = new NodeHashMap
  sums = neighborsSum cells, getNeighborhood
  
  sums.forItems (cell, neighSum)->
    #console.log "#{showNode cell}, sum=#{neighSum}"
    cellState = cells.get(cell) ? 0
    nextState = nextStateFunc cellState, neighSum
    if nextState isnt 0
      newCells.put cell, nextState
  return newCells


# r - radius
# appendRewrite: rewriter for chains.
# n,m - parameters of the tessellation
# Return value:
#  list of chains to append
exports.farNeighborhood = farNeighborhood = (center, r, appendRewrite, n, m) ->
  cells = new NodeHashMap
  cells.put center, true
  getNeighbors = mooreNeighborhood n, m, appendRewrite
  getCellList = (cells) ->
    cellList = []
    cells.forItems (cell, state) ->
      cellList.push cell
    return cellList

  for i in [0...r] by 1
    for cell in getCellList cells
      for nei in getNeighbors cell
        cells.put nei, true

  getCellList cells  


exports.extractClusterAt = extractClusterAt = (cells, getNeighbors, chain) ->
  #use cycle instead of recursion in order to avoid possible stack overflow.
  #Clusters may be big.
  stack = [chain]
  cluster = []
  while stack.length > 0
    c = stack.pop()
    continue if cells.get(c) is null
    
    cells.remove c
    cluster.push c
    
    for neighbor in getNeighbors c
      if cells.get(neighbor) isnt null
        stack.push neighbor
  return cluster
  
exports.allClusters = (cells, n, m, appendRewrite) ->
  cellsCopy = cells.copy()
  clusters = []
  getNeighbors = mooreNeighborhood n, m, appendRewrite
    
  cells.forItems (chain, value) ->
    if cellsCopy.get(chain) isnt null
      clusters.push extractClusterAt(cellsCopy, getNeighbors, chain)

  return clusters      
  

#Generate JS object from this field.
# object tries to efectively store states of the field cells in the tree.
# Position of echa cell is represented by chain.
# Chains can be long; for nearby chains, their tails are the same.
# Storing chains in list would cause duplication of repeating tails.
#
# Object structure:
# {
#   g: 'a' or 'b', name of the group generator. Not present in root!
#   p: integer, power of the generator. Not present in root!
#   [v:] value of the cell. Optional.
#   [cs]: [children] array of child trees
# }
exports.exportField = (cells) ->
  root = {
  }
  chain2treeNode = new NodeHashMap
  chain2treeNode.put unity, root
  
  putChain = (chain) -> #returns tree node for that chain
    node = chain2treeNode.get chain
    if node is null
      parentNode = putChain chain.t
      node = {}
      node[chain.letter] = chain.p
      if parentNode.cs?
        parentNode.cs.push node
      else
        parentNode.cs = [node]
      chain2treeNode.put chain, node
    return node
  cells.forItems (chain, value) ->
    putChain(chain).v = value

  return root

exports.importField = (fieldData, cells = new NodeHashMap)->
  putNode = (rootChain, rootNode)->
    if rootNode.v?
      #node is a cell that stores some value?
      cells.put rootChain, rootNode.v
    if rootNode.cs?
      for childNode in rootNode.cs
        if childNode.a?
          putNode(newNode('a', childNode.a, rootChain), childNode)
        else if childNode.b?
          putNode(newNode('b', childNode.b, rootChain), childNode)
        else
          throw new Error "Node has neither A nor B generator"
    return
  putNode unity, fieldData
  return cells
      
exports.randomFill = (field, density, center, r, appendRewrite, n, m) ->
  if density < 0 or density > 1.0
    throw new Error "Density must be in [0;1]"
    
  for cell in farNeighborhood center, r, appendRewrite, n, m
    if Math.random() < density
      field.put cell, 1
  return
      
  
