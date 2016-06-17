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
  a: (pow) -> new NodeA pow, this
  b: (pow) -> new NodeB pow, this
  toString: -> showNode this
  ### Convert chain to array of pairs: [letter, power], where letter is "a" or "b" and power is integer.
  # Top element of the chain becomes first element of the array
  ###
  asStack: ->
    result = []
    node = this
    while node isnt unity
      result.push [node.letter, node.p]
      node = node.t
    return result
  
  #Append elements from the array to the chain.
  # First element of the array becomes top element of the chain;
  # stack itself becomes empty
  appendStack: (stack)->
    chain = this
    while stack.length > 0
      [e, p] = stack.pop()
      chain = newNode e, p, chain
    return chain
    
exports.unity = unity = new Node
unity.l = 0
unity.h = 0
unity.mtx = M.eye()
unity.repr = (g) -> @.mtx #jsut overload with a faster code.
  
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
    
chainEquals = chainEquals = (a, b) ->
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
    return 'e'
  parts = []
  while node isnt unity
    letter = node.letter
    power = node.p
    if power < 0
      letter = letter.toUpperCase()
      power = - power
    #Adding in reverse order!
    if power isnt 1
      parts.push "^#{power}"
    parts.push letter
    node = node.t
  return parts.reverse().join ''

#reverse of showNode
exports.parseNode = (s) ->
  return unity if s is '' or s is 'e'
  prepend = (tail) -> tail
  
  updPrepender = (prepender, letter, power) -> (tail) ->
    newNode letter, power, prepender tail
  
  while s
    match = s.match /([aAbB])(?:\^(\d+))?/
    throw new Error("Bad syntax: #{s}") unless match
    s = s.substr match[0].length
    letter = match[1]
    power = parseInt (match[2] ? '1'), 10
    letterLow = letter.toLowerCase()
    if letter isnt letterLow
      power = -power
    prepend = updPrepender prepend, letterLow, power
  prepend unity

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

### Convert chain to array of pairs: [letter, power], where letter is "a" or "b" and power is integer.
# Top element of the chain becomes first element of the array
###
#exports.node2array = node2array = (node) -> node.asStack()



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

#Inverse element of the chain
exports.inverseChain = (c, appendRewrite) -> appendInverseChain unity, c, appendRewrite

# appends c^-1 to a
exports.appendInverseChain = appendInverseChain = (a, c, appendRewrite) ->
  elementsWithPowers = c.asStack()
  elementsWithPowers.reverse()
  for e_p in elementsWithPowers
    e_p[1] *= -1
  appendRewrite a, elementsWithPowers


exports.appendChain = appendChain = (c1, c2, appendRewrite) ->
  appendRewrite c1, c2.asStack()  
