# Terrain edges — rounded coastlines

**Goal (the user's request):** keep BlueHaven's simple grid exactly as it is, but make the edges
between different terrain look rounded and natural instead of perfect squares, by looking only
at each cell's 8 neighbours. A visual layer only: no change to terrain coordinates, terrain
types, building placement, animals, pathfinding, resources, island size, collision or saves.
Keep it simple: no new terrain architecture, no Marching Squares, no procedural terrain.

- Use the 4 cardinal neighbours for edges and the diagonals for corners.
- Same terrain all round → a plain square. A different neighbour → a softened edge on that side.
  Different on two touching sides → a rounded corner. Surrounded by other terrain → a rounded patch.
- All boundaries use the same treatment at first, built so terrain pairs can later get their own
  look (sand/water soft and round, rock/water hard and irregular, ice/water broken, mud/water soft
  and irregular).
- No seams: the two cells on either side of a boundary must agree on where it is (no gaps,
  overlaps, cracks or flicker).
- Performance: work it out only when the island loads and when a tile changes (then only that
  tile and its neighbours); cache the result; nothing per frame.

## How the terrain works today

1. **Where terrain blocks are created:** each island scene (`scenes/islands/*.tscn`) has one
   `Ground` TileMapLayer. Its tiles were painted by `tools/generate_islands.gd` and are stored in
   the scene. At runtime tiles change only through `set_cell`:
   - the shovel (`scripts/world/sand_shovel.gd`);
   - Mangrove silting (`mangrove_ecosystem.gd`);
   - parrotfish sand and the hurricane (`reef_ecosystem.gd`);
   - dock decks (`building.gd`);
   - loading a save (saved tile edits).
2. **Where the terrain type is stored:** in the tileset `assets/tilesets/placeholder_tileset.tres`.
   Each atlas tile has custom data "terrain" (sand, grass, rock, ice, mud, water = shallow, "" =
   mid water) and "walkable". Deep water is no tile at all, just the ocean background.
3. **Where its picture comes from:** that tileset's single atlas texture, one 32×32 square per
   terrain type. There are no meshes; Godot's TileMapLayer draws the squares.
4. **Where it's rendered:** by each island's `Ground` TileMapLayer (z-index −2, tinted by island
   health in `IslandHealth.tint`).
5. **Can one block's look be swapped?** Only by setting a different tile, which would change its
   terrain type, so that's not allowed. A separate overlay drawn on top can change how a cell
   looks without touching the cell itself.
6. **The smallest change:** add one overlay node per island ("TerrainEdges"), drawn just above
   `Ground`, that paints the rounded corners and edges. `Ground` itself stays untouched.

## Proposal

- **One `TerrainEdges` node per island**, a child of the island next to `Ground`. It reads
  `Ground`'s cells and draws, for each boundary, small shapes in the colour of the terrain that
  "wins" there:
  - a quarter-circle filling a corner;
  - a gently curved strip along an edge.
- **Seam-free by deciding at the shared corners, not per cell.** Each grid corner point is shared
  by 4 cells. For each one, look at those 4 cells and decide the shape around it from a fixed
  priority order (land over water: rock, grass, sand, mud and ice above shallow, shallow above
  mid, mid above deep). The cells on both sides of a boundary always draw the same shape, so
  there are no gaps or overlaps.
- **Uses the 8 neighbours as asked:**
  - a cell's 4 corners each use 2 cardinal neighbours and 1 diagonal;
  - a cell's edges use the cardinal neighbours.
  - Examples:
    - a water cell with sand all round → 4 sand corners rounding in: a rounded pool;
    - sand above and to the right → a rounded top-right corner;
    - a single sand cell in water → a rounded islet.
- **Cached:** the shapes are worked out once when an island loads and drawn in one batch. When
  a tile changes, it and its 8 neighbours are redone (one notice from the places that call
  `set_cell`).
- **Terrain-pair styles later:** a small table from (terrain, terrain) to edge style, starting
  with one style ("soft") for every pair.
- **Placeholder art:** the shapes are drawn in the same colours as the placeholder tiles; with
  real art they'd become small corner and edge pictures from a tileset.

**Status:** built (scripts/world/terrain_edges.gd, a TerrainEdges node after Ground in every island scene; tests/test_terrain_edges.gd). Tile changes notify it through SaveGame.record_tile; loading a save rebuilds it. Corners are rounded with a radius of 8 px (a quarter of a tile): the first version used the full half tile, which made blobs and pointed gaps where three terrains met.
