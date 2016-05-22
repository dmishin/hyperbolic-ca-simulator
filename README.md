Cellular automata on hyperbolic fields
======================================

Simulator of cellular automata on regular hyperbolic plane tilings, working in browser.

[See it online](http://dmishin.github.io/hyperbolic-ca-simulator/index.html)

For usage details, see [help page](http://dmishin.github.io/hyperbolic-ca-simulator/help.html)


Key features are:

* Support of arbitrary regular tilings.
* Unlimited world size

Building
========
Build requirements are: Node.JS, NPM, GNU Make.
Install NPM modules: coffee-script, browserify, coffeeify.

Testing
=======

Running tests additionally requires the following NPM modules: mocha

```bash
$ make test
```

Requirements
============
Works in any contemporary browser: Firefox, Chromium. Probably, works in the latest IE.

Upload animation feature works only if the page is open from the local server. To do it, Python 3 is additionally required. Change to the project direcory, build it (alternatively, download [index.html](http://dmishin.github.io/hyperbolic-ca-simulator/index.html) and [application.js](http://dmishin.github.io/hyperbolic-ca-simulator/application.js) from the demo site), then run:

```bash
$ python http_server_with_upload.py
```

After this, open http://localhost:8000/index.html and upload feature should work.

Known bugs
==========

### Change to generic rule, then change grid, then change back to binary
Workaround: set rule manually again.

Licence
=======

MIT
