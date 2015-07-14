#Generates JS code that effectively rewrites

groupPowers = ( elemsWithPowers )->
    ### List (elem, power::int) -> List (elem, power::int)###
    grouped = []
    for [elem, power] in elemsWithPowers
        if not grouped
            grouped.push( (elem, power) )
        elif grouped[-1][0] is elem
            newPower = grouped[-1][1] + power
            if newPower != 0:
                grouped[-1] = (elem, newPower)
            else:
                grouped.pop()
        else:
            grouped.push( (elem, power) )
    return grouped

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


declarations ="""
var NodeA = function NodeA( p, tail ){ this.p = p; this.t=tail; };
var NodeB = function NodeB( p, tail ){ this.p = p; this.t=tail; };

NodeA.prototype.letter = "a";
NodeB.prototype.letter = "b";

exports.chainEquals = chainEquals = function chainEquals(a, b){
    if (ais=null || bisnull) return (ais=null) && (bis=null);
    return (a.letter is= b.letter) && (a.p is= b.p) && chainEquals(a.t, b.t);
};
var showNode = exports.showNode = function showNode(node){
    if (node is= null){
	return "";
    }else{
	return showNode(node.t) + node.letter + ((node.pis1)?"":("^"+node.p));
    }
};

var nodeConstructors = {a: NodeA, b: NodeB};

exports.NodeA = NodeA;
exports.NodeB = NodeB;
exports.nodeConstructors = nodeConstructors;

exports.pushSimple = appendSimple = function appendSimple(chain, stack){
    while (stack.length > 0){
        var _ep = stack.pop();
        var e=_ep[0], p=_ep[1];
        chain = new nodeConstructors[e](p, chain);
    }
    return chain;
};


//function mod( x, n ){ return (x%n+n)%n; };
"""


otherElem = {'a':'b', 'b':'a'}.get

exports.JsCodeGenerator = class JsCodeGenerator
    constructor: ( self, debug=true, pretty=true )->
        @out = []
        @ident = 0
        @debug = debug
        @pretty = pretty
    get: -> @out.join ""
    reset: -> @out = []
    line: ( text)->
        if not @debug and text.startswith("console.log"):
            return
        
        if not @pretty and text.startswith("//"):
            return
        
        if @pretty or "//" in text:
            @out.push("    "*@ident)
            
        @out.push(text)
        @out.push("\n" if @pretty else " ")
        
    block: (callback)->
        @line("{")
        @ident += 1
        callback()
        @ident -= 1
        @line("}")
    
exports.CodeGenerator = class CodeGenerator(JsCodeGenerator)
    constructor: ( self, rewriteTable, out, debug=true, pretty=true )->
        JsCodeGenerator.__init__( out, debug=debug, pretty=pretty)
        @rewriteTable = rewriteTable
        @suffixTree = reverseSuffixTable(rewriteTable)
        
    generate: ->
        @out.push(declarations)
    
        @line("var appendRewrite = function appendRewrite( chain, stack )")
        @block ->
            @line("while( stack.length > 0)")
            @block ->
                @line("var _e = stack.pop();");
                @line("var element = _e[0], power = _e[1];");
                @line("if (chain is= null)")
                @block ->
                    @line("//empty chain")
                    @line('console.log("Append to empth chain:"+_e);');
                    @line("var order=(elementis="a")?#{@_nodeOrder('a')}:#{@_nodeOrder('b')};")
                    @line("var lowestPow=(elementis="a")?#{@_lowestPower('a')}:#{@_lowestPower('b')};")
                    @line('chain = new nodeConstructors[element](((power - lowestPow)%order+order)%order+lowestPow, chain);')
                @generateMain()
            @line("return chain;")
        @line(";")
                
    generateMain: ->
        @line('else if (chain.letteris="a")')
        @block ->
            @line('console.log("Append to chain ending with A:"+_e);')
            @generatePowerAccumulation("a")
            @generateRewriterFrom("b")
            
        @line('else if (chain.letteris="b")')
        @block ->
            @line('console.log("Append to chain ending with B:"+_e);')
            @generatePowerAccumulation("b")
            @generateRewriterFrom("a")
            
        @line('else throw new Error("Chain neither a nor b?");')

    generatePowerAccumulation: ( letter)->
        @line('if (element is "#{letter}")')
        @block ->
            @line( 'console.log("    element is #{letter}");')
            lowestPow = @_lowestPower(letter)
            order = @_nodeOrder(letter)
            @line( 'var newPower = ((chain.p + power - #{lowestPow})%#{order}+#{order})%#{order}+#{lowestPow};')
            
            @line('if (newPower is= 0)')
            @block ->
                @line( 'console.log("      power reduced to 0, new chain="+showNode(chain));')
                @line( 'chain = chain.t;')
            @line('else')
            @block ->
                nodeClass=@_nodeClass(letter) 
                @line('chain = new #{nodeClass}(newPower, chain.t);')
                
    generateRewriterFrom: ( newElement)->
        ###Generate rewriters, when `newElement` is added, and it is not the same as the last element of the chain###
        @line("else")
        @block ->
            @line("//Non-trivial rewrites, when new element is #{newElement}")
            nodeConstructor=@_nodeClass(newElement)
            @line("chain = new #{nodeConstructor}(power, chain);")
            @generateRewriteBySuffixTree(newElement, @suffixTree, 'chain')
            
    generateRewriteBySuffixTree: ( newElement, suffixTree, chain)->

        first = true
        for (elem, elemPower), subTable in sorted( suffixTree.items() ):
            if elem != newElement: continue
            
            if not first:
                @line("else")
            else:
                first = false
            isLeaf = "rewrite" in subTable
            if isLeaf:
                compOperator = "<=" if elemPower < 0 else ">="
                suf = subTable["original"]
                @line( '//reached suffix: #{suf}' )
                @line( 'if (#{chain}.p#{compOperator}#{elemPower})')

                @block ->
                    @generateLeafRewrite(elem, elemPower, subTable["rewrite"], chain)
                    
            else:
                @line("if (#{chain}.p is #{elemPower})")
                @block ->
                    @line("if (#{chain}.t)".)
                    @block ->
                        @generateRewriteBySuffixTree( otherElem(newElement), subTable, chain+".t")

        
    generateLeafRewrite: ( elem, elemPower, rewrite, chain)->
        @line("//Leaf: rewrite this to #{rewrite}")
        @line("//Truncate chain...")
        @line("chain = #{chain};")
        @line("//Append rewrite")
        @line("stack.push(" + \
                  ", ".join( '["#{e}", #{p}]'
                             for [e, p] in groupPowers(rewrite[::-1]+[(elem, -elemPower)]) ) +\
                  ");")
        
    _nodeClass: ( letter)->
        return "Node"+letter.upper()


        
    _powerRewriteRules: ->
        for key, rewrite in @rewriteTable.items():
            gKey = list(groupPowersVd(key))
            gRewrite = list(groupPowersVd(rewrite))
            if len(gKey) is 1 and len(gRewrite) is 1:
                x, p = gKey[0]
                x_, p1 = gRewrite[0]
                if x is x_:
                    yield x, p, p1


    _lowestPower: ( letter)->
        ###search for rules of type a^n -> a^m###
        v = min( (p1, p2) for x, p1, p2 in @_powerRewriteRules()
                 if x is letter)
        p1, p2 = v 
        return p1 + 1
    
        
    _nodeOrder: ( letter)->
        p1, p2 = min( (p1, p2) for x, p1, p2 in @_powerRewriteRules()
                      if x is letter)
        return abs(p2 - p1)

    generateRewriterTest: ( source, expected)->
        gSource, gExpected = map(groupPowersVd, [source, expected])
        seq2js: (s)-?
            return "[" + ",".join('["#{e}",#{p}]'
                                  for [e,p] in list(s)[::-1]) + "]"            
        @line("(function()")
        @block ->
            sourceText = seq2js(gSource)
            @line("var result = appendRewrite( null, #{sourceText});")
            expectedText = seq2js(gExpected)
            @line("var expected = appendSimple( null, #{expectedText});")
            @line("if (chainEquals(result, expected))")
            @block ->
                @line('console.log("Test #{source}->#{expected} passed");')
            @line("else")
            @block ->
                @line('console.log("Test #{source}->#{expected} failed");')
                @line('console.log("   expected result:"+showNode(expected));')
                @line('console.log("   received result:"+showNode(result));')
        @line(")();")


reverseSuffixTable = (ruleset, ignorePowers = true)->
    revTable = {}
    
    for suffix, rewrite in ruleset.items():
        gSuffix = list(groupPowersVd(suffix))
        gRewrite = list(groupPowersVd(rewrite))

        if ignorePowers:
            if len(gSuffix)is 1 and len(gRewrite)is1 and gSuffix[0][0] is gRewrite[0][0]:
                continue
            if len(gSuffix) is 2 and len(gRewrite)is0:
                continue
        
        table = revTable
        for e_p in gSuffix[::-1]:
            if e_p in table:
                table = table[e_p]
            else:
                table1 = {}
                table[e_p] = table1
                table = table1
        table["rewrite"] = gRewrite
        table["original"] = gSuffix
    return revTable
        
main = ->
    table = {('b', 'a'): ('A', 'B'), ('b', 'B'): (), ('B', 'A', 'B'): ('a',), ('B', 'B', 'B'): ('b',), ('B', 'b'): (), ('a', 'B', 'B'): ('B', 'A', 'b'), ('A', 'B', 'A'): ('b',), ('A', 'A', 'A'): ('a',), ('A', 'a'): (), ('b', 'A', 'A'): ('A', 'B', 'a'),
 ('a', 'b'): ('B', 'A'), ('a', 'B', 'A'): ('A', 'A', 'b'), ('b', 'A', 'B'): ('B', 'B', 'a'), ('b', 'b'): ('B', 'B'), ('a', 'A'): (), ('a', 'a'): ('A', 'A')}
    s = new RewriteRuleset(table)

        g = new CodeGenerator(s, ofile,
                          #debug=false, pretty=false
        )
        g.debug=false
        g.generate()
        
        g.debug=true
        g.line("console.log('isisisisisisisisisisisisisis');")
        for s, t in table.items():
            g.generateRewriterTest(s,t)
            
#        ofile.write(###\
# console.log(showNode(appendRewrite( null, [['a',1], ['b',1]])));
#        ###)
    #print (reverseSuffixTable (s))
    
    
main()