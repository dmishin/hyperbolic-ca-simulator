{parseUri} = require "./parseuri.coffee"
assert = require "assert"

describe "parseUri", ->
  it "should parse URI with parameters", ->
    uri = "https://sample.org/folder/root.html?p1=1&p2=2&p3=hello"

    parsed = parseUri uri

    assert.equal parsed.anchor, ''
    assert.equal parsed.query, 'p1=1&p2=2&p3=hello'
    assert.equal parsed.file, 'root.html'
    assert.equal parsed.directory, '/folder/'
    assert.equal parsed.path, '/folder/root.html'
    assert.equal parsed.relative, '/folder/root.html?p1=1&p2=2&p3=hello'
    assert.equal parsed.port, ''
    assert.equal parsed.host, 'sample.org'
    assert.equal parsed.password, ''
    assert.equal parsed.user, ''
    assert.equal parsed.userInfo, ''
    assert.equal parsed.authority, 'sample.org'
    assert.equal parsed.protocol, 'https'
    assert.equal parsed.source, 'https://sample.org/folder/root.html?p1=1&p2=2&p3=hello'
    
    assert.equal parsed.queryKey.p1, '1'
    assert.equal parsed.queryKey.p2, '2'
    assert.equal parsed.queryKey.p3, 'hello'
