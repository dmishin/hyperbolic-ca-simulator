#Generates JS code that effectively rewrites
{RewriteRuleset}= require "./knuth_bendix.coffee"
{NodeA, NodeB, chainEquals, appendSimple, nodeConstructors, newNode} = require "./vondyck_chain.coffee"

groupPowers = ( elemsWithPowers )->
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

exports.JsCodeGenerator = class JsCodeGenerator
    constructor: ( debug=true, pretty=true )->
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
        if not @debug and text.match /^console.log/
            return
        
        if not @pretty and text.match /^\/\//
            return
        
        if @pretty or text.match(/\/\//)
          for i in [0...@ident]
            @out.push "    "
            
        @out.push(text)
        @out.push(if @pretty then "\n" else " ")
        
    block: (callback)->
        @line("{")
        @ident += 1
        callback()
        @ident -= 1
        @line("}")
    
exports.CodeGenerator = class CodeGenerator extends JsCodeGenerator
    constructor: ( rewriteTable, out, debug=true, pretty=true )->
        super debug, pretty
        @rewriteTable = rewriteTable
        @suffixTree = reverseSuffixTable(rewriteTable)
        
    generateAppendRewriteOnce: ->
        @line("(function(chain, stack )")
        @block =>
            @line "if (stack.length === 0) {throw new Error('empty stack');}"
            @line("var _e = stack.pop();")
            @line("var element = _e[0], power = _e[1];")
            @line("if (chain === null)")
            @block =>
                @line("//empty chain")
                @line('console.log("Append to empth chain:"+_e);');
                @line("var order=(element==='a')?#{@_nodeOrder('a')}:#{@_nodeOrder('b')};")
                @line("var lowestPow=(element==='a')?#{@_lowestPower('a')}:#{@_lowestPower('b')};")
                @line('chain = newNode( element, ((power - lowestPow)%order+order)%order+lowestPow, chain);')
            @generateMain()
            @line("return chain;")
        @line(")")
        return @get()
                
    generateMain: ->
        @line('else if (chain.letter==="a")')
        @block =>
            @line('console.log("Append to chain ending with A:"+_e);')
            @generatePowerAccumulation("a")
            @generateRewriterFrom("b")
            
        @line('else if (chain.letter==="b")')
        @block =>
            @line('console.log("Append to chain ending with B:"+_e);')
            @generatePowerAccumulation("b")
            @generateRewriterFrom("a")
            
        @line('else throw new Error("Chain neither a nor b?");')

    generatePowerAccumulation: ( letter)->
        @line("if (element === \"#{letter}\")")
        @block =>
            @line( "console.log(\"    element === #{letter}\");")
            lowestPow = @_lowestPower(letter)
            order = @_nodeOrder(letter)
            @line( "var newPower = ((chain.p + power - #{lowestPow})%#{order}+#{order})%#{order}+#{lowestPow};")
            
            @line('if (newPower === 0)')
            @block =>
                @line( 'console.log("      power reduced to 0, new chain="+showNode(chain));')
                @line( 'chain = chain.t;')
            @line('else')
            @block =>
                nodeClass=@_nodeClass(letter) 
                @line("chain = new #{nodeClass}(newPower, chain.t);")
                
    generateRewriterFrom: ( newElement)->
        ###Generate rewriters, when `newElement` is added, and it is not the same as the last element of the chain###
        @line("else")
        @block =>
            @line("//Non-trivial rewrites, when new element is #{newElement}")
            nodeConstructor=@_nodeClass(newElement)
            @line("chain = new #{nodeConstructor}(power, chain);")
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
        @line("//Leaf: rewrite this to #{rewrite}")
        @line("//elem: #{elem}, power: #{elemPower}: rewrite this to #{rewrite}")
        @line("//Truncate chain...")
        @line("chain = #{chain};")
        @line("//Append rewrite")

        revRewrite = rewrite[..]
        revRewrite.reverse()
        revRewrite.push [elem, -elemPower]

        sPowers = ( "[\"#{e}\",#{p}]" for [e, p] in groupPowers(revRewrite) ).join(",")
        @line("stack.push(#{sPowers});")
        
    _nodeClass: ( letter)->
        {"a": "NodeA", "b":"NodeB"}[letter]
        
    _powerRewriteRules: ->
        result = []
        for [key, rewrite] in @rewriteTable.items()
            gKey = groupPowersVd(key)
            gRewrite = groupPowersVd(rewrite)
            if gKey.length is 1 and gRewrite.length is 1
                [x, p] = gKey[0]
                [x_, p1] = gRewrite[0]
                if x is x_
                    result.push [x, p, p1]
        return result


    _lowestPower: ( letter)->
        ###search for rules of type a^n -> a^m###
        powers = (p1 for [x, p1, p2] in @_powerRewriteRules() when x is letter)
        return Math.min( powers... ) + 1
        
    _nodeOrder: ( letter)->
        orders = (Math.abs(p1-p2) for [x, p1, p2] in @_powerRewriteRules() when x is letter)
        if orders.length is 0
          throw new Error("No power rewrites for #{letter}")
        return Math.min( orders... )

testRewriter = (appendRewrite, sSource, sExpected)->  
  gSource = groupPowersVd sSource
  gExpected = groupPowersVd sExpected
  
  reversed = (s)->
      rs = s[..]
      rs.reverse()
      return rs

  result = appendRewrite( null, reversed(gSource) )
  expected = appendSimple( null, reversed(gExpected));
  
  if chainEquals(result, expected)
    console.log("Test #{sSource}->#{sExpected} passed")
  else
    console.log("Test #{sSource}->#{sExpected} failed")
    console.log("   expected result:"+showNode(expected))
    console.log("   received result:"+showNode(result))


reverseSuffixTable = (ruleset, ignorePowers = true)->
    revTable = {}
    
    for [suffix, rewrite] in ruleset.items()
        gSuffix = groupPowersVd(suffix)
        gRewrite = groupPowersVd(rewrite)

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
  
  appendRewriteOnce = eval g.generateAppendRewriteOnce()
  appendRewrite = repeatRewrite appendRewriteOnce
      
  throw new Error("Failed to compilation gave nothing?") unless appendRewrite?
  return appendRewrite

main = ->
    table = {'ba': 'AB', 'bB': '', 'BAB': 'a', 'BBB': 'b', 'Bb': '', 'aBB': 'BAb', 'ABA': 'b', 'AAA': 'a', 'Aa': '', 'bAA': 'ABa', 'ab': 'BA', 'aBA': 'AAb', 'bAB': 'BBa', 'bb': 'BB', 'aA': '', 'aa': 'AA'}
    s = new RewriteRuleset(table)

    appendRewrite = makeAppendRewrite s 

    for [s, t] in s.items()
       testRewriter(appendRewrite, s,t)
    return
    
main()
