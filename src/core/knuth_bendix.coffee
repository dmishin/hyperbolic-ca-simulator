#Based on http://www.math.rwth-aachen.de/~Gerhard.Hiss/Students/DiplomarbeitPfeiffer.pdf
#algorithm 3, 4
#import itertools


#values are encoded as simple strings.
# User is responsible 

print = (s ... ) -> console.log( s.join(" ") )

#COnvert "less or equal" function to the JS-compatible comparator function
le2cmp = ( leFunc ) ->
  (a,b) ->
    if a is b
      0
    else if leFunc(a,b)
      -1
    else
      1
      
exports.RewriteRuleset = class RewriteRuleset
    constructor: (rules)->
        @rules = rules

    pprint: ()->
        print ("{")
        for [v, w] in @_sortedItems()
            print "  #{v} -> #{w}"
        print "}"
        
    copy: ()->
      new RewriteRuleset(JSON.parse JSON.stringify @rules)
    
    _sortedItems: ()->
      items = @items()
      items.sort le2cmp(shortLex)
      return items

    suffices: -> (k for k of @rules)
    
    size: -> @suffices().length
    items: -> ( [k, v] for k, v of @rules )


    __equalOneSided: (other) ->
      for k, v of @rules
        if other.rules[k] isnt v
          return false
      return true
      
    equals: ( other)-> this.__equalOneSided(other) and other.__equalOneSided(this)
    
    #__hash__: ()-> return hash(@rules)

    add: ( v, w)->
        @rules[v] = w
        
    remove: ( v)->
        delete @rules[v]
        
    normalize: ( lessOrEq )->
        SS  = {}
        for v, w of @rules
            [v, w] = sortPairReverse(v, w, lessOrEq)
            #v is biggest now
            if not SS[v]?
                SS[v] = w
            else
                #resolve conflict by chosing the lowest of 2.
                SS[v] = sortPairReverse(w, SS[v], lessOrEq)[1]
        return new RewriteRuleset(SS)

    __ruleLengths: ()->
      lens = {}
      for k of @rules
        lens[k.length] = null
      lenslist = (parseInt(k, 10) for k of lens)
      lenslist.sort()
      return lenslist
    
    appendRewrite: ( s, xs_)->
        #"""Append elements of the string xs_ to the string s, running all rewrite rules"""
        rules = @rules
        return s if xs_.length is 0
        
        xs = xs_.split("")
        xs.reverse()
        
        lengths = @__ruleLengths()

        while xs.length > 0
            s = s + xs.pop()
            
            for suffixLen in lengths
                suffix = s.substring(s.length-suffixLen)
                #console.log "suf: #{suffix}, len: #{suffixLen}"
                rewriteAs = rules[suffix]
                if rewriteAs?
                    #Rewrite found!
                    #console.log "   Rewrite found: #{suffix}, #{rewriteAs}"
                    s = s.substring(0, s.length - suffixLen)
                    for i in [rewriteAs.length-1 .. 0] by -1
                      xs.push rewriteAs[i]
                    continue
        return s
    has: (key) -> @rules.hasOwnProperty key
    rewrite: ( s )-> @appendRewrite( "", s )
    

exports.shortLex = shortLex = (s1, s2)->
    #"""Shortlex less or equal comparator"""
    if s1.length > s2.length
        return false
    if s1.length < s2.length
        return true
    return s1 <= s2

exports.overlap = overlap = (s1, s2)->
    #"""Two strings: s1, s2.
    #Reutnrs x,y,z such as:
    #s1 = xy
    #s2 = yz
    #"""

    if s2.length is 0
        return [s1, "", s2]
    
    [i1, i2] = [0, 0]
    #i1, i2: indices in s1, s2
    s2_0 = s2[0]
    istart = Math.max( 0, s1.length - s2.length )
    for i in [istart ... s1.length]
        s1_i = s1[i]
        if s1_i is s2_0
            #console.log "Comparing #{s1.substring(i+1)} and #{s2.substring(1, s1.length-i)}"
            if s1.substring(i+1) is s2.substring(1, s1.length-i)
                return [s1.substring(0,i), s1.substring(i), s2.substring(s1.length-i)]
    return [s1, "", s2]

exports.splitBy = splitBy = (s1, s2)->
    #"""Split sequence s1 by sequence s2.
    #Returns True and prefix + postfix, or just False and None None
    #"""
    if s2.length == 0
        [true, s1, ""]
    
    for i in [0...s1.length - s2.length+1]
        if s1.substring(i, i+s2.length) is s2
            return [true, s1.substring(0,i), s1.substring(i+s2.length)]
    return [false, null, null]

sortPairReverse = ( a, b, lessOrEq )->
    #"""return a1, b1 such that a1 >= b1"""
    if lessOrEq(a,b)
      [b, a]
    else [a,b]

findOverlap = ( v1, w1, v2, w2 )->
    #"""Find a sequence that is can be rewritten in 2 ways using given rules"""
    # if v1=xy and v2=yz
    [x, y, z] = overlap(v1, v2)
    if y #if there is nonempty overlap
      return [true, x+w2, w1+z]
    
    [hasSplit, x, z] = splitBy(v1, v2)
    if hasSplit# and x.length>0 and z.length>0
        return [true, w1, x+w2+z]

    return [false, null, null]

knuthBendixCompletion = (S, lessOrEqual)->
    #"""S :: dict of rewrite rules: (original, rewrite)
    #lessorequal :: (x, y) -> boolean
    #"""

    SS = S.copy()
    #
    for [v1, w1] in S.items()
        for [v2, w2] in S.items()
            # if v1=xy and v2=yz
            #[x, y, z] = overlap(v1, v2)
            [hasOverlap, s1, s2] = findOverlap(v1,w1, v2,w2)
            if hasOverlap
                t1 = S.rewrite s1
                t2 = S.rewrite s2
                if t1 isnt t2
                    #dprint ("Conflict found", v1, w1, v2, w2)
                    [t1, t2] = sortPairReverse(t1, t2, lessOrEqual)
                    #dprint("    add rule:", (t1,t2) )
                    SS.add(t1, t2)
    return SS

simplifyRules = (S_, lessOrEqual)->
    S = S_.copy()
    Slist = S_.items() #used to iterate
    
    while Slist.length > 0
        [v,w] = vw = Slist.pop()
        S.remove(v)

        vv = S.rewrite vw[0]
        ww = S.rewrite vw[1]
        
        addBack = true
        if vv is ww
            #dprint("Redundant rewrite", v, w)
            addBack = false
        else
            vw1 = sortPairReverse(vv,ww, lessOrEqual)
            if vw1[0] isnt vw[0] and  vw1[1] isnt vw[1]
                #dprint ("Simplify rule:", vw, "->", vw1 )
                S.add( vw1... )
                Slist.push(vw1)
                addBack = false
        if addBack
            S.add(v,w)
    return S

exports.knuthBendix = (S0, lessOrEqual=shortLex, maxIters = 1000, maxRulesetSize = 1000, onIteration=null)->
    #"""Main funciton of the Knuth-Bendix completion algorithm.
    #arguments:
    #S - original rewrite table
    #lessOrEqual - comparator for strings. shortLex is the default one.
    #maxIters - maximal number of iterations. If reached, exception is raised.
    #maxRulesetSize - maximal number of ruleset. If reached, exception is raised.
    #onIteration - callback, called each iteration of the method. It receives iteration number and current table.
    #"""
    S = S0.normalize(lessOrEqual)
    for i in [0...maxIters]
        if S.size() > maxRulesetSize
            throw new Error("Ruleset grew too big")
        SS = simplifyRules(S, lessOrEqual)
        SSS = knuthBendixCompletion(SS, lessOrEqual)
        if SSS.equals S
            #Convergence achieved!
            return SSS
        if onIteration?
           onIteration( i, S )
        S = SSS
    throw new Error("Iterations exceeded")
    
