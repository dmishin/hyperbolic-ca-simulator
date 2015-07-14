{RewriteRuleset, knuthBendix} = require "./knuth_bendix.coffee"


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

exports.vdRule =vdRule = (n, m, k=2)->
    ###Create initial ruleset for von Dyck group with inverse elements
    #https://en.wikipedia.org/wiki/Triangle_group#von_Dyck_groups
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


#compute the rewriter
#

r = vdRule 15, 15

r1 = knuthBendix r

console.log "ruleset after elimintaion:"
console.log(r1)