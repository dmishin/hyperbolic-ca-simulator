assert = require "assert"

{formatString, pad, mod} = require "../src/core/utils.coffee"

describe "formatString", ->
  it "must format string with several args", ->
    out = formatString "{0} is dead, but {1} is alive! {0} {2}", ["ASP", "ASP.NET"]
    expect = "ASP is dead, but ASP.NET is alive! ASP {2}"
    assert.equal out, expect

describe "pad", ->
  it "must pad small nums", ->
    assert.equal pad(4,4), "0004"
    assert.equal pad(4,5), "00004"
    
    assert.equal pad(123,5), "00123"

  it "must not truncate", ->
    assert.equal pad(123,2), "123"
    assert.equal pad(123,1), "123"
    
describe "mod", ->
  it "must calculate modulo of positive values", ->
    assert.equal 0, mod 0, 5
    assert.equal 1, mod 1, 5
    assert.equal 2, mod 2, 5

    assert.equal 0, mod 25, 5
    assert.equal 1, mod 26, 5
    assert.equal 2, mod 27, 5

  it "must calculate modulo of negative values mathematically", ->
    assert.equal 0, mod -25, 5
    assert.equal 1, mod -24, 5
    assert.equal 2, mod -23, 5
                
