{shortLex, overlap, splitBy, RewriteRuleset} = require "../src/knuth_bendix"
#M = require "../src/matrix3"
assert = require "assert"

describe "TestComparatros", ->
    it "checks shortlex", ->
        
        assert.ok( shortLex( "", "a") )
        assert.ok( shortLex( "", "") )
        assert.ok( shortLex( "a", "a") )
        assert.ok( shortLex( "a", "a") )
        
        assert.ok( shortLex( "a", "bb") )
        assert.ok( shortLex( "a", "b") )
        assert.ok not( shortLex( "bb", "a") )

describe "RewriteRuleset", ->
  it "must support construction", ->
    r = new RewriteRuleset {"aa": "", "AAA": "a"}
    it "must support copying", ->
      r1 = r.copy()
      assert.ok r isnt r1
      assert.ok r.equals r1
      assert.ok r1.equals r

    r2 = new RewriteRuleset {"aa": "a"}
    assert.ok not r.equals r2
    assert.ok not r2.equals r
    
    r3 = new RewriteRuleset {"AAA": "a", "aa": ""}
    assert.ok r.equals r3
    assert.ok r3.equals r
    
  it "must rewrite according to the rules", ->
    r = new RewriteRuleset {"aa": ""}
    assert.equal r.rewrite(""), ""
    assert.equal r.rewrite("a"), "a"
    assert.equal r.rewrite("aa"), ""
    assert.equal r.rewrite("b"), "b"
    assert.equal r.rewrite("ba"), "ba"
    assert.equal r.rewrite("baa"), "b"
    
  it "must apply rewrites multiple times", ->
    r = new RewriteRuleset {"bc": "BC", "ABC": "alphabet"}
    assert.equal r.rewrite("bc"), "BC"
    assert.equal r.rewrite("abc"), "aBC"
    assert.equal r.rewrite("Abc"), "alphabet"
    assert.equal r.rewrite("AAbc"), "Aalphabet"
    
      

describe "TestSplits", ->

    assertOverlap = (s1, s2, x, y, z)->
      assert.deepEqual( overlap(s1, s2), [x, y, z])

    assertSplit = (s1, s2, hasSplit, x, z)->
        assert.deepEqual( splitBy(s1, s2),
                          [hasSplit,
                           if x? then x else null,
                           if z? then z else null])
    it "tests split", ->
        assertSplit( "123456", "34",
                          true, "12", "56" )
        assertSplit( "123456", "35",
                          false, null, null )
        assertSplit( "123456", "123456",
                          true, "", "" )
        assertSplit( "123456", "456",
                          true, "123", "" )
        
    it "tests overlap", ->

        assertOverlap("123", "234", "1","23", "4") 
        assertOverlap("123", "1234", "","123", "4") 
        assertOverlap("123", "123", "","123", "") 
        assertOverlap("1123", "2345", "11","23", "45")
        assertOverlap("1123", "22345", "1123","", "22345")


