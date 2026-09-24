// Layouts for the /schema dependency graph (see
// schema/dependency_graph.js): pure functions that turn
// the server-rendered dependency payload into positioned node boxes and SVG
// edge paths. Each layout takes the node map plus the focused id and returns
// `{ boxes, edges, top }`; `top` pins the drawing that many pixels below the
// canvas top edge, leaving it out centers the drawing vertically instead.
// Nothing here touches the DOM, so every layout is unit-testable.
import {
	forceCollide,
	forceLink,
	forceManyBody,
	forceSimulation,
	forceX,
	forceY,
} from "d3-force";
import { hierarchy, tree } from "d3-hierarchy";
import { path } from "d3-path";
import { linkRadial } from "d3-shape";

export const NODE_W = 200;
export const NODE_H = 56;
const GAP_X = 24;
const GAP_Y = 72;
// edges stop this far short of the child's top edge, so the curve does not run
// under the node's rounded corner
const EDGE_GAP = 5;
// depth cap for the tree views: the full dependency closure of a busy template
// runs into hundreds of nodes — three levels stay readable
const TREE_DEPTH = 3;
// the radial view stays one level shallower: its outermost ring has to hold
// every node of that level side by side, and three levels blow the circle up far
// past anything readable
const RADIAL_DEPTH = 2;
// smallest distance between two node boxes in the radial view — a full box
// width, since boxes sitting side by side horizontally are the tight case
const RADIAL_RING = NODE_W + GAP_X;
// node budget for every drawing: beyond this it only fits the canvas at an
// unreadable zoom level, so the trees drop a level and the network stops
// expanding
const MAX_BOXES = 40;
// how far out the network view walks from the focused node, in both directions
const NETWORK_HOPS = 2;
// resting length of a network edge, and the clearance the collision force keeps
// between two node centers: above √(NODE_W² + NODE_H²), so boxes cannot overlap
// whatever angle they settle at
const NETWORK_LINK = 300;
const NETWORK_CLEARANCE = Math.hypot(NODE_W, NODE_H) / 2 + 8;
// ticks to run the simulation for — the drawing is static SVG, so it is run to
// rest in one go instead of animating
const NETWORK_TICKS = 400;

function box(nodes, id, x, y) {
	return { id, node: nodes.get(id), x, y };
}

// What a drawing had to leave out, or null when it shows everything. Both budgets
// (node count and, for the trees, depth) cut silently otherwise, and a cut
// drawing is indistinguishable from a complete one — which is exactly what makes
// the three views look like they contradict each other.
function truncation(shown, total, depth, maxDepth) {
	if (shown >= total && depth >= maxDepth) return null;

	return { shown, total, depth, max_depth: maxDepth };
}

// vertical bezier from the bottom edge of the parent box to the top edge of the
// child box, both control points on the row gap's midline
function verticalEdge(parent, child) {
	const x1 = parent.x + NODE_W / 2;
	const y1 = parent.y + NODE_H;
	const x2 = child.x + NODE_W / 2;
	const mid = (y1 + child.y) / 2;
	const curve = path();
	curve.moveTo(x1, y1);
	curve.bezierCurveTo(x1, mid, x2, mid, x2, child.y - EDGE_GAP);
	return curve.toString();
}

// ---- network (force-directed, both directions) ----------------------------

// Walks NETWORK_HOPS out from the focused node, following dependencies AND
// dependents, until the box budget is used up. Unlike the tree views this is not
// a hierarchy: a node reached over several routes is still drawn once, and
// cycles stay visible as cycles.
export function networkNodeIds(nodes, id, max = MAX_BOXES) {
	const collected = [id];
	let frontier = [id];

	for (let hop = 0; hop < NETWORK_HOPS; hop++) {
		const next = [];
		for (const currentId of frontier) {
			const node = nodes.get(currentId);
			if (!node) continue;
			// strongest connections first, so hitting the budget drops the weakly
			// linked neighbors rather than whichever happen to come last
			const neighbors = [
				...Object.entries(node.deps),
				...Object.entries(node.used_by ?? {}),
			]
				.sort((a, b) => b[1] - a[1] || a[0].localeCompare(b[0]))
				.map(([neighborId]) => neighborId);
			for (const neighborId of neighbors) {
				if (collected.length >= max) return collected;
				if (collected.includes(neighborId)) continue;
				collected.push(neighborId);
				next.push(neighborId);
			}
		}
		frontier = next;
	}
	return collected;
}

// straight center-to-center line — the network's edges are undirected springs,
// not the parent-to-child curves of the tree views
function straightEdge(source, target) {
	const line = path();
	line.moveTo(source.x, source.y);
	line.lineTo(target.x, target.y);
	return line.toString();
}

export function networkLayout(nodes, id) {
	const ids = networkNodeIds(nodes, id);
	// what the same walk collects without a budget, for the truncation hint
	const total = networkNodeIds(nodes, id, Number.POSITIVE_INFINITY).length;
	const simNodes = ids.map((nodeId) => ({ id: nodeId }));
	const byId = new Map(simNodes.map((entry) => [entry.id, entry]));
	// the focused node is pinned to the middle, everything else settles around it
	Object.assign(byId.get(id), { fx: 0, fy: 0 });

	const links = [];
	for (const entry of simNodes)
		for (const targetId of Object.keys(nodes.get(entry.id)?.deps ?? {})) {
			if (targetId === entry.id || !byId.has(targetId)) continue;
			links.push({ source: entry, target: byId.get(targetId) });
		}

	forceSimulation(simNodes)
		.force("link", forceLink(links).distance(NETWORK_LINK).strength(0.4))
		.force("charge", forceManyBody().strength(-2400).distanceMax(2000))
		.force("collide", forceCollide(NETWORK_CLEARANCE).iterations(6))
		// a light pull towards the middle keeps loose ends from drifting off
		.force("x", forceX().strength(0.05))
		.force("y", forceY().strength(0.06))
		.stop()
		.tick(NETWORK_TICKS);

	return {
		boxes: simNodes.map((entry) =>
			box(nodes, entry.id, entry.x - NODE_W / 2, entry.y - NODE_H / 2),
		),
		edges: links.map(({ source, target }) => straightEdge(source, target)),
		// the network never drops a hop, it only stops collecting
		truncation: truncation(ids.length, total, NETWORK_HOPS, NETWORK_HOPS),
	};
}

// ---- tree views (several hops of outgoing dependencies) -------------------

// Outgoing dependencies as a d3-hierarchy datum, cut off at `maxDepth` levels
// and wherever a node repeats on its own path — the dependency graph has
// cycles, a hierarchy must not.
function dependencyTree(nodes, id, maxDepth, ancestors = []) {
	const node = nodes.get(id);
	const leaf = !node || ancestors.length >= maxDepth;
	return {
		id,
		children: leaf
			? []
			: Object.keys(node.deps)
					.filter((childId) => childId !== id && !ancestors.includes(childId))
					.map((childId) =>
						dependencyTree(nodes, childId, maxDepth, [...ancestors, id]),
					),
	};
}

// Busy templates fan out into hundreds of nodes, which the canvas can only show
// at a zoom level where no label is legible any more. Drop a level (down to a
// single hop) until the drawing stays within MAX_BOXES.
function boundedTree(nodes, id, maxDepth) {
	const full = hierarchy(dependencyTree(nodes, id, maxDepth));
	let root = full;
	let depth = maxDepth;

	while (depth > 1 && root.descendants().length > MAX_BOXES) {
		depth -= 1;
		root = hierarchy(dependencyTree(nodes, id, depth));
	}

	return {
		root,
		truncation: truncation(
			root.descendants().length,
			full.descendants().length,
			depth,
			maxDepth,
		),
	};
}

export function treeLayout(nodes, id) {
	const bounded = boundedTree(nodes, id, TREE_DEPTH);
	const root = tree().nodeSize([NODE_W + GAP_X, NODE_H + GAP_Y])(bounded.root);

	const boxes = new Map(
		root
			.descendants()
			.map((entry) => [
				entry,
				box(nodes, entry.data.id, entry.x - NODE_W / 2, entry.y),
			]),
	);

	return {
		boxes: [...boxes.values()],
		edges: root
			.links()
			.map(({ source, target }) =>
				verticalEdge(boxes.get(source), boxes.get(target)),
			),
		top: 24,
		truncation: bounded.truncation,
	};
}

// Scale factor for a layout run on the unit circle: blows the rings up until
// every pair of neighbors keeps RADIAL_RING apart — between the rings, and along
// each ring, where the angular gaps d3 hands out decide how wide the ring has to
// be. Without this, a ring with many nodes crams its boxes into each other.
function radialRadius(root) {
	const rings = new Map();
	root.each((entry) => {
		if (!rings.has(entry.depth)) rings.set(entry.depth, []);
		rings.get(entry.depth).push(entry.x);
	});

	const depth = root.height || 1;
	let radius = depth * RADIAL_RING;
	for (const [ring, angles] of rings) {
		if (!ring || angles.length < 2) continue;
		angles.sort((a, b) => a - b);
		const gap = Math.min(
			...angles.slice(1).map((angle, i) => angle - angles[i]),
			// the wrap-around gap between the last and the first node
			2 * Math.PI - (angles.at(-1) - angles[0]),
		);
		// arc length at this ring must cover a whole box: gap * radius_ring
		radius = Math.max(radius, (RADIAL_RING * depth) / (gap * ring));
	}
	return radius;
}

export function radialLayout(nodes, id) {
	const { root, truncation: cut } = boundedTree(nodes, id, RADIAL_DEPTH);
	// laid out on the unit circle first, so the radius can be derived from the
	// angles d3 assigned and then applied to every ring
	tree()
		.size([2 * Math.PI, 1])
		.separation((a, b) => (a.parent === b.parent ? 1 : 2))(root);
	const radius = radialRadius(root);

	const boxes = root.descendants().map((entry) => {
		// d3's radial convention: the angle runs clockwise from 12 o'clock
		const angle = entry.x - Math.PI / 2;
		return box(
			nodes,
			entry.data.id,
			entry.y * radius * Math.cos(angle) - NODE_W / 2,
			entry.y * radius * Math.sin(angle) - NODE_H / 2,
		);
	});

	const link = linkRadial()
		.angle((entry) => entry.x)
		.radius((entry) => entry.y * radius);

	return { boxes, edges: root.links().map(link), truncation: cut };
}

export const LAYOUTS = {
	network: networkLayout,
	tree: treeLayout,
	radial: radialLayout,
};
