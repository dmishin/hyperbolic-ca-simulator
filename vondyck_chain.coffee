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
#  Root element is `unity`, it represens identity element of the group.
###  
M = require "./matrix3.coffee"

        
exports.Node = class Node
  hash: ->
    if (h = @h) isnt null
      h
    else
      #seen here: http://werxltd.com/wp/2010/05/13/javascript-implementation-of-javas-string-hashcode-method/
      h = @t.hash()
      @h = (((h<<5)-h) + (@letterCode<<7) + @p) | 0
  repr: (generatorMatrices) ->
      if (m = @mtx) isnt null
        m
      else
        @mtx = M.mul @t.repr(generatorMatrices), generatorMatrices.generatorPower(@letter, @p)
  equals: (c) -> chainEquals(this, c)
          
identityMatrix = M.eye()

exports.unity = unity = new Node
unity.l = 0
unity.h = 0
unity.mtx = M.eye()
unity.repr = (g) -> @.mtx #jsut reload with a faster code.
  
exports.NodeA = class NodeA extends Node
  letter: 'a'
  letterCode: 0
  constructor: (@p, @t)->
    @l = if @t is unity then 1 else @t.l+1
    @h = null
    @mtx = null #support for calculating matrix representations
    
exports.NodeB = class NodeB extends Node
  letter: 'b'
  letterCode: 1
  constructor: (@p, @t)->
    @l = if @t is unity then 1 else @t.l+1
    @h = null
    @mtx = null
    
exports.chainEquals = chainEquals = (a, b) ->
  while true
    return true if a is b 
    if a is unity or b is unity
      return false #a is E and b is E, but not both
      
    if (a.letter isnt b.letter) or (a.p isnt b.p)
      return false
    a = a.t
    b = b.t


showNode = exports.showNode = (node) ->
  if node is unity
    'e'
  else
    showNode(node.t) + node.letter + (if node.p is 1 then '' else "^#{node.p}")


exports.truncateA = truncateA = (chain)->
  while (chain isnt unity) and (chain.letter is "a")
    chain = chain.t
  return chain
  
exports.truncateB = truncateB = (chain)->
  while (chain isnt unity) and (chain.letter is "b")
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
  while node isnt unity
    result.push [node.letter, node.p]
    node = node.t
  return result



exports.nodeMatrixRepr = nodeMatrixRepr = (node, generatorMatrices) -> node.repr(generatorMatrices)
    


# Hash function of the node
#
exports.nodeHash = nodeHash = (node) -> node.hash()
exports.chainLen = chainLen = (chain)-> chain.l
    
###
# Reverse compare 2 chains by shortlex algorithm
###
exports.reverseShortlexLess = reverseShortlexLess = (c1, c2) ->
  if c1 is unity
    return c2 isnt unity
  else
    #c1 not unity
    if c2 is unity
      return false
    else
      #neither is unity
      if c1.l isnt c2.l
        return c1.l < c2.l
      #both are equal length
      while c1 isnt unity
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

  _index: (chain) -> chain.hash() & @sizeMask
    
  putAccumulate: (chain, value, accumulateFunc)->
    cell = @table[@_index chain]

    for key_value in cell
      if chainEquals(key_value[0], chain)
        #Update existing value
        key_value[1] = accumulateFunc key_value[1], value
        return
        
    cell.push [chain, value]
    @count += 1
    if @count > @maxFillRatio*@table.length
      @_growTable()
    return this
          
  put: (chain, value) -> @putAccumulate chain, value, (x,y)->y

  get: (chain) ->
    # console.log "geting for #{showNode chain}"
    for key_value in @table[@_index chain]
      if chainEquals key_value[0], chain
        #console.log "   found something"
        return key_value[1]
    #console.log "   not found"
    return null
    
  remove: (chain) ->
    tableCell = @table[@_index chain]
    for key_value, index in tableCell
      if chainEquals key_value[0], chain
        tableCell.splice index, 1
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

  copy: ->
    copied = new NodeHashMap 1 #minimal size

    copied.count = @count
    copied.maxFillRatio = @maxFillRatio
    copied.sizeMask = @sizeMask
    
    copied.table = for cell in @table
      for key_value in cell
        key_value[..]

    return copied
  

#Inverse element of the chain
exports.inverseChain = inverseChain = (c, appendRewrite) ->
  elementsWithPowers = node2array c
  elementsWithPowers.reverse()
  for e_p in elementsWithPowers
    e_p[1] *= -1
  appendRewrite unity, elementsWithPowers

exports.appendChain = appendChain = (c1, c2, appendRewrite) ->
  appendRewrite c1, node2array(c2)  