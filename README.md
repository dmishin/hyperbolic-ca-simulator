Cellular automata on hyperbolic fields
======================================



TODO List
---------
Things left to implement

### GUI
* [x] Save and load state to Indexed database
* [x] Import data from URL
* [ ] Select manually, export selection (remove export visible)
* [ ] Write short help
* [x] Display generation
* [x] Support Day/Night rules
* [ ] Notifications
* [x] Random fill fills fixed number of cells, not radius
* [ ] Adavnced settings: fill percent, size; autostop population;
* [x] Pan / Edit button
* [ ] Home pointer
* [x] Manually setting imase size
* [x] Export to SVG
* [x] Upload frames of smooth animations

### Internal code structure
* [ ] Reorganize code, to make appendRewrite, eliminateFinalA, group a parts of a single entity.
* [ ] improve performance of eliminateFinalA, by trying only rewrites that change something. (Is it really different? Check performance.)
* [x] Split application.coffee into modules. It is too big.
* [ ] Re-group modules: core, ui. Target: make core modules easily usable in a separate project
* [v] Create application class. Done partially.

### Major rewrites
* [ ] Use web worker for calculations.

Building
========

    $ make

Requirements
============



BUGS
----
### Rule editor problems:

* *fixed* If bad rule entered, switch from generic to binary does not work
* if clicked OK in generic editor, then it closes even if not compiled.

### Fixed. Problem: rule B3 S023 does not actually works!
seems that only neighbored cells are evaluated!



