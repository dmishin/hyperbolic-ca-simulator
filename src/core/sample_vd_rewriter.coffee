# Generates JS code that effectively rewrites
{RewriteRuleset}= require "./knuth_bendix.coffee"
{unity, chainEquals, appendSimple} = require "./vondyck_chain.coffee"
{makeAppendRewrite, groupPowersVd} = require "./vondyck_rewriter.coffee"

testRewriter = (appendRewrite, sSource, sExpected)->  
  gSource = groupPowersVd sSource
  gExpected = groupPowersVd sExpected
  
  reversed = (s)->
      rs = s[..]
      rs.reverse()
      return rs

  result = appendRewrite( unity, reversed(gSource) )
  expected = appendSimple( unity, reversed(gExpected));
  
  if chainEquals(result, expected)
    console.log("Test #{sSource}->#{sExpected} passed")
  else
    console.log("Test #{sSource}->#{sExpected} failed")
    console.log("   expected result:"+showNode(expected))
    console.log("   received result:"+showNode(result))



main = ->
    table = {'ba': 'AB', 'bB': '', 'BAB': 'a', 'BBB': 'b', 'Bb': '', 'aBB': 'BAb', 'ABA': 'b', 'AAA': 'a', 'Aa': '', 'bAA': 'ABa', 'ab': 'BA', 'aBA': 'AAb', 'bAB': 'BBa', 'bb': 'BB', 'aA': '', 'aa': 'AA'}
    s = new RewriteRuleset(table)

    appendRewrite = makeAppendRewrite s 

    for [s, t] in s.items()
       testRewriter(appendRewrite, s,t)
    return
    
main()
