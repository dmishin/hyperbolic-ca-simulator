{parseIntChecked} = require "./utils.coffee"


class BaseFunc
  plus: (x,y) -> x+y
  plusInitial: 0
  setGeneration: (g)->
    
exports.GenericTransitionFunc = class GenericTransitionFunc extends BaseFunc
  constructor: ( @numStates, @plus, @plusInitial, @evaluate ) ->
    if @numStates <= 0 then throw new Error "Number if states incorrect"
    @generation = 0
  toString: -> "GenericFunction( #{@numStates} states )"
  isStable: -> @evaluate(0,0) is 0
  setGeneration: (g) -> @generation = g
  getType: -> "custom"  

#DayNight functions are those, who transform empty field to filled and back.
# They can be effectively simulated as a pair of 2 rules, applying one rule for even generations and another for odd.

isDayNightRule = (binaryFunc)->
  binaryFunc.evaluate(0,0) == 1 and binaryFunc.evaluate(1, binaryFunc.numNeighbors) == 0
   
exports.DayNightTransitionFunc = class DayNightTransitionFunc extends BaseFunc
  constructor: (@base) ->
    throw new Error("base function is not flashing") if not isDayNightRule @base
    @phase = 0
    
  toString: -> @base.toString()
  numStates: 2
  getType: -> "binary"
  
  setGeneration: (g)->
    @phase = g & 1

  isStable: ->
    @base.evaluate(0,0) is 1 and @base.evaluate(1,@base.numNeighbors) is 0
    
  evaluate: (x, s) ->
    if @phase
      1 - @base.evaluate(x,s)
    else
      @base.evaluate(1-x, @base.numNeighbors-s)

exports.BinaryTransitionFunc = class BinaryTransitionFunc extends BaseFunc
  constructor: ( @n, @m, bornAt, stayAt ) ->
    @numNeighbors = @n*(@m-2)
    @table = for arr in [bornAt, stayAt]
      for s in [0 .. @numNeighbors] by 1
        if s in arr then 1 else 0
          
  isStable: -> table[0][0] is 0
  
  plus: (x,y) -> x+y
  plusInitial: 0
  numStates: 2
  getType: -> "binary"  
  
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
exports.parseTransitionFunction = (str, n, m, allowDayNight=true) ->
  match = str.match /B([\d\s]+)S([\d\s]+)/
  throw new Error("Bad function string: #{str}") unless match?
    
  strings2array = (s)->
    for part in s.split ' ' when part
      parseIntChecked part

  bArray = strings2array match[1]
  sArray = strings2array match[2]
  func = new BinaryTransitionFunc n, m, bArray, sArray

  #If allowed, convert function to day/night rule
  if allowDayNight and isDayNightRule func
    new DayNightTransitionFunc func
  else
    func


exports.binaryTransitionFunc2GenericCode = (binTf) ->
  row2condition = (row) -> ("s===#{sum}" for nextValue, sum in row when nextValue).join(" || ")
  
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
    //this.generation stores current generation number
    'next': function(x, s){
        if (x===1 && (#{conditionStay})) return 1;
        if (x===0 && (#{conditionBorn})) return 1;
        return 0;
     }
}"""]


exports.dayNightBinaryTransitionFunc2GenericCode = (binTf) ->
  row2condition = (row) -> ("s===#{sum}" for nextValue, sum in row when nextValue).join(" || ")
  row2conditionInv = (row) -> ("s===#{binTf.base.numNeighbors-sum}" for nextValue, sum in row when nextValue).join(" || ")
  
  conditionBorn = row2condition binTf.base.table[0]
  conditionStay = row2condition binTf.base.table[1]
  conditionBornInv = row2conditionInv binTf.base.table[0]
  conditionStayInv = row2conditionInv binTf.base.table[1]
  
  code = ["""//Automatically generated code for population-inverting binary rule #{binTf}
{
    //number of states
    'states': 2,

    //Neighbors sum calculation is default. Code for reference.
    //'plus': function(s,x){ return s+x; },
    //'plusInitial': 0,
    
    //Transition function. Takes current state and sum, returns new state.
    'next': function(x, s){
        var phase = this.generation & 1;

        //The original rule #{binTf} inverts state of an empty field
        //To calculate it efficiently, we instead invert each odd generation, so that population never goes to infinity.
        
        
        if (phase === 0){
            //On even generations, invert output
            if (x===1 && (#{conditionStay})) return 0;
            if (x===0 && (#{conditionBorn})) return 0;
            return 1
        } else {
            //On odd generations, invert input state and nighbors sum
            if (x===0 && (#{conditionStayInv})) return 1;
            if (x===1 && (#{conditionBornInv})) return 1;
            return 0;
        }
     }
}"""]

