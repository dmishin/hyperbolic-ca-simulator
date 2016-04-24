
exports.formatString = (s, args)->
  s.replace /{(\d+)}/g, (match, number) -> args[number] ?  match
