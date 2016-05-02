{parseIntChecked} = require "./utils.coffee"


exports.GenericTransitionFunc = class GenericTransitionFunc
  constructor: ( @numStates, @plus, @plusInitial, @evaluate ) ->
    if @numStates <= 0 then throw new Error "Number if states incorrect"
  toString: -> "GenericFunction( #{@numStates} states )"
  isStable: -> @evaluate(0,0) is 0
  
exports.BinaryTransitionFunc = class BinaryTransitionFunc
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
exports.parseGenericTransitionFunction = (str) ->
  tfObject = eval('('+str+')')
  throw new Error("Numer of states not specified") unless tfObject.states?
  throw new Error("Transition function not specified") unless tfObject.next?
  
  #@numStates, @plus, @plusInitial, @evaluate )
  return new GenericTransitionFunc tfObject.states, (tfObject.sum ? ((x,y)->x+y)), (tfObject.sumInitial ? 0), tfObject.next

# BxxxSxxx
exports.parseTransitionFunction = (str, n, m) ->
  match = str.match /B([\d\s]+)S([\d\s]+)/
  throw new Error("Bad function string: #{str}") unless match?
    
  strings2array = (s)->
    for part in s.split ' ' when part
      parseIntChecked part

  bArray = strings2array match[1]
  sArray = strings2array match[2]
  return new BinaryTransitionFunc n, m, bArray, sArray


exports.binaryTransitionFunc2GenericCode = (binTf) ->
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

