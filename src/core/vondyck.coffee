{makeAppendRewrite, vdRule, eliminateFinalA} = require "./vondyck_rewriter.coffee"
{parseNode, unity} = require "./vondyck_chain.coffee"
{RewriteRuleset, knuthBendix} = require "../core/knuth_bendix.coffee"

exports.VonDyck = class VonDyck
  constructor: (@n, @m, @k=2)->
    throw new Error "bad N" if @n <= 0
    throw new Error "bad M" if @m <= 0
    throw new Error "bad K" if @k <= 0

    @unity = unity
    
  toString: -> "VonDyck(#{@n}, #{@m}, #{@k})"
  
  parse: (s) -> parseNode s
  
  solve: ->
    rewriteRuleset = knuthBendix vdRule @n, @m, @k
    @appendRewrite = makeAppendRewrite rewriteRuleset
    #console.log "Solved group #{@} OK"
    
  appendRewrite: (chain, stack)->
    throw new Error "Group not solved"

  trimA: (chain)->
    eliminateFinalA chain, @appendRewrite, @n

  
  rewrite: (chain)->
    @appendRewrite @unity, chain.asStack()
  
