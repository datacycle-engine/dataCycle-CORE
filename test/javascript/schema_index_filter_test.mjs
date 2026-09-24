// Unit tests for the DOM-free parts of SchemaIndexFilter: the sort comparator and the
// three-way filter predicate. The DOM wiring (tablist, expand-all, group badges) is not
// covered here — see the docker skill for running the component in a browser.
//
// This is the logic that used to live as an inline IIFE in schema/index.html.erb, where it
// could not be imported and therefore could not be tested at all.
import assert from "node:assert/strict";
import { test } from "node:test";
import SchemaIndexFilter, {
	SORTS,
	DEFAULT_SORT,
	compareValues,
	matchesFilters,
} from "../../app/assets/javascripts/schema/index_filter.js";

// Sorts a list of values the way #sort orders cards under one spec.
function sorted(values, sortKey) {
	const spec = SORTS[sortKey];
	return [...values].sort((a, b) => compareValues(a, b, spec));
}

function entry(attributes = {}) {
	return { haystack: "", part: "main", count: 0, ...attributes };
}

const ALL = { term: "", part: "main", onlyWithContent: false };

test("the component binds the overview, not the detail page", () => {
	assert.equal(SchemaIndexFilter.selector, "[data-schema-index]");
	assert.equal(SchemaIndexFilter.className, "dcjs-schema-index-filter");
});

test("every sort option names a real card dataset key", () => {
	assert.ok(SORTS[DEFAULT_SORT], "the default sort must be one of the options");
	for (const [name, spec] of Object.entries(SORTS)) {
		assert.ok(
			["sortName", "sortPath", "count"].includes(spec.key),
			`${name} sorts by an unknown key ${spec.key}`,
		);
		assert.equal(typeof spec.desc, "boolean");
		assert.equal(typeof spec.numeric, "boolean");
	}
});

test("compareValues: alphabetical ascending and descending are mirrors", () => {
	assert.deepEqual(sorted(["Ort", "Artikel", "Bild"], "heading_asc"), [
		"Artikel",
		"Bild",
		"Ort",
	]);
	assert.deepEqual(sorted(["Ort", "Artikel", "Bild"], "heading_desc"), [
		"Ort",
		"Bild",
		"Artikel",
	]);
});

// The reason localeCompare is used instead of `<`: "Ähre" must sort next to "Ahre", not
// after "Zebra" where its code point would put it. `sensitivity: "base"` makes the two
// compare EQUAL, so their order relative to each other is the input order (Array#sort is
// stable) — only their position against "Zebra" is defined.
test("compareValues: umlauts sort with their base letter", () => {
	assert.deepEqual(sorted(["Zebra", "Ähre", "Ahre"], "heading_asc").at(-1), "Zebra");
	assert.equal(compareValues("Ähre", "Ahre", SORTS.heading_asc), 0);
	assert.ok(compareValues("Ähre", "Zebra", SORTS.heading_asc) < 0);
});

// …and why `numeric: true` is set: a plain string sort puts "Bild 10" before "Bild 9".
test("compareValues: embedded numbers sort numerically", () => {
	assert.deepEqual(sorted(["Bild 10", "Bild 9", "Bild 1"], "heading_asc"), [
		"Bild 1",
		"Bild 9",
		"Bild 10",
	]);
});

test("compareValues: counts sort numerically, not as strings", () => {
	assert.deepEqual(sorted(["100", "9", "20"], "count_asc"), ["9", "20", "100"]);
	assert.deepEqual(sorted(["100", "9", "20"], "count_desc"), [
		"100",
		"20",
		"9",
	]);
});

// A template that has never been used carries no count; it must not jump to the top of a
// descending count sort. The comparator is called directly for the undefined case, because
// Array#sort moves a bare `undefined` element to the end without consulting it at all.
test("compareValues: a missing count counts as zero", () => {
	assert.deepEqual(sorted(["5", "", "3"], "count_desc"), ["5", "3", ""]);
	assert.equal(compareValues(undefined, 0, SORTS.count_asc), 0);
	assert.ok(compareValues(undefined, 3, SORTS.count_asc) < 0);
	assert.ok(compareValues(undefined, 3, SORTS.count_desc) > 0);
});

test("matchesFilters: an empty term matches every card of the active part", () => {
	assert.equal(matchesFilters(entry({ haystack: "artikel" }), ALL), true);
});

test("matchesFilters: the term is a substring match on the haystack", () => {
	const card = entry({ haystack: "artikel article" });

	assert.equal(matchesFilters(card, { ...ALL, term: "tike" }), true);
	assert.equal(matchesFilters(card, { ...ALL, term: "artic" }), true);
	assert.equal(matchesFilters(card, { ...ALL, term: "ort" }), false);
});

// The part is the tablist, so an embedded template must never show under Hauptschema
// however well it matches the search.
test("matchesFilters: a card of another schema part never matches", () => {
	const embedded = entry({ haystack: "bild", part: "embedded" });

	assert.equal(matchesFilters(embedded, { ...ALL, term: "bild" }), false);
	assert.equal(
		matchesFilters(embedded, { ...ALL, term: "bild", part: "embedded" }),
		true,
	);
});

test("matchesFilters: the content toggle drops templates with a zero count", () => {
	const used = entry({ count: 3 });
	const unused = entry({ count: 0 });
	const filters = { ...ALL, onlyWithContent: true };

	assert.equal(matchesFilters(used, filters), true);
	assert.equal(matchesFilters(unused, filters), false);
	assert.equal(matchesFilters(unused, ALL), true);
});

// The three filters are independent, so failing any one of them hides the card.
test("matchesFilters: the three filters combine with AND", () => {
	const card = entry({ haystack: "artikel", part: "main", count: 2 });

	assert.equal(
		matchesFilters(card, { term: "artikel", part: "main", onlyWithContent: true }),
		true,
	);
	assert.equal(
		matchesFilters(card, { term: "ort", part: "main", onlyWithContent: true }),
		false,
	);
	assert.equal(
		matchesFilters(card, {
			term: "artikel",
			part: "embedded",
			onlyWithContent: true,
		}),
		false,
	);
	assert.equal(
		matchesFilters({ ...card, count: 0 }, {
			term: "artikel",
			part: "main",
			onlyWithContent: true,
		}),
		false,
	);
});
