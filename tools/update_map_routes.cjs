// Regenerate overview routes and their shared intersection geometry.
// Run from any directory with: node tools/update_map_routes.cjs
const fs = require('node:fs');
const path = require('node:path');
const assert = require('node:assert/strict');
const mapsDir = path.resolve(__dirname, '../Project MultiNav App/Maps');
const overviewDir = path.join(mapsDir, 'overviews');
const detailDir = path.join(mapsDir, 'intersection_views');
const xs = [150, 450, 750], ys = [200, 600, 1000, 1400];
const streets = ['Aspen Street', 'Birch Street', 'Cedar Street'];
const avenues = ['Summit Avenue', 'Garden Avenue', 'Market Avenue', 'Harbor Avenue'];
// Start, first turn, second turn, end. All four vertices are intersections.
const routes = {
    map01_orchard: [[750, 200], [450, 200], [450, 1400], [150, 1400]],
    map02_harbor: [[150, 200], [450, 200], [450, 1400], [750, 1400]],
    map03_songbird: [[450, 200], [450, 600], [150, 600], [150, 1000]],
    map04_gemstone: [[750, 600], [450, 600], [450, 1000], [750, 1000]],
    map05_aurora: [[150, 600], [450, 600], [450, 1000], [750, 1000]],
    map06_melody: [[450, 1000], [450, 200], [150, 200], [150, 600]],
    map07_palette: [[750, 600], [450, 600], [450, 200], [150, 200]],
    map08_atlas: [[750, 200], [750, 600], [150, 600], [150, 1000]],
    map09_meridian: [[450, 200], [150, 200], [150, 600], [450, 600]],
    map10_solstice: [[150, 600], [450, 600], [450, 200], [150, 200]],
    map11_woodland: [[450, 600], [150, 600], [150, 1000], [450, 1000]],
    map12_desert: [[450, 200], [450, 600], [750, 600], [750, 1000]],
    map13_alpine: [[150, 200], [750, 200], [750, 1000], [450, 1000]],
    map14_storybook: [[450, 200], [450, 1000], [750, 1000], [750, 1400]],
    map15_spice: [[750, 600], [750, 1000], [450, 1000], [450, 1400]],
    map16_meadow: [[450, 600], [750, 600], [750, 1000], [450, 1000]],
    map17_trades: [[450, 1000], [150, 1000], [150, 200], [450, 200]],
    map18_carnival: [[150, 600], [150, 200], [450, 200], [450, 600]],
};
const same = (a, b) => a[0] === b[0] && a[1] === b[1];
const onSegment = (p, a, b) => (a[0] === b[0] ? p[0] === a[0] : p[1] === a[1]) &&
    p[0] >= Math.min(a[0], b[0]) && p[0] <= Math.max(a[0], b[0]) &&
    p[1] >= Math.min(a[1], b[1]) && p[1] <= Math.max(a[1], b[1]);
const intersectionName = ([x, y]) => `Intersection Between ${streets[xs.indexOf(x)]} and ${avenues[ys.indexOf(y)]}`;
const streetName = (a, b) => a[0] === b[0] ? streets[xs.indexOf(a[0])] : avenues[ys.indexOf(a[1])];
const feature = (id, type, coordinates, name) => ({
    id, type, geometry: {type: Array.isArray(coordinates[0]) ? 'LineString' : 'Point', coordinates},
    properties: {name, level: 1, accessible: true},
});
function document(name, buildingName, features) {
    const file = path.join(detailDir, name + '.json');
    const prior = fs.existsSync(file) ? JSON.parse(fs.readFileSync(file, 'utf8')) : null;
    return {version: '1.0', type: 'TactileMapDocument', metadata: {
        name, buildingName, floor: 1, scale: '1 unit = 1 foot', coordinate_unit: 'feet',
        coordinateOrigin: 'top-left', author: 'WaiveLab', created: prior?.metadata.created ?? '2026-09-24',
    }, bounds: {width: 900, height: 1600}, features};
}
const write = (file, doc) => fs.writeFileSync(file, JSON.stringify(doc, null, 4) + '\n');

// The corner ring has a crossing wherever a road arm exists, and a continuous
// sidewalk wherever that arm is absent (T junctions and outer grid corners).
const corners = {NW: [300, 650], NE: [600, 650], SE: [600, 950], SW: [300, 950]};
const arms = {
    N: [['NW', [300, 90], 'West'], ['NE', [600, 90], 'East']],
    E: [['NE', [840, 650], 'North'], ['SE', [840, 950], 'South']],
    S: [['SW', [300, 1510], 'West'], ['SE', [600, 1510], 'East']],
    W: [['NW', [60, 650], 'North'], ['SW', [60, 950], 'South']],
};
const ring = [['NW', 'NE', 'N', 'North'], ['NE', 'SE', 'E', 'East'],
    ['SW', 'SE', 'S', 'South'], ['NW', 'SW', 'W', 'West']];
function makeBase(p) {
    const [x, y] = p, vertical = streets[xs.indexOf(x)], horizontal = avenues[ys.indexOf(y)];
    const present = {N: y > ys[0], E: x < xs.at(-1), S: y < ys.at(-1), W: x > xs[0]};
    const features = [
        feature('street0', 'street', [[450, present.N ? 90 : 800], [450, present.S ? 1510 : 800]], vertical),
        feature('street1', 'street', [[present.W ? 60 : 450, 800], [present.E ? 840 : 450, 800]], horizontal),
    ];
    const sidewalks = [], crosswalks = [];
    for (const arm of ['N', 'S', 'W', 'E']) if (present[arm]) {
        for (const [corner, port, side] of arms[arm]) {
            const coords = ['N', 'W'].includes(arm) ? [port, corners[corner]] : [corners[corner], port];
            sidewalks.push(feature(`offsw${sidewalks.length}`, 'offRouteSidewalk', coords,
                `${side} sidewalk of ${['N', 'S'].includes(arm) ? vertical : horizontal}`));
        }
    }
    for (const [a, b, arm, side] of ring) {
        const coords = [corners[a], corners[b]];
        if (present[arm]) crosswalks.push(feature(`offcw${crosswalks.length}`, 'offRouteCrosswalk', coords,
            `${side} crosswalk across ${['N', 'S'].includes(arm) ? vertical : horizontal}`));
        else sidewalks.push(feature(`offsw${sidewalks.length}`, 'offRouteSidewalk', coords,
            `${side} sidewalk of ${['N', 'S'].includes(arm) ? horizontal : vertical}`));
    }
    features.push(...sidewalks, ...crosswalks, feature('center0', 'intersectionCenter', [450, 800], 'Intersection center'));
    const name = intersectionName(p);
    return document(name, name, features);
}
function routeIntersections(vertices) {
    const points = [];
    for (let i = 0; i < vertices.length - 1; i++) {
        const a = vertices[i], b = vertices[i + 1];
        const candidates = xs.flatMap(x => ys.map(y => [x, y])).filter(p => onSegment(p, a, b));
        candidates.sort((p, q) => Math.hypot(p[0] - a[0], p[1] - a[1]) - Math.hypot(q[0] - a[0], q[1] - a[1]));
        points.push(...candidates.filter(p => !points.length || !same(p, points.at(-1))));
    }
    return points;
}
function makeOverview(original, vertices, points) {
    const features = vertices.slice(1).map((b, i) => feature(`str${i}`, 'onRoute', [vertices[i], b], streetName(vertices[i], b)));
    // Partition each street into route and non-route intervals without overlaps.
    for (const [vertical, constants, positions] of [[true, xs, ys], [false, ys, xs]]) {
        for (const fixed of constants) {
            let segment = null;
            const flush = () => {if (segment) features.push(feature(`str${features.length}`, 'offRoute', segment, streetName(...segment))); segment = null;};
            for (let i = 0; i < positions.length - 1; i++) {
                const a = vertical ? [fixed, positions[i]] : [positions[i], fixed];
                const b = vertical ? [fixed, positions[i + 1]] : [positions[i + 1], fixed];
                const used = vertices.slice(1).some((end, j) => onSegment(a, vertices[j], end) && onSegment(b, vertices[j], end));
                if (used) flush();
                else if (segment) segment[1] = b;
                else segment = [a, b];
            }
            flush();
        }
    }
    features.push(...original.features.filter(f => f.type === 'landmark'));
    for (const y of ys) for (const x of xs) {
        const p = [x, y];
        if (same(p, vertices[0]) || same(p, vertices.at(-1))) continue;
        features.push(feature(`intersection-${xs.indexOf(x)}-${ys.indexOf(y)}`,
            points.some(q => same(p, q)) ? 'onRouteIntersection' : 'offRouteIntersection', p, intersectionName(p)));
    }
    features.push(feature('start', 'start', vertices[0], `Route Start at ${intersectionName(vertices[0])}`),
        feature('end', 'end', vertices.at(-1), `Route End at ${intersectionName(vertices.at(-1))}`));
    return {...original, features};
}
const armFrom = (center, p) => p[0] < center[0] ? 'W' : p[0] > center[0] ? 'E' : p[1] < center[1] ? 'N' : 'S';
function makeDetail(mapName, p, previous, next, base) {
    const incoming = armFrom(p, previous), outgoing = armFrom(p, next);
    const entry = {N: 'NW', E: 'NE', S: 'SE', W: 'SW'}[incoming];
    const exit = {N: 'NE', E: 'SE', S: 'SW', W: 'NW'}[outgoing];
    const port = (arm, corner) => arms[arm].find(([c]) => c === corner)[1];
    // Follow the right-hand sidewalk, counterclockwise around the corner ring.
    const ccw = {NW: 'SW', SW: 'SE', SE: 'NE', NE: 'NW'};
    const coords = [port(incoming, entry), corners[entry]];
    let corner = entry;
    while (corner !== exit) {corner = ccw[corner]; coords.push(corners[corner]);}
    coords.push(port(outgoing, exit));
    const features = [];
    for (let i = 0; i < coords.length - 1; i++) {
        const a = coords[i], b = coords[i + 1];
        const baseFeature = base.features.find(f => f.geometry.type === 'LineString' &&
            ((same(f.geometry.coordinates[0], a) && same(f.geometry.coordinates[1], b)) ||
             (same(f.geometry.coordinates[1], a) && same(f.geometry.coordinates[0], b))));
        assert(baseFeature, `No base segment for ${mapName}: ${JSON.stringify([a, b])}`);
        features.push(feature(`route${i}`, baseFeature.type === 'offRouteCrosswalk' ? 'onRouteCrosswalk' : 'onRouteSidewalk',
            [a, b], `On-route ${baseFeature.properties.name[0].toLowerCase()}${baseFeature.properties.name.slice(1)}`));
    }
    for (let i = 1; i < coords.length - 1; i++) {
        const a = coords[i - 1], b = coords[i], c = coords[i + 1];
        const cross = (b[0] - a[0]) * (c[1] - b[1]) - (b[1] - a[1]) * (c[0] - b[0]);
        if (cross) features.push(feature('turn', 'turn', b, cross > 0 ? 'Turn right' : 'Turn left'));
    }
    features.push(feature('start', 'start', coords[0], `Route enters from ${streetName(previous, p)}`),
        feature('end', 'end', coords.at(-1), `Route continues on ${streetName(p, next)}`));
    const intersection = intersectionName(p);
    return document(`${mapName}__${intersection}_route`, intersection, features);
}

// Build everything before changing files, so invalid plans cannot cause partial writes.
const outputs = new Map(), bases = new Map();
for (const x of xs) for (const y of ys) {
    const base = makeBase([x, y]); bases.set(intersectionName([x, y]), base);
    outputs.set(path.join(detailDir, base.metadata.name + '.json'), base);
}
for (const [name, vertices] of Object.entries(routes)) {
    assert(vertices.length === 4);
    for (const p of vertices) assert(xs.includes(p[0]) && ys.includes(p[1]));
    for (let i = 1; i < vertices.length; i++) assert((vertices[i][0] === vertices[i - 1][0]) !== (vertices[i][1] === vertices[i - 1][1]));
    for (let i = 1; i < vertices.length - 1; i++) assert((vertices[i - 1][0] === vertices[i][0]) !== (vertices[i][0] === vertices[i + 1][0]));
    const points = routeIntersections(vertices);
    assert(new Set(points.map(p => p.join(','))).size === points.length, `${name}: repeated intersection`);
    const file = path.join(overviewDir, name + '.json');
    outputs.set(file, makeOverview(JSON.parse(fs.readFileSync(file, 'utf8')), vertices, points));
    for (let i = 1; i < points.length - 1; i++) {
        const doc = makeDetail(name, points[i], points[i - 1], points[i + 1], bases.get(intersectionName(points[i])));
        outputs.set(path.join(detailDir, doc.metadata.name + '.json'), doc);
    }
}
for (const [file, doc] of outputs) write(file, doc);
// Only remove generated route overlays for these maps which are no longer referenced.
for (const file of fs.readdirSync(detailDir)) {
    const full = path.join(detailDir, file);
    if (file.endsWith('_route.json') && Object.hasOwn(routes, file.split('__')[0]) && !outputs.has(full)) fs.unlinkSync(full);
}
console.log(`Updated ${Object.keys(routes).length} overviews, ${bases.size} shared bases, and ${outputs.size - bases.size - Object.keys(routes).length} route overlays.`);
