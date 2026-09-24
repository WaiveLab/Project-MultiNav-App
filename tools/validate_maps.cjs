// Validate the files the app loads, independently of the generation plan.
// node tools/validate_maps.cjs
const fs = require('node:fs');
const path = require('node:path');
const assert = require('node:assert/strict');
const root = path.resolve(__dirname, '../Project MultiNav App/Maps');
const detailDir = path.join(root, 'intersection_views');
const xs = [150, 450, 750], ys = [200, 600, 1000, 1400];
const streets = ['Aspen Street', 'Birch Street', 'Cedar Street'];
const avenues = ['Summit Avenue', 'Garden Avenue', 'Market Avenue', 'Harbor Avenue'];
const same = (a, b) => JSON.stringify(a) === JSON.stringify(b);
const key = p => p.join(',');
const grid = xs.flatMap(x => ys.map(y => [x, y]));
const nameAt = ([x, y]) => `Intersection Between ${streets[xs.indexOf(x)]} and ${avenues[ys.indexOf(y)]}`;
const between = (p, a, b) => (a[0] === b[0] ? p[0] === a[0] : p[1] === a[1]) &&
    p[0] >= Math.min(a[0], b[0]) && p[0] <= Math.max(a[0], b[0]) &&
    p[1] >= Math.min(a[1], b[1]) && p[1] <= Math.max(a[1], b[1]);
function load(file) {
    const doc = JSON.parse(fs.readFileSync(file, 'utf8'));
    assert.equal(doc.metadata.name, path.basename(file, '.json'), file);
    assert.equal(new Set(doc.features.map(f => f.id)).size, doc.features.length, `${file}: duplicate IDs`);
    for (const f of doc.features) {
        const coords = f.geometry.type === 'Point' ? [f.geometry.coordinates] : f.geometry.coordinates;
        for (const [x, y] of coords) assert(Number.isFinite(x) && Number.isFinite(y) && x >= 0 && y >= 0 &&
            x <= doc.bounds.width && y <= doc.bounds.height, `${file}: out of bounds`);
        if (f.geometry.type === 'LineString') for (let i = 1; i < coords.length; i++) {
            assert((coords[i][0] === coords[i - 1][0]) !== (coords[i][1] === coords[i - 1][1]), `${file}: zero-length/diagonal segment`);
        }
    }
    return doc;
}
function endpoint(doc, type) {
    const found = doc.features.filter(f => f.type === type);
    assert.equal(found.length, 1, `${doc.metadata.name}: ${type} count`);
    return found[0].geometry.coordinates;
}
function trace(doc, types) {
    const remaining = doc.features.filter(f => types.includes(f.type)).map(f => f.geometry.coordinates);
    const start = endpoint(doc, 'start'), end = endpoint(doc, 'end'), points = [start];
    while (remaining.length) {
        const candidates = remaining.map((line, i) => ({line, i})).filter(({line}) => same(line[0], points.at(-1)) || same(line.at(-1), points.at(-1)));
        assert.equal(candidates.length, 1, `${doc.metadata.name}: disconnected or branching route`);
        const {line, i} = candidates[0];
        const ordered = same(line[0], points.at(-1)) ? line : [...line].reverse();
        points.push(...ordered.slice(1)); remaining.splice(i, 1);
    }
    assert.deepEqual(points.at(-1), end, `${doc.metadata.name}: route misses end`);
    assert.equal(new Set(points.map(key)).size, points.length, `${doc.metadata.name}: route revisits a point`);
    return points;
}
function bends(points) {
    const result = [];
    for (let i = 1; i < points.length - 1; i++) {
        const [a, b, c] = points.slice(i - 1, i + 2);
        const cross = (b[0] - a[0]) * (c[1] - b[1]) - (b[1] - a[1]) * (c[0] - b[0]);
        if (cross) result.push({point: b, direction: cross > 0 ? 'Turn right' : 'Turn left'});
    }
    return result;
}
const expectedRoutes = new Set();
const files = fs.readdirSync(path.join(root, 'overviews')).filter(f => f.endsWith('.json'));
assert.equal(files.length, 18);
for (const file of files) {
    const doc = load(path.join(root, 'overviews', file)), label = doc.metadata.name;
    const points = trace(doc, ['onRoute']);
    const turns = bends(points);
    assert.equal(turns.length, 2, `${label}: must have exactly two turns`);
    assert.equal(doc.features.filter(f => f.type === 'onRoute').length, 3, `${label}: must have three legs`);
    const start = endpoint(doc, 'start'), end = endpoint(doc, 'end');
    assert(grid.some(p => same(p, start)) && grid.some(p => same(p, end)), `${label}: endpoints must be intersections`);
    assert(doc.features.find(f => f.type === 'start').properties.name.includes(nameAt(start)));
    assert(doc.features.find(f => f.type === 'end').properties.name.includes(nameAt(end)));
    const markers = doc.features.filter(f => ['start', 'end', 'onRouteIntersection', 'offRouteIntersection'].includes(f.type));
    assert.equal(markers.length, 12);
    const expanded = [];
    for (let i = 1; i < points.length; i++) {
        const a = points[i - 1], b = points[i];
        const local = grid.filter(p => between(p, a, b)).sort((p, q) => Math.hypot(p[0] - a[0], p[1] - a[1]) - Math.hypot(q[0] - a[0], q[1] - a[1]));
        expanded.push(...local.filter(p => !expanded.length || !same(p, expanded.at(-1))));
    }
    assert.equal(new Set(expanded.map(key)).size, expanded.length, `${label}: intersecting route legs`);
    for (const p of grid) {
        const found = markers.filter(f => same(f.geometry.coordinates, p));
        assert.equal(found.length, 1, `${label}: overlapping/missing intersection markers at ${p}`);
        const expectedType = same(p, start) ? 'start' : same(p, end) ? 'end' : expanded.some(q => same(q, p)) ? 'onRouteIntersection' : 'offRouteIntersection';
        assert.equal(found[0].type, expectedType, `${label}: wrong marker at ${p}`);
        if (expectedType.endsWith('Intersection')) assert.equal(found[0].properties.name, nameAt(p));
    }
    // Every elementary road edge appears exactly once, with the correct type.
    const lines = doc.features.filter(f => ['onRoute', 'offRoute'].includes(f.type));
    for (const f of lines) for (const p of f.geometry.coordinates) assert(grid.some(q => same(q, p)));
    for (const a of grid) for (const b of grid) {
        if (!((a[0] === b[0] && b[1] - a[1] === 400) || (a[1] === b[1] && b[0] - a[0] === 300))) continue;
        const matching = lines.filter(f => between(a, ...f.geometry.coordinates) && between(b, ...f.geometry.coordinates));
        assert.equal(matching.length, 1, `${label}: gap/overlap on street ${a} to ${b}`);
        const used = points.slice(1).some((p, i) => between(a, points[i], p) && between(b, points[i], p));
        assert.equal(matching[0].type, used ? 'onRoute' : 'offRoute');
    }
    for (let i = 1; i < expanded.length - 1; i++) {
        const p = expanded[i], name = nameAt(p), resource = `${label}__${name}_route.json`;
        expectedRoutes.add(resource);
        const base = load(path.join(detailDir, name + '.json'));
        const detail = load(path.join(detailDir, resource));
        assert.deepEqual(base.bounds, detail.bounds);
        assert.equal(detail.metadata.buildingName, name);
        const local = trace(detail, ['onRouteSidewalk', 'onRouteCrosswalk']);
        const localTurns = bends(local), expectedTurn = turns.find(t => same(t.point, p));
        assert.equal(localTurns.length, expectedTurn ? 1 : 0, `${resource}: wrong movement`);
        const turnMarkers = detail.features.filter(f => f.type === 'turn');
        assert.equal(turnMarkers.length, localTurns.length);
        if (expectedTurn) {
            assert.equal(localTurns[0].direction, expectedTurn.direction);
            assert.equal(turnMarkers[0].properties.name, expectedTurn.direction);
            assert.deepEqual(turnMarkers[0].geometry.coordinates, localTurns[0].point);
        }
        const boundary = q => q[1] === 90 ? 'N' : q[0] === 840 ? 'E' : q[1] === 1510 ? 'S' : q[0] === 60 ? 'W' : null;
        const arm = q => q[0] < p[0] ? 'W' : q[0] > p[0] ? 'E' : q[1] < p[1] ? 'N' : 'S';
        assert.equal(boundary(local[0]), arm(expanded[i - 1]), `${resource}: wrong entry arm`);
        assert.equal(boundary(local.at(-1)), arm(expanded[i + 1]), `${resource}: wrong exit arm`);
        for (const f of detail.features.filter(f => f.geometry.type === 'LineString')) {
            const type = f.type === 'onRouteSidewalk' ? 'offRouteSidewalk' : 'offRouteCrosswalk';
            assert(base.features.some(b => b.type === type && (same(b.geometry.coordinates, f.geometry.coordinates) ||
                same([...b.geometry.coordinates].reverse(), f.geometry.coordinates))), `${resource}: overlay leaves base sidewalk/crosswalk`);
        }
    }
}
const actualRoutes = fs.readdirSync(detailDir).filter(f => f.endsWith('_route.json'));
assert.deepEqual(new Set(actualRoutes), expectedRoutes, 'Missing or obsolete route overlays');
for (const p of grid) {
    const base = load(path.join(detailDir, nameAt(p) + '.json'));
    const roads = base.features.filter(f => f.type === 'street');
    assert.equal(roads.length, 2);
    const armCount = (p[0] > 150) + (p[0] < 750) + (p[1] > 200) + (p[1] < 1400);
    assert.equal(base.features.filter(f => f.type === 'offRouteCrosswalk').length, armCount);
    assert.equal(base.features.filter(f => f.type === 'intersectionCenter').length, 1);
    assert.deepEqual(roads.find(f => f.properties.name === streets[xs.indexOf(p[0])]).geometry.coordinates,
        [[450, p[1] > 200 ? 90 : 800], [450, p[1] < 1400 ? 1510 : 800]]);
    assert.deepEqual(roads.find(f => f.properties.name === avenues[ys.indexOf(p[1])]).geometry.coordinates,
        [[p[0] > 150 ? 60 : 450, 800], [p[0] < 750 ? 840 : 450, 800]]);
}
console.log(`Validated ${files.length} maps: exactly two turns, intersection endpoints, complete road coverage, 12 shared bases, and ${actualRoutes.length} consistent route overlays.`);
