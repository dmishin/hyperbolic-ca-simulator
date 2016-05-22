TODO List
---------
Things left to implement

### GUI
* [x] Save and load state to Indexed database
* [x] Import data from URL
* [ ] Select manually, export selection (remove export visible)
* [x] Write short help
* [x] Display generation
* [x] Support Day/Night rules
* [ ] Notifications
* [x] Random fill fills fixed number of cells, not radius
* [ ] Advanced settings: fill percent, size; critical population;
* [x] Pan / Edit button
* [x] Home pointer
* [x] Manually setting image size
* [x] Export to SVG
* [x] Upload frames of smooth animations

### Internal code structure
* [ ] Reorganize code, to make appendRewrite, eliminateFinalA, group a parts of a single entity.
* [ ] Improve performance of eliminateFinalA, by trying only rewrites that change something. (Is it really different? Check performance.)
* [x] Split application.coffee into modules. It is too big.
* [ ] Re-group modules: core, ui. Target: make core modules easily usable in a separate project
* [v] Create application class. Done partially.

### Major rewrites
* [ ] Use web worker for calculations.

