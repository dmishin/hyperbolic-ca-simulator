{lzw_encode, lzw_decode} = require "../lzw.coffee"
assert = require "assert"
describe "lzw_encode", ->
  strings = ["", "a", "bbbbbbbbbabababbabab", "hello hello hello hello this is me"]
  
  it "should encode without error some strings", ->
    codes = (lzw_encode(s) for s in strings)

    for c1, i in codes
      for c2, j in codes
        if i isnt j
          assert c1 isnt c2, "Code for #{strings[i]} isnt #{strings[j]}"
    return
    
  it "should decode. giving same result", ->
    for s in strings
      code = lzw_encode s
      s1 = lzw_decode code
      assert.equal s1, s
    
    
