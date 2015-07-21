### Implementation of values of von Dyck groups.
#  Each value is a chain of powers of 2 generators: A and B
#
#  Example:
#    x = a*b*a-1*b^2*a*b-3
#
#  vD groups have additional relations for generators:
#   a^n === b^m === (ab)^k,
#  however this implementation is agnostic about these details.
#  They are implemented by the js_rewriter module.
#
#  (To this module actually implements free group of 2 generators...)
#
#  To facilitate chain appending/truncating, theyt are implemented as a functional data structure.
#  Root element is null, it represens identity element of the group.
###  
M = require "./matrix3.coffee"
    
exports.Node = class Node
  hash: ->
    h = @h
    if h isnt null
      h
    else
      #seen here: http://werxltd.com/wp/2010/05/13/javascript-implementation-of-javas-string-hashcode-method/
      h = nodeHash @t
      @h = (((h<<5)-h) + (@letterCode<<7) + @p) | 0
      
  
exports.NodeA = class NodeA extends Node
  letter: 'a'
  letterCode: 0
  constructor: (@p, @t)->
    @l = if @t is null then 1 else @t.l+1
    @h = null
    @mtx = null #support for calculating matrix representations
    
exports.NodeB = class NodeB extends Node
  letter: 'b'
  letterCode: 1
  constructor: (@p, @t)->
    @l = if @t is null then 1 else @t.l+1
    @h = null
    @mtx = null
    
exports.chainEquals = chainEquals = (a, b) ->
  if a is null or b is null
    a is null and b is null
  else
    a.letter is b.letter and a.p is b.p and chainEquals(a.t, b.t)


showNode = exports.showNode = (node) ->
  if node is null
    ''
  else
    showNode(node.t) + node.letter + (if node.p is 1 then '' else "^#{node.p}")


exports.truncateA = truncateA = (chain)->
  while (chain isnt null) and (chain.letter is "a")
    chain = chain.t
  return chain
  
exports.truncateB = truncateB = (chain)->
  while (chain isnt null) and (chain.letter is "b")
    chain = chain.t
  return chain
  

exports.nodeConstructors = nodeConstructors = 
  a: NodeA
  b: NodeB

exports.newNode = newNode = (letter, power, parent) ->
  new nodeConstructors[letter](power, parent)

#Append elements from the array to the chain.
# First element of the array becomes top element of the chain;
# stack itself becomes empty
exports.appendSimple = appendSimple = (chain, stack) ->
  while stack.length > 0
    [e, p] = stack.pop()
    chain = newNode(e, p, chain)
  return chain

### Convert chain to array of pairs: [letter, power], where letter is "a" or "b" and power is integer.
# Top element of the chain becomes first element of the array
###
exports.node2array = node2array = (node) ->
  result = []
  while node isnt null
    result.push [node.letter, node.p]
    node = node.t
  return result


identityMatrix = M.eye()

exports.nodeMatrixRepr = nodeMatrixRepr = (node, generatorMatrices) ->
  if node is null
    identityMatrix
  else
    m = node.mtx
    if m isnt null
      m
    else
      node.mtx = M.mul nodeMatrixRepr(node.t, generatorMatrices), generatorMatrices.generatorPower(node.letter, node.p)
    


### Hash function of the node
####
exports.nodeHash = nodeHash = (node) ->
  if node is null
    0
  else
    node.hash()

### Reverse compare 2 chains by shortlex algorithm
###
exports.reverseShortlexLess = reverseShortlexLess = (c1, c2) ->
  if c1 is null
    return c2 isnt null
  else
    #c1 not null
    if c2 is null
      return false
    else
      #neither is null
      if c1.l isnt c2.l
        return c1.l < c2.l
      #both are equal length
      while c1 isnt null
        if c1.letter isnt c2.letter
          return c1.letter < c2.letter
        if c1.p isnt c2.p
          return c1.p < c2.p
        #go upper
        c1 = c1.t
        c2 = c2.t
      #exactly equal
      return false

#Hash map that uses chain as key
exports.NodeHashMap = class NodeHashMap
  constructor: (initialSize = 16) ->
    #table size MUST be power of 2! Or else write your own implementation of % that works with negative hashes.
    if initialSize & (initialSize-1) isnt 0 #this trick works!
      throw new Error "size must be power of 2"
    @table = ([] for i in [0...initialSize] by 1)
    @count = 0
    @maxFillRatio = 0.7
    
    @sizeMask = initialSize - 1
      
  putAccumulate: (chain, value, accumulateFunc)->
    idx = nodeHash(chain) & @sizeMask
    cell = @table[idx]

    for key_value in cell
      if chainEquals(key_value[0], chain)
        #Update existing value
        key_value[1] = accumulateFunc key_value[1], value
        return
        
    #console.log "##Adding new #{showNode chain} to #{value}, index is #{idx}"
    cell.push [chain, value]
    @count += 1
    if @count > @maxFillRatio*@table.length
      @_growTable()
    return this
        
  put: (chain, value) -> @putAccumulate chain, value, (x,y)->y
    
  get: (chain) ->
    idx = nodeHash(chain) & @sizeMask
    # console.log "geting for #{showNode chain}"
    for key_value in @table[idx]
      if chainEquals key_value[0], chain
        #console.log "   found something"
        return key_value[1]
    #console.log "   not found"
    return null
    
  remove: (chain) ->
    idx = nodeHash(chain) & @sizeMask
    for key_value, index in @table[idx]
      if chainEquals key_value[0], chain
        @table.splice(index,1)
        @count -= 1
        return true
    return false
    
  _growTable: ->
    newTable = new NodeHashMap (@table.length * 2)
    #console.log "Growing table to #{newTable.table.length}"
    for cell in @table
      for [key, value] in cell
        newTable.put key, value
    @table = newTable.table
    @sizeMask = newTable.sizeMask
    return
    
  forItems: (callback) ->
    for cell in @table
      for [key, value] in cell
        callback key, value
    return    
    
    
  
