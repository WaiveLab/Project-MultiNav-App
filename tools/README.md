# Map routes

Every overview follows one cell of the supplied whiteboard photo: exactly two
on-route intersections, with start/end at two other grid intersections. Routes
can have zero, one, or two turns. The four consecutive grid nodes for each map
are defined in `update_map_routes.cjs`; the first existing POI and overview metadata are preserved. Each map contains
exactly one POI. The generator also owns the spoken feature labels.

Map numbers match the photo's cells in row order, left to right and top to bottom.
The crossed-out row 2, column 2 is excluded (`map05_aurora`), leaving 17 maps without
renumbering the others. Rows 1–3 travel left to right between the marked dots;
rows 4–6 travel top to bottom. The existing three-street/four-avenue grid is retained.

After changing those vertices, regenerate and validate from the project root:

```powershell
node tools/update_map_routes.cjs
node tools/validate_maps.cjs
```

The generator updates the 17 overviews, the 12 shared intersection bases, and
34 route overlays (two per map). It removes the excluded overview and obsolete
overlays for these maps. Straight-through intersections retain their overlays;
start/end intersections have no overlay because the app does not zoom into those
overview marker types. Local detail start/end dots mark entry/exit at the edge
of the intersection view, while overview start/end dots occupy grid intersections.

Detail routes follow the right-hand sidewalk and use only sidewalk/crosswalk
segments in their shared base. Boundary intersections have only the road arms
present in the overview grid.

# Firebase candidate uploader

`seed_firebase_candidate.py` creates one complete schema-version-2 candidate in
the `parameterValues` collection. It includes all 14 independently controlled
haptic element types, including `intersectionCenter`.

Keep the downloaded Firebase Admin JSON key outside this repository. Preview a
candidate first:

```powershell
py .\tools\seed_firebase_candidate.py `
  --credentials "C:\FirebaseKeys\project-multinav-admin.json" `
  --pid "101" `
  --round 1
```

The preview does not contact or change Firebase. To publish it, install the
Admin SDK and repeat the command with `--write`:

```powershell
py -m pip install firebase-admin

py .\tools\seed_firebase_candidate.py `
  --credentials "C:\FirebaseKeys\project-multinav-admin.json" `
  --pid "101" `
  --round 1 `
  --write
```

Only publish the next round the app expects. The app deliberately rejects a
partial candidate or a candidate for a different participant/round.
