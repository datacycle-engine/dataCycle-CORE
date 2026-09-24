import get from "lodash/get";
import CalloutHelpers from "../helpers/callout_helpers";
import { formDataToObject, getFormData } from "../helpers/dom_element_helpers";
import DcStickyBar from "./dc_sticky_bar";

// Header actions of an embedded item that render a second item from an existing record: linking
// one picked in the object browser (Feature::ReusableEmbedded), unlinking a shared one into a
// copy, and duplicating one (Feature::DuplicateEmbedded). Mixed into EmbeddedObject.prototype.
const EmbeddedCopyActions = {
	async selectExisting(_event, data) {
		this.reusableBrowser.querySelector(".object-thumbs").replaceChildren();

		if (!data?.ids?.length) return;

		await this.addItems(data.ids, "existing");

		this.$element.trigger("change");
	},
	// Unlinks a shared embedded from this content: the copy takes its place, the save creates a new
	// record here and leaves the other usages untouched.
	async unlinkEmbedded(event) {
		event.preventDefault();

		const source = event.currentTarget.closest(".content-object-item");

		await this.insertCopyAfter(source);
		this.removeObject($(source));
	},
	async duplicateEmbedded(event) {
		event.preventDefault();

		if (
			this.max !== 0 &&
			this.$element.children(".content-object-item").length >= this.max
		)
			return this.maxReachedModal();

		await this.insertCopyAfter(
			event.currentTarget.closest(".content-object-item"),
		);
		this.$element.trigger("change");
	},
	// What the copy is rendered from: the form's own fields once the item's editors are loaded
	// (unsaved edits and unsaved items included), the saved record while the item is still
	// collapsed and its fields are not on the page yet.
	copySource(source) {
		if (
			source.querySelector(
				":scope > .embedded-properties.remote-render:not(.remote-rendered)",
			)
		)
			return { object_ids: [source.dataset.id] };

		return {
			embedded_template: source.querySelector(
				":scope > input.embedded-template",
			)?.value,
			copy_data: get(
				formDataToObject(getFormData(source)),
				`${this.key}[${source.dataset.index}]`,
			),
		};
	},
	// Renders a split-view copy of the item right below it. The copy carries no hidden [id]
	// field, so it also drops the source's data-id: this.ids and data-excluded describe the
	// records the form links, and a copy is not one of them.
	async insertCopyAfter(source) {
		this.parent.classList.add("loading-embedded");

		try {
			const data = await this.requestEmbeddedHtml({
				index: this.index++,
				duplicated_content: true,
				...this.copySource(source),
			});

			// empty once another editor removed the record meanwhile
			if (!data?.html)
				throw new Error(`no copy rendered for ${source.dataset.id}`);

			source.insertAdjacentHTML("afterend", data.html);
			const copy = source.nextElementSibling;
			copy.removeAttribute("data-id");

			this.update();
			DcStickyBar.scrollIntoViewWithStickyOffset(copy);
		} catch (error) {
			CalloutHelpers.show(
				error.responseBody?.error ||
					(await I18n.translate("frontend.remote_render.error")),
				"alert",
			);
		} finally {
			this.parent.classList.remove("loading-embedded");
		}
	},
};

export default EmbeddedCopyActions;
