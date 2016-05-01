Cellular automata on hyperbolic fields
======================================

BUGS
----

### Serious problem: rule B3 S023 does not actually works!
seems that only neighbored cells are evaluated!


TODO List
---------
Things left to implement

**GUI**
* [ ] Save and load state to Local Storage (or indexed database? Seems like the latter is better!)
* [ ] Import data from URL
* [ ] Select manually, export selection (remove export visible)
* [ ] Write short help
* [ ] Support Day/Night rules
* [ ] Notifications
* [ ] Random fill fills fixed number of cells, not radius
* [ ] Adavnced settings: fill percent, size; autostop population;
* [ ] Pan / Edit button
* [ ] Home pointer
* [ ] Manually setting imase size
* [x] Upload frames of smooth animations

**Internal code structure**
* [ ] Reorganize code, to make appendRewrite, eliminateFinalA, group a parts of a single entity.
* [ ] improve performance of eliminateFinalA, by trying only rewrites that change something. (Is it really different? Check performance.)
* [ ] Split application.coffee into modules. It is too big.
* [ ] Create application class.

**Major rewrites**
* [ ] Use web worker for calculations.
