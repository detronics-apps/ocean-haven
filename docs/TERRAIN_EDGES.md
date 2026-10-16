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

## Heights (the owner's pick: line + height)

Where one ground stands above the next, a 3/4 view shows the higher one's face. Looks only, like
the rounded corners: walking, building, collisions and saves are unchanged.

- **One height per region, from how the grounds sit inside each other.** The sea (every water
  kind) is 0. A region of ground (its cells side by side) touching the sea stands its own step
  above it: sand 0 (a beach slopes into the water: the waves show it), mud 2, grass 5, ice 6,
  rock 12 px. Any other region stands on top of the one it shares the most border with among
  those already worked out (outside it, or a bigger one beside it; on a tie the higher), a step
  higher (the owner: anything lower than the ground in front of it looks like a hole, so a rock
  between the beach and a grass plateau stands on the plateau): grass on rock 4, on mud 3, on sand 5; rock on grass 5, on
  sand 6, on ice 6; mud on sand 2; sand on anything 0 (`TerrainEdges.STEPS`).
  - So an island goes up from its beach and back down on the far side (water > sand > grass >
    sand > water), the Deep Sea's grass stands on top of its rock (the owner: per-ground heights
    made the grass look like holes in the rock), rock outcrops stand on the grass, and no land is
    ever lower than all the ground round it. Water inside land (pools) is 0.
  - Worked out when the island loads and once at the end of a frame in which tiles changed
    (a channel dug through or ice melting can change heights far away).
- **Faces only on the south side** (the side the 3/4 view shows), as tall as the step (at most
  16 px), hanging below the line between the two grounds into the lower one. Each face follows
  its edge's own shape: round the cell's own rounded corner (tapering away), down the curve of an
  inside corner rounding in from the ground below, else straight to the next cell's face; so
  stepped coasts, the joined diagonals and four-ground corners all come out whole (the owner's
  corner cases, checked on a test patch of all 15).
- **The line stays** along every edge (the owner liked line + height best), and runs along each
  face's foot and its ends where no face beside it covers them; foam where a face stands in the
  water; a soft shadow at the foot of a step of 5 px or more on land.
- **Lips:** where the ground drops away behind or beside a raised ground (unseen in a 3/4 view),
  its edge catches the light on the north and west and is shaded on the east (light from the top
  left), a pixel in from the line.
- **Pictures:** `assets/tilesets/terrain_faces.png` (tools/make_terrain_tiles.py, twice the
  pixels like the ground art, a tile wide and tileable, a row per ground: two courses of stones,
  an earth bank under the grass's edge, a floe's edge with the ice under the water at its foot,
  low banks of mud and sand). A face's top comes from its picture's top, its last pixels from the
  picture's foot.
- **Layers:** the faces are their own layer ("TerrainFaces", after GroundDetails, at the ground's
  z), so shells, waves on the sand and spray stay under a face; SeaWaves' moving crests skip the
  water just under one (`TerrainEdges.covers`); swimming animals, decks and boats are in front.
