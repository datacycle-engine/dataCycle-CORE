// Unit tests for the /schema dependency graph layouts (no DOM involved): the
// force-directed network and the two tree drawings. Rendering
// itself (SVG/DOM) is not covered here — see the docker skill for running the
// component in a browser to verify visual output.
import assert from "node:assert/strict";
import { test } from "node:test";
import {
	LAYOUTS,
	NODE_H,
	NODE_W,
	networkLayout,
	networkNodeIds,
	radialLayout,
	treeLayout,
} from "../../app/assets/javascripts/components/schema_dependency_layouts.js";

const nodes = (list) => new Map(list.map((node) => [node.id, node]));

// a chain A → B → C → D → E, deep enough to run into the depth cap
const CHAIN = nodes([
	{ id: "A", deps: { B: 1 }, used_by: {} },
	{ id: "B", deps: { C: 1 }, used_by: { A: 1 } },
	{ id: "C", deps: { D: 1 }, used_by: { B: 1 } },
	{ id: "D", deps: { E: 1 }, used_by: { C: 1 } },
	{ id: "E", deps: {}, used_by: { D: 1 } },
]);

const ids = (layout) => layout.boxes.map((entry) => entry.id);

// a bushy graph: `deps` dependencies, each with `subDeps` of their own
function bushy(deps, subDeps) {
	return nodes([
		{
			id: "A",
			deps: Object.fromEntries(
				Array.from({ length: deps }, (_value, i) => [`B${i}`, 1]),
			),
			used_by: {},
		},
		...Array.from({ length: deps }, (_value, i) => ({
			id: `B${i}`,
			deps: Object.fromEntries(
				Array.from({ length: subDeps }, (_v, j) => [`C${i}-${j}`, 1]),
			),
			used_by: { A: 1 },
		})),
	]);
}

// 1 + 12 + 24 boxes — still inside the box budget, so both levels are drawn
const BUSHY = bushy(12, 2);

function assertNoOverlap(layout, label) {
	for (const [i, a] of layout.boxes.entries())
		for (const b of layout.boxes.slice(i + 1))
			assert.ok(
				Math.abs(a.x - b.x) >= NODE_W || Math.abs(a.y - b.y) >= NODE_H,
				`${label}: ${a.id} overlaps ${b.id}`,
			);
}

test("networkNodeIds: walks both directions — dependencies and dependents", () => {
	const graph = nodes([
		{ id: "A", deps: { B: 1 }, used_by: {} },
		{ id: "B", deps: {}, used_by: { A: 1, C: 1 } },
		{ id: "C", deps: { B: 1 }, used_by: {} },
	]);

	// from B: up to its dependent A and C, and no further
	assert.deepEqual(networkNodeIds(graph, "B").sort(), ["A", "B", "C"]);
});

test("networkNodeIds: reaches two hops out and lists every node once", () => {
	// A → B → C → D → E: two hops from A are B and C
	assert.deepEqual(networkNodeIds(CHAIN, "A").sort(), ["A", "B", "C"]);
	// from C both directions: B and D at one hop, A and E at two
	assert.deepEqual(networkNodeIds(CHAIN, "C").sort(), ["A", "B", "C", "D", "E"]);
});

test("networkNodeIds: stops at the box budget", () => {
	const ids = networkNodeIds(bushy(20, 10), "A");

	assert.equal(ids.length, 40);
	assert.equal(new Set(ids).size, 40, "no node may be collected twice");
	assert.equal(ids[0], "A", "the focused node comes first");
});

test("networkNodeIds: an unknown (external) node has no surroundings", () => {
	assert.deepEqual(networkNodeIds(nodes([]), "Unknown"), ["Unknown"]);
});

test("networkLayout: pins the focused node to the middle and draws one edge per dependency", () => {
	const layout = networkLayout(CHAIN, "C");

	assert.deepEqual(ids(layout).sort(), ["A", "B", "C", "D", "E"]);
	const focused = layout.boxes.find((entry) => entry.id === "C");
	assert.equal(focused.x, -NODE_W / 2);
	assert.equal(focused.y, -NODE_H / 2);
	// A→B, B→C, C→D, D→E all inside the collected set
	assert.equal(layout.edges.length, 4);
	for (const edge of layout.edges)
		assert.match(edge, /^M-?[\d.]+,-?[\d.]+L-?[\d.]+,-?[\d.]+$/, "edges are straight lines");
	// centered in both directions rather than pinned to the top edge
	assert.equal(layout.top, undefined);
});

test("networkLayout: keeps a cycle as a cycle instead of cutting it", () => {
	const cycle = nodes([
		{ id: "A", deps: { B: 1 }, used_by: { B: 1 } },
		{ id: "B", deps: { A: 1 }, used_by: { A: 1 } },
	]);

	const layout = networkLayout(cycle, "A");

	assert.deepEqual(ids(layout).sort(), ["A", "B"]);
	assert.equal(layout.edges.length, 2, "both directions are drawn");
});

test("networkLayout: a self-reference does not become an edge to itself", () => {
	const layout = networkLayout(
		nodes([{ id: "A", deps: { A: 1 }, used_by: { A: 1 } }]),
		"A",
	);

	assert.deepEqual(ids(layout), ["A"]);
	assert.deepEqual(layout.edges, []);
});

test("networkLayout: the simulation settles without overlapping node boxes", () => {
	assertNoOverlap(networkLayout(BUSHY, "A"), "network");
	assertNoOverlap(networkLayout(CHAIN, "C"), "network (chain)");
});

test("treeLayout: follows the dependencies over several hops, one edge per level", () => {
	const layout = treeLayout(CHAIN, "A");

	// depth is capped at three levels below the root, so E is cut off
	assert.deepEqual(ids(layout), ["A", "B", "C", "D"]);
	assert.equal(layout.edges.length, 3);
	assert.deepEqual(
		layout.boxes.map((entry) => entry.y),
		[0, NODE_H + 72, 2 * (NODE_H + 72), 3 * (NODE_H + 72)],
	);
	assert.equal(layout.top, 24);
});

test("treeLayout: cuts cycles instead of recursing forever", () => {
	const cycle = nodes([
		{ id: "A", deps: { B: 1 }, used_by: { B: 1 } },
		{ id: "B", deps: { A: 1 }, used_by: { A: 1 } },
	]);

	const layout = treeLayout(cycle, "A");

	assert.deepEqual(ids(layout), ["A", "B"]);
	assert.equal(layout.edges.length, 1);
});

test("treeLayout: a self-referencing node does not become its own child", () => {
	const layout = treeLayout(
		nodes([{ id: "A", deps: { A: 1 }, used_by: { A: 1 } }]),
		"A",
	);

	assert.deepEqual(ids(layout), ["A"]);
	assert.deepEqual(layout.edges, []);
});

test("treeLayout: keeps unknown (external) targets as leaf boxes without a node", () => {
	const layout = treeLayout(
		nodes([{ id: "A", deps: { Unknown: 1 }, used_by: {} }]),
		"A",
	);

	assert.deepEqual(ids(layout), ["A", "Unknown"]);
	assert.equal(layout.boxes[1].node, undefined);
});

test("radialLayout: rings the dependencies around the focused node, one level shallower than the tree", () => {
	const layout = radialLayout(CHAIN, "A");

	// two rings instead of the tree's three, so D is cut off here
	assert.deepEqual(ids(layout).sort(), ["A", "B", "C"]);
	assert.equal(layout.edges.length, 2);
	// the focused node is the center of the rings
	const root = layout.boxes.find((entry) => entry.id === "A");
	assert.equal(root.x, -NODE_W / 2);
	assert.equal(root.y, -NODE_H / 2);
	for (const entry of layout.boxes.filter((box) => box.id !== "A"))
		assert.ok(
			Math.hypot(entry.x + NODE_W / 2, entry.y + NODE_H / 2) > 0,
			`${entry.id} must sit off center`,
		);
	// centered in both directions rather than pinned to the top edge
	assert.equal(layout.top, undefined);
});

test("treeLayout: node boxes never overlap, even for a bushy graph", () => {
	const layout = treeLayout(BUSHY, "A");

	assert.equal(layout.boxes.length, 1 + 12 + 24);
	assertNoOverlap(layout, "tree");
});

test("treeLayout: drops a level once a drawing would blow past the box budget", () => {
	// 1 + 20 + 200 boxes at two levels, so only the direct dependencies are drawn
	const layout = treeLayout(bushy(20, 10), "A");

	assert.equal(layout.boxes.length, 21);
	assert.deepEqual(
		layout.boxes.map((entry) => entry.y),
		Array.from({ length: 21 }, (_value, i) => (i ? NODE_H + 72 : 0)),
	);
});

// ---- truncation: a cut-out drawing has to say so ------------------------

test("every layout reports no truncation for a neighborhood that fits", () => {
	for (const [view, layout] of Object.entries(LAYOUTS))
		assert.equal(layout(CHAIN, "A").truncation, null, view);
});

test("treeLayout: truncation reports the dropped level and the boxes left out", () => {
	const { truncation } = treeLayout(bushy(20, 10), "A");

	assert.equal(truncation.shown, 21);
	assert.equal(truncation.total, 1 + 20 + 200);
	assert.equal(truncation.depth, 1, "one level instead of the configured three");
	assert.equal(truncation.max_depth, 3);
});

test("radialLayout: truncation counts against its own (shallower) depth", () => {
	const { truncation } = radialLayout(bushy(20, 10), "A");

	assert.equal(truncation.depth, 1);
	assert.equal(truncation.max_depth, 2, "radial is configured one level shallower");
	assert.ok(truncation.shown < truncation.total);
});

test("networkLayout: truncation counts nodes, never levels — the network drops no hop", () => {
	const { boxes, truncation } = networkLayout(bushy(20, 10), "A");

	assert.equal(truncation.shown, boxes.length);
	assert.ok(
		truncation.total > truncation.shown,
		"the unbudgeted walk must reach more nodes",
	);
	assert.equal(truncation.depth, truncation.max_depth);
});

test("networkNodeIds: an explicit budget overrides the default", () => {
	assert.equal(networkNodeIds(bushy(20, 10), "A", 5).length, 5);
	assert.ok(
		networkNodeIds(bushy(20, 10), "A", Number.POSITIVE_INFINITY).length > 40,
		"without a budget the whole two-hop neighborhood is collected",
	);
});

test("networkNodeIds: cuts the weakly linked neighbors, not the ones that come last", () => {
	// D is referenced three times, B once — with a budget of 2 only the focused
	// node and D may survive, whatever order the payload lists them in
	const weighted = nodes([
		{ id: "A", deps: { B: 1, C: 1, D: 3 }, used_by: {} },
		{ id: "B", deps: {}, used_by: { A: 1 } },
		{ id: "C", deps: {}, used_by: { A: 1 } },
		{ id: "D", deps: {}, used_by: { A: 3 } },
	]);

	assert.deepEqual(networkNodeIds(weighted, "A", 2), ["A", "D"]);
});

test("radialLayout: rings are spaced so that node boxes never overlap", () => {
	assertNoOverlap(radialLayout(BUSHY, "A"), "radial");
	// the tight case is a lone ring of dependencies: a box placed horizontally
	// next to the focused node needs a full box width of clearance
	assertNoOverlap(
		radialLayout(nodes([{ id: "A", deps: { B: 1, C: 1 }, used_by: {} }]), "A"),
		"radial (single ring)",
	);
});

test("radialLayout: a node without dependencies draws just itself", () => {
	const layout = radialLayout(nodes([{ id: "A", deps: {}, used_by: {} }]), "A");

	assert.deepEqual(ids(layout), ["A"]);
	assert.deepEqual(layout.edges, []);
});
