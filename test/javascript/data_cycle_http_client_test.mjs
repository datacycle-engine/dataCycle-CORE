// mergeHttpOptions moves the body of a GET request into the query string. A url that already
// carries one (the search history's load-more link is `/search_history?page=2`) has to be joined
// with `&`: a second `?` would make the server read `page` as "2?last_day=…" and drop `last_day`.
import assert from "node:assert/strict";
import { test } from "node:test";
import DataCycleHttpClient from "../../app/assets/javascripts/components/data_cycle_http_client.js";

globalThis.document = { getElementsByName: () => [{ content: "csrf-token" }] };

const client = { ...DataCycleHttpClient, config: { EnginePath: "" } };
const getRequestUrl = (url, body) => client.mergeHttpOptions(url, { body })[0];

test("a GET body starts the query string of a url without one", () => {
	assert.equal(
		getRequestUrl("/search_history/saved_searches", { q: "Wandern" }),
		"/search_history/saved_searches?q=Wandern",
	);
});

test("a GET body joins the query string a url already carries", () => {
	assert.equal(
		getRequestUrl("/search_history?page=2", { last_day: "18. August 2026", q: "" }),
		"/search_history?page=2&last_day=18.+August+2026&q=",
	);
});
