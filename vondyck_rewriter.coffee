#Generates JS code that effectively rewrites
{RewriteRuleset}= require "./knuth_bendix.coffee"
{unity, NodeA, NodeB, chainEquals, appendSimple, nodeConstructors, newNode, reverseShortlexLess, showNode, node2array} = require "./vondyck_chain.coffee"

collectPowers = ( elemsWithPowers )->
    ### List (elem, power::int) -> List (elem, power::int)
    ###
    grouped = []
    for [elem, power] in elemsWithPowers
        if grouped.length is 0
            grouped.push( [elem, power] )
        else if grouped[grouped.length-1][0] is elem
            newPower = grouped[grouped.length-1][1] + power
            if newPower isnt 0
                grouped[grouped.length-1][1] = newPower
            else
                grouped.pop()
        else
            grouped.push( [elem, power] )
    return grouped

exports.groupByPower = groupByPower = (s)->
    last = null
    lastPow = null
    result = []
    for i in [0...s.length]
        x = s[i]
        if last is null
            last = x
            lastPow = 1
        else
            if x is last
                lastPow += 1
            else
                result.push [last, lastPow]
                last = x
                lastPow = 1
    if last isnt null
        result.push [last, lastPow]
    return result

#collect powers, assuming convention that uppercase letters degignate negative powers
exports.groupPowersVd = groupPowersVd = (s)->
    for [x, p] in groupByPower(s)
        if x.toUpperCase() is x
            [x.toLowerCase(), -p]
        else
            [x, p]

###
#Every string is a sequence of powers of 2 operators: A and B.
#powers are limited to be in range -n/2 ... n/2 and -m/2 ... m/2
#
#
#rewrite rules work on these pow cahins:
#
#
#Trivial rewrites:
#   a^-1 a       -> e
#   b^-1 b       -> e
#   a a^-1       -> e
#   b b^-1       -> e
#
#Power modulo rewrites.
#   b^2  -> b^-2
#   b^-3 -> b
#   #allower powers: -2, -1, 1
#   #rewrite rule: (p + 2)%4-2
#
#   a^2  -> a^-2
#   a^-3 -> a
#   #allower powers: -2, -1, 1
#   #rewrite rule: (p+2)%4-2
#
#Non-trivial rewrites
# Ending with b
#   a b  -> b^-1 a^-1
#   b^-1 a^-1 b^-1       -> a       *
#   a b^-2       -> b^-1 a^-1 b     *
#   b a^-1 b^-1  -> b^-2 a          *
#
# Ending with a
#   b a  -> a^-1 b^-1
#   a^-1 b^-1 a^-1       -> b       *
#   a b^-1 a^-1  -> a^-2 b          *
#   b a^-2       -> a^-1 b^-1 a     *
#
#
#As a tree, sorted in reverse order. Element in square braces is "eraser" for the last element in the matching pattern.
#
#- Root B
#  - b^-2   
#    - a       REW: [a^-1] b^-1 a^-1 b
#  - b^-1
#    - a^-1
#       - b    REW: [b^-1] b^-2 a
#       - b^-1 REW: [b] a
#  - b
#    - a       REW: [a^-1] b^-1 a^-1
#
#- Root A
#  - a^-2 
#    - b       REW: [b^-1] a^-1 b^-1 a
#  - a^-1
#    - b^-1
#       - a    REW: [a^-1] a^-2 b
#       - a^-1 REW: [a] b
#  - a
#    - b       REW: [b^-1] a^-1 b^-1
#   
#Idea: 2 rewriters. For chains ending with A and with B.
#Chains are made in functional style, stored from end. 
#
#
#See sample_rewriter.js for working code.
#    
###

otherElem = (e) -> {'a':'b', 'b':'a'}[e]

mod = (x,y) -> (x%y+y)%y

exports.JsCodeGenerator = class JsCodeGenerator
    constructor: ( debug=false, pretty=false )->
        @out = []
        @ident = 0
        @debug = debug
        @pretty = pretty
    get: ->
      if @ident isnt 0
        throw new RuntimeError "Attempt to get generated code while not finished"
      code = @out.join ""
      @reset()
      return code
    reset: -> @out = []
    line: ( text)->
        if not @debug and text.match /^console\.log/
          return
        
        if not @pretty and text.match /^\/\//
            return
        
        if @pretty or text.match(/\/\//)
          for i in [0...@ident]
            @out.push "    "
            
        @out.push(text)
        @out.push(if @pretty then "\n" else " ")
    if_: ( conditionText ) -> @line "if(#{conditionText})"
    op: (expressionText) -> @line "#{expressionText};"
    
    block: (callback)->
        @line("{")
        @ident += 1
        callback()
        @ident -= 1
        @line("}")

exports.CodeGenerator = class CodeGenerator extends JsCodeGenerator
    constructor: ( rewriteTable, out, debug=false, pretty=false )->
        super debug, pretty

        powerRewrites = powerRewriteRules rewriteTable

        rangeA = elementPowerRange(powerRewrites, 'a')
        rangeB = elementPowerRange(powerRewrites, 'b')
        
        @minPower =
          'a': rangeA[0]
          'b': rangeB[0]
        @elementOrder =
          'a': elementOrder powerRewrites, 'a'
          'b': elementOrder powerRewrites, 'b'
          
        #extend rewrite table with new rules
        rewriteTable = rewriteTable.copy()
        extendLastPowerRewriteTable rewriteTable, 'a', rangeA[0], rangeA[1]
        extendLastPowerRewriteTable rewriteTable, 'b', rangeB[0], rangeB[1]
        
        @rewriteTable = rewriteTable
        @suffixTree = reverseSuffixTable(rewriteTable)

    generateAppendRewriteOnce: ->
        @line("(function(chain, stack )")
        @block =>
            @line "if (stack.length === 0) {throw new Error('empty stack');}"
            @op("var _e = stack.pop(), element = _e[0], power = _e[1]")
            @line("if (chain === unity)")
            @block =>
                @line("//empty chain")
                @line('console.log("Append to empth chain:"+_e);');
                @line("var order=(element==='a')?#{@elementOrder['a']}:#{@elementOrder['b']};")
                @line("var lowestPow=(element==='a')?#{@minPower['a']}:#{@minPower['b']};")
                @line('chain = newNode( element, mod(power-lowestPow, order)+lowestPow, chain);')
            @line 'else'
            @block =>
              @generateMain()
            @line("return chain;")
        @line(")")
        return @get()
                
    generateMain: ->
        @line('if (chain.letter==="a")')
        @block =>
            @line('console.log("Append "+JSON.stringify(_e)+" to chain ending with A:"+showNode(chain));')
            @generatePowerAccumulation("a")
            @generateRewriterFrom("b")
            
        @line('else if (chain.letter==="b")')
        @block =>
            @line('console.log("Append "+JSON.stringify(_e)+" to chain ending with B:"+showNode(chain));')
            @generatePowerAccumulation("b")
            @generateRewriterFrom("a")
            
        @line('else throw new Error("Chain neither a nor b?");')

    generatePowerAccumulation: ( letter)->
        @line("if (element === \"#{letter}\")")
        @block =>
            @line( "console.log(\"    element is #{letter}\");")
            lowestPow = @minPower[letter]
            order = @elementOrder[letter]
            @line( "var newPower = ((chain.p + power - #{lowestPow})%#{order}+#{order})%#{order}+#{lowestPow};")
            
            @line "chain = chain.t;"
            
            @line('if (newPower !== 0)')
            @block =>
                nodeClass=@_nodeClass(letter) 
                @line('console.log("    new power is "+newPower);')
                #and append modified power to the stack
                @line "stack.push(['#{letter}', newPower]);"
            if @debug
              @line('else')
              @block =>
                @line( 'console.log("      power reduced to 0, new chain="+showNode(chain));')
                
    generateRewriterFrom: ( newElement)->
        ###Generate rewriters, when `newElement` is added, and it is not the same as the last element of the chain###
        @line("else")
        @block =>
            @line("//Non-trivial rewrites, when new element is #{newElement}")
            nodeConstructor=@_nodeClass(newElement)
            o = @elementOrder[newElement]
            mo = @minPower[newElement]
            @line("chain = new #{nodeConstructor}((((power - #{mo})%#{o}+#{o})%#{o}+#{mo}), chain);")            
            @generateRewriteBySuffixTree(newElement, @suffixTree, 'chain')
            
    generateRewriteBySuffixTree: ( newElement, suffixTree, chain)->

        first = true
        for e_p_str, subTable of suffixTree
            e_p = JSON.parse e_p_str
            @line "// e_p = #{JSON.stringify e_p}"
            [elem, elemPower] = e_p
            if elem isnt newElement
              continue
            
            if not first
                @line("else")
            else
                first = false
            isLeaf = subTable["rewrite"]?
            if isLeaf
                compOperator = if elemPower < 0 then "<=" else ">="
                suf = subTable["original"]
                @line( "//reached suffix: #{suf}" )
                @line( "if (#{chain}.p#{compOperator}#{elemPower})")
                @line "// before call leaf: ep = #{elemPower}"
                @block =>
                    @generateLeafRewrite(elem, elemPower, subTable["rewrite"], chain)
                    
            else
                @line("if (#{chain}.p === #{elemPower})")
                @block =>
                    @line("if (#{chain}.t)")
                    @block =>
                        @generateRewriteBySuffixTree( otherElem(newElement), subTable, chain+".t")

        
    generateLeafRewrite: ( elem, elemPower, rewrite, chain)->
        throw new Error("power?") unless elemPower? 
        @line("console.log( 'Leaf: rewrite this to #{rewrite}');")
        @line("//elem: #{elem}, power: #{elemPower}: rewrite this to #{rewrite}")
        @line("console.log( 'Truncate chain from ' + showNode(chain) + ' to ' + showNode(#{chain}) + ' with additional elem: #{elem}^#{-elemPower}' );")
        @line("chain = #{chain};")
        @line("//Append rewrite")

        revRewrite = rewrite[..]
        revRewrite.reverse()
        revRewrite.push [elem, -elemPower]

        sPowers = ( "[\"#{e}\",#{p}]" for [e, p] in collectPowers(revRewrite) ).join(",")
        @line("stack.push(#{sPowers});")
        
    _nodeClass: ( letter)->
        {"a": "NodeA", "b":"NodeB"}[letter]

#extracts from table rules, rewriting single powers                
powerRewriteRules = (rewriteTable) ->
  result = []
  for [key, rewrite] in rewriteTable.items()
      gKey = groupPowersVd(key)
      gRewrite = groupPowersVd(rewrite)
      if gKey.length is 1 and gRewrite.length is 1
          [x, p] = gKey[0]
          [x_, p1] = gRewrite[0]
          if x is x_
              result.push [x, p, p1]
  return result

#for given lsit of power rewrites, return range of allowed powers for element
# (range bounds are inclusive)
elementPowerRange = ( powerRewrites, letter )->
  ###search for rules of type a^n -> a^m###
  powers = (p1 for [x, p1, p2] in powerRewrites when x is letter)
  if powers.length is 0
    throw new Error("No power rewrites for #{letter}")
  minPower = Math.min( powers... ) + 1
  maxPower = Math.max( powers... ) - 1
  return [minPower, maxPower]
    
elementOrder = ( powerRewrites, letter)->
    orders = (Math.abs(p1-p2) for [x, p1, p2] in powerRewrites when x is letter)
    if orders.length is 0
      throw new Error("No power rewrites for #{letter}")
    return Math.min( orders... )



reverseSuffixTable = (ruleset, ignorePowers = true)->
    revTable = {}
    
    for [suffix, rewrite] in ruleset.items()
        gSuffix = groupPowersVd(suffix)
        #gSuffix.reverse()
        gRewrite = groupPowersVd(rewrite)
        #gRewrite.reverse()
        if ignorePowers
            if gSuffix.length is 1 and gRewrite.length is 1 and gSuffix[0][0] is gRewrite[0][0]
                continue
            if gSuffix.length is 2 and gRewrite.length is 0
                continue
        table = revTable
        for e_p in gSuffix by -1
            e_p_str = JSON.stringify e_p
            if table.hasOwnProperty e_p_str
                table = table[e_p_str]
            else
                table1 = {}
                table[e_p_str] = table1
                table = table1
        table["rewrite"] = gRewrite
        table["original"] = gSuffix
    return revTable


exports.repeatRewrite = repeatRewrite = (appendRewriteOnce) -> (chain, stack) ->
  while stack.length > 0
    chain = appendRewriteOnce chain, stack
  return chain

exports.canAppend = (appendRewriteOnce) -> (chain, element, power) ->
  stack = [[element, power]]
  appendRewriteOnce(chain, stack)
  return stack.length is 0
  
exports.makeAppendRewrite= makeAppendRewrite = (s)->
  g = new CodeGenerator(s)
  g.debug=false
  
  rewriterCode = g.generateAppendRewriteOnce()
  #console.log rewriterCode
  appendRewriteOnce = eval rewriterCode
  throw new Error("Rewriter failed to compile") unless appendRewriteOnce?
  
  appendRewrite = repeatRewrite appendRewriteOnce    
  return appendRewrite

repeat = (pattern, count)->
    if count < 1
      return ''
      
    result = ''
    while count > 1
        if count & 1
          result += pattern
        count >>= 1
        pattern += pattern
        
    return result + pattern

exports.vdRule = vdRule = (n, m, k=2)->
    ###
    # Create initial ruleset for von Dyck group with inverse elements
    # https://en.wikipedia.org/wiki/Triangle_group#von_Dyck_groups
    ###

    r = {
        'aA': ""
        'Aa': ""
        'bB': ""
        'Bb': ""
    } 
    r[repeat('BA', k)] = ""
    r[repeat('ab', k)] = ""
    r[repeat( 'A', n )] = ""
    r[repeat( 'a', n )] = ""
             
    r[repeat( 'B', m )] = ""
    r[repeat( 'b', m )] = ""
    return new RewriteRuleset r

exports.string2chain = string2chain = (s) ->
  #last element of the string is chain head
  grouped = groupPowersVd s
  grouped.reverse()
  appendSimple unity, grouped

exports.chain2string = chain2string = (chain)->
  s = ""
  while chain isnt unity
    e = chain.letter
    p = chain.p
    if p < 0
      e = e.toUpperCase()
      p = -p
      
    s = repeat(e, p) + s
    chain = chain.t
  return s

#take list of pairs: [element, power] and returns list of single elements,
# assuming convention that negative power is uppercase letter.
ungroupPowersVd = (stack) ->
  ungroupedStack = []
  for [e, p] in stack
    if p < 0
      p = -p
      e = e.toUpperCase()        
    for i in [0...p] by 1
      ungroupedStack.push e
  return ungroupedStack  

##Creates reference rewriter, using strings internally.
# Slow, but better tested than the compiled.
exports.makeAppendRewriteRef = makeAppendRewriteRef= (rewriteRule) ->
  (chain, stack) ->
    sChain = chain2string chain
    ungroupedStack = ungroupPowersVd stack
    ungroupedStack.reverse()
    #console.log "Ref rewriter: chain=#{sChain}, stack=#{ungroupedStack.join('')}"    
    string2chain rewriteRule.appendRewrite sChain, ungroupedStack.join('')


#Remove last element of a chain, if it is A.
takeLastA = (chain) ->
  if (chain is unity) or (chain.letter isnt 'a')
    chain
  else
    chain.t
    
# Add all possible rotations powers of A generator) to the end of the chain,
# and choose minimal of all chains (by some ordering).
exports.eliminateFinalA = eliminateFinalA = (chain, appendRewrite, orderA) ->
  chain = takeLastA chain
  #zero chain is always shortest, return it.
  if chain is unity
    return chain
  #now chain ends with B power, for sure.
  #if chain.letter isnt 'b' then throw new Error "two A's in the chain!"
    
  #bPower = chain.p

  #TODO: only try to append A powers that cause rewriting.
      
  bestChain = chain
  for i in [1...orderA]
    chain_i = appendRewrite chain, [['a', i]]
    if reverseShortlexLess chain_i, bestChain
      bestChain = chain_i
  #console.log "EliminateA: got #{showNode chain}, produced #{showNode bestChain}"
  return bestChain

#Takes some rewrite ruleset and extends it by adding new rules with increased power of last element
# Example:
#  Original table:
#    b^2 a^1 -> XXX
#  Extended table
#    b^2 a^2 -> XXXa
#    b^2 a^3 -> XXXa^2
#    ... 
#    b^2 a^maxPower -> XXXa^{maxPower-1}
#
#  if power is negative, it is extended to minPower.
#  This function modifies existing rewrite table.
exports.extendLastPowerRewriteTable = extendLastPowerRewriteTable = (rewriteRule, element, minPower, maxPower) ->
  throw new Error "min power must be non-positive" if minPower > 0
  throw new Error "max power must be non-negative" if maxPower < 0
  
  #newRules = []
  for [suffix, rewrite] in rewriteRule.items()
    gSuffix = groupPowersVd suffix
    throw new Error('empty suffix!?') if gSuffix.length is 0
    continue if gSuffix[gSuffix.length-1][0] isnt element
    
    gRewrite = groupPowersVd rewrite
    
    power = gSuffix[gSuffix.length-1][1]
    step = if power > 0 then 1 else -1
    lastPower =  if power > 0 then maxPower else minPower

    #prepare placeholder item. 0 will be replaced with additional power
    gRewrite.push [element, 0]
    
    #console.log "SUFFIX  PLACEHOLDER: #{JSON.stringify gSuffix}"
    #console.log "REWRITE PLACEHOLDER: #{JSON.stringify gRewrite}"
    
    for p in [power+step .. lastPower] by step
      #Update power...
      gSuffix[gSuffix.length-1][1] = p
      gRewrite[gRewrite.length-1][1] =  p - power
      
      #console.log "   Upd: SUFFIX  PLACEHOLDER: #{JSON.stringify gSuffix}"
      #console.log "   Upd: REWRITE PLACEHOLDER: #{JSON.stringify gRewrite}"
      
      #and generate new strings      
      newSuffix = ungroupPowersVd(gSuffix).join ''
      newRewrite = ungroupPowersVd(collectPowers gRewrite).join ''

      unless tailInRewriteTable rewriteRule, newSuffix
        rewriteRule.add newSuffix, newRewrite
      #console.log "Adding new extended rule: #{newSuffix} -> #{newRewrite}"
      #TODO: don't add rules whose suffices are already in the table.
      
  return rewriteRule

#Returns True, if string tail (of nonzero length) is present in the rewrite table
tailInRewriteTable = (rewriteTable, s) ->
  for suffixTailLen in [1 ... s.length] by 1
    suffixTail = s.substring s.length - suffixTailLen
    if rewriteTable.has suffixTail
      return true
  return false
            
exports.makeAppendRewriteVerified = (rewriteRule) ->

  #Reference rewriter
  appendRewriteRef = makeAppendRewriteRef rewriteRule
  #compiled rewriter
  appendRewrite = makeAppendRewrite rewriteRule
  
  (chain, stack) ->
    console.log ("========= before verification =======")
    refValue = appendRewriteRef chain, stack[..]
    value = appendRewrite chain, stack[..]

    if not chainEquals refValue, value
      for [k, v] in rewriteRule.items()
        console.log "  #{k} -> #{v}"
      throw new Error "rewriter verification failed. args: chain = #{showNode chain}, stack: #{JSON.stringify stack}, refValue: #{showNode refValue}, value: #{showNode value}"
    return value
