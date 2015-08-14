#search for cell  clusters and navigate through them

{eliminateFinalA, NodeHashMap, chainLen} = require "./vondyck_chain.coffee"
{mooreNeighborhood, allClusters} = require "./field.coffee"
{DomBuilder} = require "./dom_builder.coffee"

exports.Navigator = class Navigator
  constructor: (@observer) ->
    @clustersElem = document.getElementById "navigator-cluster-list"
    @clusters = []
    
  search: (field, n, m, appendRewrite)->
    #field is NodeHashMap
    @clusters = allClusters field, n, m, appendRewrite
    @updateClusterList()

  setObserver: (o) -> @observer = o
  
  makeNavigateTo: (chain) -> (e) =>
    e.preventDefault()
    #console.log JSON.stringify chain
    if @observer?
      @observer.navigateTo chain
    return
    
  updateClusterList: ->
    dom = new DomBuilder

    dom.tag "ul"
    
    for cluster, idx in @clusters
      size = cluster.length
      dist = chainLen cluster[0]

      dom.tag("li")
         .rtag("navtag", "a").a("href", "#nav-cluster#{idx}")
         .text("#{size} cells at distance #{dist}")
         .end()
         .end()
        
      dom.vars.navtag.addEventListener "click",
        @makeNavigateTo cluster[0]
      
    dom.end()
    
    @clustersElem.innerHTML = ""
    @clustersElem.appendChild dom.finalize()
  