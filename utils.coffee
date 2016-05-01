
exports.formatString = (s, args)->
  s.replace /{(\d+)}/g, (match, number) -> args[number] ?  match

exports.pad = (num, size) ->
  s = num+"";
  while s.length < size
    s = "0" + s
  return s
