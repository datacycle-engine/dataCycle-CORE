// Unit tests for the DOM-free helpers of SchemaDependencyGraph: node label
// formatting and the legend dot classes. Layout math lives in (and is tested
// with) components/schema_dependency_layouts.js; rendering itself is not covered
// here — see the docker skill for running the component in a browser.
import assert from "node:assert/strict";
import { test } from "node:test";
import SchemaDependencyGraph from "../../app/assets/javascripts/schema/dependency_graph.js";

// Builds an instance without going through the DOM-dependent constructor —
// truncate/dotClass need nothing, depsLabel only `labels`.
function component(labels) {
	const instance = Object.create(SchemaDependencyGraph.prototype);
	if (labels) instance.labels = labels;
	return instance;
}

// document.createElement stand-in: appendOptions only sets `label`/`value`/
// `textContent` and appends, so a plain object per element is enough.
globalThis.document ??= {
	createElement: (tag) => ({ tag, children: [], appendChild: appendChild() }),
};

function appendChild() {
	return function append(child) {
		this.children.push(child);
		return child;
	};
}

const LABELS = {
	dependencies_one: "%{count} dependency",
	dependencies_other: "%{count} dependencies",
};

test("truncate: leaves short text untouched", () => {
	assert.equal(component().truncate("short", 22), "short");
});

test("truncate: text at exactly the limit is untouched", () => {
	assert.equal(component().truncate("exactly5", 8), "exactly5");
});

test("truncate: cuts long text down to max chars, ending in an ellipsis", () => {
	const result = component().truncate("a very long template name", 10);

	assert.equal(result.length, 10);
	assert.ok(result.endsWith("…"));
	assert.equal(result, "a very lo…");
});

test("depsLabel: picks the singular label for exactly one dependency", () => {
	assert.equal(component(LABELS).depsLabel(1), "1 dependency");
});

test("depsLabel: picks the plural label for zero or several dependencies", () => {
	const graph = component(LABELS);

	assert.equal(graph.depsLabel(0), "0 dependencies");
	assert.equal(graph.depsLabel(3), "3 dependencies");
});

// The group name doubles as the CSS modifier (`schema-rel__dot--<group>`), so the
// component must hand the payload's own value through untouched. It used to
// re-derive one here and answered "shared" for external nodes, against a
// stylesheet that defines `--external` — the sidebar dot fell back to the generic
// grey while the legend right above it stayed coloured. The Ruby side pins the
// three names against the stylesheet (SchemaNodeGroupTest).
test("dotClass: passes the payload's group through as the CSS modifier", () => {
	const graph = component();

	assert.equal(graph.dotClass({ group: "main" }), "main");
	assert.equal(graph.dotClass({ group: "embedded" }), "embedded");
	assert.equal(graph.dotClass({ group: "external" }), "external");
});

test("dotClass: a node the payload does not know is external", () => {
	const graph = component();

	assert.equal(graph.dotClass(null), "external");
	assert.equal(graph.dotClass(undefined), "external");
	assert.equal(graph.dotClass({}), "external");
});

// The root select used to only list templates with outgoing dependencies, so
// clicking an external node (PostalAddress & co.) drew one template while the
// select still showed another. Every node of the payload must be selectable.
test("appendOptions: lists every node, only-used types in their own group", () => {
	const graph = component();
	const select = { options: [], appendChild: appendChild(), children: [] };
	graph.rootSelect = select;
	graph.labels = { root_with_deps: "Mit", root_without_deps: "Ohne" };

	graph.appendOptions([{ id: "Event" }, { id: "Place" }], "Mit");
	graph.appendOptions([{ id: "PostalAddress" }], "Ohne");

	assert.deepEqual(
		select.children.map((child) => [child.tag, child.label]),
		[
			["optgroup", "Mit"],
			["optgroup", "Ohne"],
		],
	);
	assert.deepEqual(
		select.children.flatMap((group) => group.children.map((o) => o.value)),
		["Event", "Place", "PostalAddress"],
	);
});

test("appendOptions: without a group label the options land in the select itself", () => {
	const graph = component();
	const select = { options: [], appendChild: appendChild(), children: [] };
	graph.rootSelect = select;

	graph.appendOptions([{ id: "Event" }], null);

	assert.deepEqual(
		select.children.map((child) => [child.tag, child.value]),
		[["option", "Event"]],
	);
});

test("appendOptions: an empty list adds nothing, not an empty group", () => {
	const graph = component();
	const select = { options: [], appendChild: appendChild(), children: [] };
	graph.rootSelect = select;

	graph.appendOptions([], "Ohne");

	assert.deepEqual(select.children, []);
});
