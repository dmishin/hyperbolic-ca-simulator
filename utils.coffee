"use strict"
exports.formatString = (s, args)->
  s.replace /{(\d+)}/g, (match, number) -> args[number] ?  match

exports.pad = (num, size) ->
  s = num+"";
  while s.length < size
    s = "0" + s
  return s

exports.parseIntChecked = (s)->
  v = parseInt s, 10
  throw new Error("Bad number: #{s}") if Number.isNaN v
  return v
  
