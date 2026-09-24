// formDataToObject (helpers/dom_element_helpers.js) builds the nested object of a form from these
// two: a `key[]` field name has to land as an array under `key`, at any depth, or every
// classification and linked value of a copied embedded reaches the server in the wrong shape.
import assert from "node:assert/strict";
import { test } from "node:test";
import { get, set } from "../../app/assets/javascripts/helpers/object_utilities.js";

const path = "thing[datahash][embedded_creative_work][3][datahash][schema_types][]";

test("set ignores the empty segment of a trailing `[]`", () => {
	const object = set({}, path, ["uuid-1"]);

	assert.deepEqual(object.thing.datahash.embedded_creative_work[3].datahash.schema_types, ["uuid-1"]);
});

test("get reads the same path back, with the default while it is unset", () => {
	const object = set({}, path, ["uuid-1"]);

	assert.deepEqual(get(object, path, []), ["uuid-1"]);
	assert.deepEqual(get({}, path, []), []);
});
