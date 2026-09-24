// Interactive dependency overview for the /schema "Abhängigkeiten" view: draws
// the focused template and its surroundings as an SVG with d3 (selection for the
// data joins, d3-zoom for pan) — with pan/zoom, fullscreen, a detail sidebar
// (outgoing dependencies + "used by") and a switch between the three drawings in
// components/schema_dependency_layouts.js, which own all geometry. Clicking any
// node refocuses the view on it. The graph payload (aggregated template→target
// edges, reverse edges, cycle markers) is server-rendered into the JSON tag by
// Schema::DependencyGraph — this component carries no schema knowledge.
import { select } from "d3-selection";
import { zoom, zoomIdentity } from "d3-zoom";
import {
	LAYOUTS,
	NODE_H,
	NODE_W,
} from "../components/schema_dependency_layouts.js";

const ZOOM_STEPS = [0.25, 0.33, 0.5, 0.67, 0.8, 1, 1.25, 1.5, 2];
const DEFAULT_VIEW = "radial";
// entries a sidebar list shows before it collapses into a "… (n more)" row — the
// cut and the count of what was cut have to be derived from one number, or the
// row claims a different remainder than the list actually dropped
const SIDEBAR_ENTRIES = 8;
// characters a node title gets inside its box before it is ellipsized; NODE_W at
// the node-title font size
const NODE_TITLE_CHARS = 22;

export default class SchemaDependencyGraph {
	static selector = "[data-schema-dep-graph]";
	static className = "dcjs-schema-dependency-graph";
	// lazy: the graph sits in the hidden "Abhängigkeiten" tab on page load —
	// initialize only once it becomes visible (getBBox()/clientWidth need a
	// rendered element to center the tree, and Firefox throws on hidden SVGs)
	static lazy = true;

	constructor(element) {
		this.element = element;
		const payload = element.querySelector("[data-graph-data]");
		if (!payload) return;

		const data = JSON.parse(payload.textContent);
		this.labels = data.labels;
		this.nodes = new Map(data.nodes.map((node) => [node.id, node]));

		this.canvas = element.querySelector("[data-graph-canvas]");
		this.sidebar = element.querySelector("[data-graph-sidebar]");
		this.rootSelect = element.querySelector("[data-graph-root]");
		this.zoomLevel = element.querySelector("[data-graph-zoom-level]");
		this.truncationHint = element.querySelector("[data-graph-truncation]");

		this.scale = 1;
		this.tx = 0;
		this.ty = 0;
		this.view = DEFAULT_VIEW;
		// the switcher is rendered from SchemaController::GRAPH_VIEWS; a key without
		// a layout here (or a layout nobody offers) is a wiring mistake, not a
		// runtime condition worth handling silently
		for (const view of data.views ?? [])
			if (!LAYOUTS[view])
				console.error(
					`SchemaDependencyGraph: no layout for view "${view}" — check GRAPH_VIEWS against LAYOUTS`,
				);

		// roots: templates with outgoing dependencies, busiest first — the graph
		// opens on the first of them
		this.roots = data.nodes
			.filter((node) => Object.keys(node.deps).length > 0)
			.sort(
				(a, b) =>
					Object.keys(b.deps).length - Object.keys(a.deps).length ||
					a.id.localeCompare(b.id),
			);
		// everything else (external types, templates that are only used) is still
		// reachable by clicking a node, so it belongs into the select as well —
		// otherwise the select keeps showing a template that is not the one drawn
		this.leaves = data.nodes
			.filter((node) => !Object.keys(node.deps).length)
			.sort((a, b) => a.id.localeCompare(b.id));
		if (!this.roots.length) return;

		this.initControls();
		this.focus(this.roots[0].id);
	}

	initControls() {
		this.appendOptions(
			this.roots,
			this.leaves.length ? this.labels.root_with_deps : null,
		);
		this.appendOptions(this.leaves, this.labels.root_without_deps);
		this.rootSelect.addEventListener("change", () =>
			this.focus(this.rootSelect.value),
		);

		for (const button of this.element.querySelectorAll("[data-graph-zoom]"))
			button.addEventListener("click", () =>
				this.zoom(Number.parseInt(button.dataset.graphZoom, 10)),
			);

		this.viewButtons = [...this.element.querySelectorAll("[data-graph-view]")];
		for (const button of this.viewButtons)
			button.addEventListener("click", () =>
				this.switchView(button.dataset.graphView),
			);

		this.element
			.querySelector("[data-graph-fullscreen]")
			?.addEventListener("click", () => {
				if (document.fullscreenElement) document.exitFullscreen();
				else this.element.requestFullscreen?.();
			});

		this.initPan();
		this.initResize();
		this.updateZoomLabel();
	}

	// Fullscreen and window resizing change the canvas box, which the fit depends
	// on — without this the drawing keeps the scale of the previous size. Only the
	// fit is redone, the layout itself does not change.
	initResize() {
		let pending = null;
		const refit = () => {
			clearTimeout(pending);
			pending = setTimeout(() => this.fitToCanvas(this.fitTop), 150);
		};

		this.element.addEventListener("fullscreenchange", refit);
		window.addEventListener("resize", refit);
	}

	// one <option> per node, optionally wrapped in a labelled <optgroup> so the
	// two kinds (sources / only-used types) stay tellable apart
	appendOptions(nodes, groupLabel) {
		if (!nodes.length) return;

		const parent = groupLabel
			? this.rootSelect.appendChild(document.createElement("optgroup"))
			: this.rootSelect;
		if (groupLabel) parent.label = groupLabel;

		for (const node of nodes) {
			const option = document.createElement("option");
			option.value = node.id;
			option.textContent = node.id;
			parent.appendChild(option);
		}
	}

	// drag to pan — d3-zoom writes the transform onto the SVG root group. Only
	// dragging is delegated to the behavior: the zoom level stays on the fixed
	// ZOOM_STEPS ladder driven by the +/− buttons, so wheel/dblclick/pinch
	// zooming stays off (the filter lets drag gestures through only, and never
	// those starting on a node — those are clicks that refocus the graph).
	initPan() {
		this.zoomBehavior = zoom()
			// the canvas box, rather than d3's default (the SVG's own width/height
			// attributes, which are unset here — the SVG is sized in CSS)
			.extent(() => [
				[0, 0],
				[this.canvas.clientWidth, this.canvas.clientHeight],
			])
			.filter(
				(event) =>
					(event.type === "touchstart" ||
						(event.type === "mousedown" && !event.button)) &&
					!event.target.closest("[data-node-id]"),
			)
			.on("start", () => this.canvas.classList.add("is-panning"))
			.on("zoom", (event) => {
				this.tx = event.transform.x;
				this.ty = event.transform.y;
				this.scale = event.transform.k;
				this.viewport?.attr("transform", event.transform);
			})
			.on("end", () => this.canvas.classList.remove("is-panning"));
	}

	// One step along the fixed ladder, anchored on the middle of the canvas: d3's
	// scaleTo keeps the world point under that screen point in place, so the
	// drawing grows out of the center instead of drifting off towards the origin.
	zoom(direction) {
		const index = ZOOM_STEPS.reduce(
			(best, step, i) =>
				Math.abs(step - this.scale) < Math.abs(ZOOM_STEPS[best] - this.scale)
					? i
					: best,
			0,
		);
		const scale =
			ZOOM_STEPS[
				Math.min(Math.max(index + direction, 0), ZOOM_STEPS.length - 1)
			];
		if (scale === this.scale) return;

		const center = [this.canvas.clientWidth / 2, this.canvas.clientHeight / 2];
		this.svg?.call(this.zoomBehavior.scaleTo, scale, center);
		this.updateZoomLabel();
	}

	updateZoomLabel() {
		this.zoomLevel.textContent = `${Math.round(this.scale * 100)}%`;
	}

	// routed through the behavior so its internal state stays in sync with the
	// buttons and the initial fit — the "zoom" handler does the actual painting
	applyTransform() {
		this.svg?.call(
			this.zoomBehavior.transform,
			zoomIdentity.translate(this.tx, this.ty).scale(this.scale),
		);
	}

	focus(id) {
		this.focusId = id;
		this.rootSelect.value = id;
		this.tx = 0;
		this.ty = 0;
		this.render();
		this.select(id);
	}

	// keeps the focused template, only the drawing around it changes — the zoom
	// level does not carry over, every layout is refitted to the canvas
	switchView(view) {
		if (!LAYOUTS[view] || view === this.view) return;
		this.view = view;
		this.scale = 1;
		this.focus(this.focusId);
	}

	// "24 von 61 Knoten · 2 von 3 Ebenen" whenever the drawing is a cut-out, empty
	// when it shows the whole neighborhood
	renderTruncation(truncation) {
		if (!this.truncationHint) return;

		if (!truncation) {
			this.truncationHint.textContent = "";
			return;
		}

		const parts = [];
		if (truncation.shown < truncation.total)
			parts.push(
				this.labels.truncation_nodes
					.replace("%{shown}", truncation.shown)
					.replace("%{total}", truncation.total),
			);
		if (truncation.depth < truncation.max_depth)
			parts.push(
				this.labels.truncation_levels
					.replace("%{depth}", truncation.depth)
					.replace("%{max}", truncation.max_depth),
			);
		this.truncationHint.textContent = parts.join(" · ");
	}

	markActiveView() {
		for (const button of this.viewButtons ?? []) {
			const active = button.dataset.graphView === this.view;
			button.classList.toggle("is-active", active);
			button.setAttribute("aria-pressed", String(active));
		}
	}

	// ---- rendering ---------------------------------------------------------

	render() {
		const { boxes, edges, top, truncation } = LAYOUTS[this.view](
			this.nodes,
			this.focusId,
		);
		this.markActiveView();
		this.renderTruncation(truncation);

		// rebuilt from scratch on every focus or view change — a different node
		// set each time, so there is nothing to update in place
		this.svg = select(this.canvas)
			.selectAll("svg")
			.data([null])
			.join("svg")
			.attr("class", "schema-graph__svg")
			.call(this.zoomBehavior);
		this.svg.selectAll("*").remove();
		this.viewport = this.svg.append("g");

		// edges first so the node boxes paint on top of them
		this.viewport
			.selectAll("path")
			.data(edges)
			.join("path")
			.attr("class", "schema-graph__edge")
			.attr("d", (edge) => edge);

		this.nodeBoxes(this.viewport.selectAll("g").data(boxes).join("g"));

		this.fitToCanvas(top);
	}

	// fit the drawing to the canvas so it isn't fanned out past the viewport —
	// never zoom in past 100%, only ever out. Layouts that pin themselves `top`
	// pixels below the canvas edge are only fitted horizontally, the others are
	// centered in both directions. If the canvas is not rendered (yet), skip
	// fitting/centering — Firefox throws on getBBox() of hidden SVGs.
	fitToCanvas(top) {
		this.fitTop = top;
		this.ty = top ?? 0;
		try {
			const box = this.viewport.node().getBBox();
			const width = this.canvas.clientWidth || 0;
			const height = this.canvas.clientHeight || 0;
			if (width > 0) {
				this.scale = Math.min(
					1,
					(width - 40) / box.width,
					top == null && height > 0 ? (height - 40) / box.height : 1,
				);
				this.updateZoomLabel();
				this.tx = (width - box.width * this.scale) / 2 - box.x * this.scale;
				if (top == null)
					this.ty = (height - box.height * this.scale) / 2 - box.y * this.scale;
			}
		} catch {
			// keep the default transform
		}
		this.applyTransform();
	}

	// fills a selection of (freshly appended) <g> elements with one node box each
	nodeBoxes(selection) {
		selection
			.attr(
				"class",
				({ node }) =>
					`schema-graph__node is-${node?.group || "external"}${node?.circular ? " is-circular" : ""}`,
			)
			.attr("transform", ({ x, y }) => `translate(${x} ${y})`)
			.attr("data-node-id", ({ id }) => id)
			// a node behaves like a button (it refocuses the graph), so it has to be
			// reachable and triggerable by keyboard as well — an SVG <g> is neither
			// focusable nor announced as anything on its own
			.attr("tabindex", 0)
			.attr("role", "button")
			.attr("aria-label", (entry) => this.nodeLabel(entry))
			.on("click", (_event, entry) => this.activate(entry))
			.on("keydown", (event, entry) => {
				if (event.key !== "Enter" && event.key !== " ") return;
				event.preventDefault(); // Space would scroll the page
				this.activate(entry);
			});

		selection
			.append("rect")
			.attr("width", NODE_W)
			.attr("height", NODE_H)
			.attr("rx", 10);

		selection
			.append("circle")
			.attr("class", "schema-graph__node-dot")
			.attr("cx", 18)
			.attr("cy", NODE_H / 2)
			.attr("r", 5);

		selection
			.append("text")
			.attr("class", "schema-graph__node-title")
			.attr("x", 34)
			.attr("y", 24)
			.text(({ id }) => this.truncate(id, NODE_TITLE_CHARS));

		selection
			.append("text")
			.attr("class", "schema-graph__node-sub")
			.attr("x", 34)
			.attr("y", 42)
			.text(({ node }) =>
				this.depsLabel(node ? Object.keys(node.deps).length : 0),
			);
	}

	// clicking or pressing Enter/Space on a node: known nodes refocus the drawing,
	// external ones can only be shown in the sidebar
	activate(entry) {
		if (entry.node) this.focus(entry.id);
		else this.select(entry.id);
	}

	// what a screen reader announces for a node box: its name, its group and how
	// many dependencies it has — the same three things the box shows visually
	nodeLabel({ id, node }) {
		const group = this.labels[node?.group ?? "external"] ?? "";
		return [id, group, this.depsLabel(node ? Object.keys(node.deps).length : 0)]
			.filter(Boolean)
			.join(", ");
	}

	truncate(text, max) {
		return text.length > max ? `${text.slice(0, max - 1)}…` : text;
	}

	depsLabel(count) {
		const template =
			count === 1
				? this.labels.dependencies_one
				: this.labels.dependencies_other;
		return template.replace("%{count}", count);
	}

	// ---- sidebar -----------------------------------------------------------

	select(id) {
		this.selectedId = id;
		for (const el of this.canvas.querySelectorAll("[data-node-id]"))
			el.classList.toggle("is-selected", el.dataset.nodeId === id);
		this.renderSidebar(
			this.nodes.get(id) || { id, group: "external", deps: {}, used_by: {} },
		);
	}

	sidebarList(title, entries, linkable) {
		if (!entries.length) return "";
		const items = entries
			.slice(0, SIDEBAR_ENTRIES)
			.map(([target, count]) => {
				const targetNode = this.nodes.get(target);
				const name =
					linkable && targetNode?.path
						? `<a href="${this.escape(targetNode.path)}">${this.escape(target)}</a>`
						: this.escape(target);
				return `<li><span class="schema-rel__dot schema-rel__dot--${this.dotClass(targetNode)}"></span><span class="schema-graph__side-name">${name}</span><span class="schema-graph__side-count">${count}</span></li>`;
			})
			.join("");
		const more =
			entries.length > SIDEBAR_ENTRIES
				? `<li class="schema-graph__side-more">${this.escape(this.labels.more)} (${entries.length - SIDEBAR_ENTRIES})</li>`
				: "";
		return `
			<h4 class="schema-graph__side-heading">${this.escape(title)}<span class="schema-graph__side-badge">${entries.reduce((sum, [, c]) => sum + c, 0)}</span></h4>
			<ul class="schema-graph__side-list">${items}${more}</ul>`;
	}

	// The payload already carries the group (Schema.node_group, one of
	// Schema::GROUPS), and that name IS the CSS modifier — no second mapping here.
	// There used to be one, and it drifted: it answered "shared" for external
	// nodes while the stylesheet had been renamed to `--external`, so the sidebar
	// dot of an external type silently lost its colour and no longer matched the
	// legend right above it. A node the payload does not know (only reachable as
	// an edge target) is external by definition.
	dotClass(node) {
		return node?.group || "external";
	}

	renderSidebar(node) {
		const deps = Object.entries(node.deps || {});
		const usedBy = Object.entries(node.used_by || {});
		this.sidebar.innerHTML = `
			<div class="schema-graph__side-head">
				<span class="schema-rel__dot schema-rel__dot--${this.dotClass(node)}"></span>
				<strong>${this.escape(node.id)}</strong>
				<span class="schema-graph__side-group is-${node.group}">${this.escape(this.labels[node.group] || node.group)}</span>
				${node.circular ? `<span class="schema-graph__side-circular">${this.escape(this.labels.circular)}</span>` : ""}
			</div>
			${this.sidebarList(this.labels.dependencies, deps, true)}
			${this.sidebarList(this.labels.used_by, usedBy, true)}`;
	}

	escape(text) {
		const div = document.createElement("div");
		div.textContent = String(text);
		return div.innerHTML;
	}
}
