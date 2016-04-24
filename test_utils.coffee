assert = require "assert"

{formatString} = require "./utils.coffee"

describe "formatString", ->
  it "must format string with several args", ->
    out = formatString "{0} is dead, but {1} is alive! {0} {2}", ["ASP", "ASP.NET"]
    expect = "ASP is dead, but ASP.NET is alive! ASP {2}"
