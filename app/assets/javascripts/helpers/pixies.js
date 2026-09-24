/**
 * What each pixie asks for and what it reads back (#47879, #47881) -- one descriptor per pixie,
 * shared by the wand in an attribute's row and by the upload mask's "apply this pixie to every
 * file" button beside it.
 *
 * Both used to carry their own copy: the components described the wand's request and the registry
 * in pixie_to_all_files.js described the same request for another asset, so an endpoint or a
 * payload change had two edit sites and no test failed when only one of them was made.
 *
 * +request+ answers for whichever image the context names -- a persisted thing, or an asset of the
 * upload mask -- and +extract+ turns a payload into the values to apply, in the {value, text} shape
 * the uploader submits as form fields. A wand shapes those further for its own editor.
 */

/**
 * The label comes along so the file's attribute summary reads like the copy button's, which
 * resolves one per id through /api/v4/universal.
 */
const classificationValues = (suggestions) =>
	(suggestions || [])
		.filter((suggestion) => suggestion.id)
		.map((suggestion) => ({
			value: suggestion.id,
			text: suggestion.name || suggestion.label,
		}));

/**
 * The request context of a wand, as the partial writes it onto the button. +assetId+ is overridden
 * for one of the other uploaded files, which is also why +thingId+ is dropped there: that file has
 * no content yet.
 *
 * @param button [HTMLElement] the wand, or the button that copied its dataset
 * @param overrides [Object]
 */
export const pixieContext = (button, overrides = {}) => ({
	...button.dataset,
	...overrides,
});

export const PIXIES = {
	annotation_pixie: {
		// a persisted image is classified through its content, so its text and its image both feed
		// the suggestion; an upload has only its asset -- by id, never by a url from here, so the
		// endpoint cannot be used as a fetch proxy
		request: ({ thingId, assetId, templateName, conceptSchemeId }) =>
			thingId
				? [
						`/things/${encodeURIComponent(thingId)}/classify`,
						{ classification_tree_id: conceptSchemeId },
					]
				: [
						"/things/classify_asset",
						{
							classification_tree_id: conceptSchemeId,
							asset_id: assetId,
							template_name: templateName,
						},
					],
		extract: (payload) => classificationValues(payload.suggestions),
		emptyKey: "frontend.annotation_pixie.no_suggestions",
		failedKey: "frontend.annotation_pixie.classify_failed",
		// the classification webhook takes one concept scheme per call ... but a list of images, so
		// applying to every file is one call rather than one per file
		batchRequest: ({ conceptSchemeId, templateName }, assetIds) => [
			"/things/classify_assets",
			{
				classification_tree_id: conceptSchemeId,
				asset_ids: assetIds,
				template_name: templateName,
			},
		],
		batchValues: (payload, assetId) =>
			classificationValues(payload.suggestions_by_asset?.[assetId]),
		// several concept schemes write into universal_classifications, so a run for one of them
		// must not drop what a run for another one suggested
		merge: true,
	},

	// no batchRequest: PixieLens annotates one image per call
	image_description_pixie: {
		// the locale is the wand's, not the request's: the endpoint keys every text by the locale it
		// was asked for and falls back to the backend's own when the request names none, so leaving
		// it out answers { de: "..." } to a wand sitting in the English translation -- and +extract+
		// below, which looks the suggestion up by that wand's locale, then finds nothing
		request: ({ thingId, assetId, templateName, locale }) => [
			"/things/description_suggestion",
			thingId
				? { thing_id: thingId, locale }
				: { asset_id: assetId, template_name: templateName, locale },
		],
		extract: (payload, { attributeKey, locale }) =>
			[payload.texts?.[attributeKey]?.[locale]]
				.filter(Boolean)
				.map((text) => ({ value: text })),
		emptyKey: "frontend.image_description_pixie.no_suggestion",
		failedKey: "frontend.image_description_pixie.failed",
		merge: false,
	},
};
