TODO List
---------
Things left to implement

### GUI
* [ ] Select manually, export selection (remove export visible)
* [ ] Notifications
* [x] Save and load state to Indexed database
* [x] Import data from URL
* [x] Write short help
* [x] Display generation
* [x] Support Day/Night rules
* [x] Random fill fills fixed number of cells, not radius
* [ ] Advanced settings: fill percent, size; critical population;
* [x] Pan / Edit button
* [x] Home pointer
* [x] Manually setting image size
* [x] Export to SVG
* [x] Upload frames of smooth animations
* [ ] Enable upload interface by button, not only on localhost.
* [ ] Animator: handle large distances
* [ ] Animator: remember initial position

### Internal code structure
* [ ] Improve performance of eliminateFinalA, by trying only rewrites that change something. (Is it really different? Check performance.)
* [ ] Performance tests
* [x] Re-group modules: core, ui. Target: make core modules easily usable in a separate project
* [x] Reorganize code, to make appendRewrite, eliminateFinalA, group a parts of a single entity.
* [x] Split application.coffee into modules. It is too big.
* [x] Create application class. 

### Major rewrites
* [ ] Use web worker for calculations.

