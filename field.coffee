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


exports.neighborsSum = neighborsSum = (cells, getNeighbors, plus=((x,y)->x+y), plusInitial=0)->
  sums = new NodeHashMap
  cells.forItems (cell, value)->
    for neighbor in getNeighbors cell
      sums.putAccumulate neighbor, value, plus, plusInitial
    #don't forget the cell itself! It must also present, with zero (initial) neighbor sum
    if sums.get(cell) is null
      sums.put(cell, plusInitial)
  return sums

exports.evaluateTotalisticAutomaton = evaluateTotalisticAutomaton = (cells, getNeighborhood, nextStateFunc, plus, plusInitial)->
  newCells = new NodeHashMap
  sums = neighborsSum cells, getNeighborhood, plus, plusInitial
  sums.forItems (cell, neighSum)->
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


exports.importFieldTo = importFieldTo = (fieldData, callback) ->
  putNode = (rootChain, rootNode)->
    if rootNode.v?
      #node is a cell that stores some value?
      callback rootChain, rootNode.v
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
    
exports.importField = (fieldData, cells = new NodeHashMap)->
  importFieldTo fieldData, (chain, value) ->
    cells.put chain, value
  return cells

#Generate random value in range from 1 to nStates-1
exports.randomStateGenerator = (nStates) -> ->
  (Math.floor(Math.random()*(nStates-1))|0) + 1
  
exports.randomFill = (field, density, center, r, appendRewrite, n, m, randomState ) ->
  if density < 0 or density > 1.0
    throw new Error "Density must be in [0;1]"
  #by default, fill with ones.    
  randomState = randomState ? -> 1
    
  for cell in farNeighborhood center, r, appendRewrite, n, m
    if Math.random() < density
      field.put cell, randomState()
  return
      
  

exports.stringifyFieldData = (data) ->
  parts = []
  doStringify = (data)->
    if data.v?
      parts.push "|"+data.v
    if data.cs?
      for child in data.cs
        parts.push '('
        if child.a?
          gen = 'a'
          pow = child.a
        else if child.b?
          gen = 'b'
          pow = child.b
          #parts.push "b#{child.b}"
        else throw new Error "bad data, neither a nor b"
        if pow < 0
          gen = gen.toUpperCase()
          pow = -pow
        parts.push gen
        parts.push "#{pow}" if pow isnt 1
        
        doStringify child
        parts.push ')'
  doStringify(data)
  return parts.join ""

#Parse what stringifyFieldData returns.
# Produce object, suitable for importField
exports.parseFieldData = (text) ->
  integer = (text, pos) ->
    #console.log "parsing from #{pos}: '#{text}'"
    sign = 1
    value = ''
    getResult = ->
      if value is ''
        return null
      else
        v = sign * parseInt(value, 10)
        #console.log "parsed int: #{v}"
        return [v, pos]

    while true
      if pos >= text.length
        return getResult()
      c = text[pos]
      if c is '-'
        sign = -sign
      else if c >= '0' and c <= '9'
        value += c
      else
        return getResult()
      pos += 1
    return
    
  skipSpaces = (text, pos) ->
    while pos < text.length and text[pos] in [' ','\t','\r','\n']
      pos += 1
    return pos

  awaitChar = (char, text, pos) ->
    pos = skipSpaces text, pos
    return null if pos >= text.length
    c = text[pos]
    pos += 1
    return null if c isnt char
    return pos
    
  parseChildSpec = (text, pos) ->

    #parse
    pos = awaitChar '(', text, pos
    return null if pos is null

    #parse generator name...
    pos = skipSpaces text, pos
    return null if pos >= text.length
    gen = text[pos]
    pos += 1
    return null unless gen in ['a','b','A','B']
    genLower = gen.toLowerCase()
    powerSign = if genLower is gen then 1 else -1
    gen = genLower
    
    #parse generaotr power
    pos = skipSpaces text, pos
    powerRes = integer text, pos
    if powerRes is null
      power = 1
    else
      [power, pos] = powerRes
    power *= powerSign

    #parse cell state and children
    pos = skipSpaces text, pos
    valueRes = parseValueSpec text, pos
    return null if valueRes is null
    [value, pos] = valueRes
    
    #store previously parsed generator and power
    value[gen] = power
    #console.log "Value updated with generator data, waiting for ) from #{pos}, '#{text.substring(pos)}'"

  
    pos = skipSpaces text, pos
    pos = awaitChar ')', text, pos
    return null if pos is null

    #ok, parsed child fine!
    #console.log "parsed child OK"
    return [value, pos]
    
    
  parseValueSpec = (text, pos) ->
    value = {}
    pos = skipSpaces text, pos

    pos1 = awaitChar '|', text, pos
    if pos1 isnt null
      #has value
      pos = pos1
      intResult = integer(text, pos)
      if intResult isnt null
        [value.v, pos] = intResult
    #parse children
    children = []
    #console.log "parsing children from from #{pos}, '#{text.substring(pos)}'"
    while true
      childRes = parseChildSpec text, pos
      if childRes is null
        #console.log "no more children..."
        break
      children.push childRes[0]
      pos = childRes[1]
    #console.log "parsed #{children.length} children"
    if children.length > 0
      value.cs = children
    return [value, pos]
  #finally, parse all
  allRes = parseValueSpec text, 0
  if allRes is null
    throw new Error "Faield to parse!"
  pos = allRes[1]
  pos = skipSpaces text, pos
  if pos isnt text.length
    throw new Error "garbage after end"
  return allRes[0]

###        
"""
exports.parseFieldData1 = (data) ->
  #data format (separators not included) is:
  #
  # text ::= value_spec
  # value_spec ::= [value]? ( '(' child_spec ')' )*
  # value ::= integer
  # child_spec ::= generator power value_spec
  # generator ::= a | b
  # power ::= integer
  #
  #

  #parser returns either null or pair:
  #  (parse result, next position)
  #
  # optional combinator
  # parse result is value of the inner parser or null
  # always succeeds
  #
  optional = (parser) -> (text, start) ->
    parsed = parser(text, start)
    if parsed is null
      [null, start]
    else
      parsed


  literal = (lit) -> (text, pos) ->
    for lit_i, i in lit
      if pos+i >= text.length
        return null
      if text[pos+i] isnt lit_i
        return null
    return [lit, pos+lit.length]

  oneOf = (parsers...) -> (text, pos) ->
    for p in parsers
      res = p(text,pos)
      return res if res isnt null
    return null
    
  word = (allowedChars) ->
    charSet = {}
    for c in allowedChars
      charSet[c] = true
    return (text, start) ->
      parseResult = ""
      pos = start
      while pos < text.length
        c = text[pos]
        if charSet.hasOwnProperty c
          parseResult += c
          pos += 1
        else
          break
      if parseResult is ""
        null
      else

  seq = (parsers) -> (text, pos) ->
    results = []
    for p in parsers
      r = p(text, pos)
      if r isnt null
        results.push r
        pos = r[1]
      else
        return null
    return [results, pos]
    
  map = (parser, func) -> (text, pos) ->
    r = parser(text, pos)
    return null if r is null
    return [func(r[0]), r[1]]
    
  integer = seq( optional(literal('-')), word('123456789')
  integer = map( parseInteger, [sign, digits]->
    parseInt((sign or '')+digits, 10) )

    
    
  parseInteger = (text, start) ->
    hasSign = false
    """
###    
