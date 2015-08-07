# LZW-compress a string
exports.lzw_encode = (s) ->
  return "" if s is ""
  dict = {}
  data = (s + "").split("")
  out = []
  currChar = undefined
  phrase = data[0]
  code = 256
  i = 1

  while i < data.length
    currChar = data[i]
    if dict[phrase + currChar]?
      phrase += currChar
    else
      out.push (if phrase.length > 1 then dict[phrase] else phrase.charCodeAt(0))
      dict[phrase + currChar] = code
      code++
      phrase = currChar
    i++
  out.push (if phrase.length > 1 then dict[phrase] else phrase.charCodeAt(0))
  i = 0

  while i < out.length
    out[i] = String.fromCharCode(out[i])
    i++
  out.join ""

# Decompress an LZW-encoded string
exports.lzw_decode = (s) ->
  return "" if s is ""
  dict = {}
  data = (s + "").split("")
  currChar = data[0]
  oldPhrase = currChar
  out = [ currChar ]
  code = 256
  phrase = undefined
  i = 1

  while i < data.length
    currCode = data[i].charCodeAt(0)
    if currCode < 256
      phrase = data[i]
    else
      phrase = (if dict[currCode] then dict[currCode] else (oldPhrase + currChar))
    out.push phrase
    currChar = phrase.charAt(0)
    dict[code] = oldPhrase + currChar
    code++
    oldPhrase = phrase
    i++
  out.join ""
