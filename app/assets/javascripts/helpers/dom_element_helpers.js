import ConfirmationModal from "../components/confirmation_modal";

const DomElementHelpers = {
	isVisible(elem) {
		return (
			elem.offsetWidth > 0 ||
			elem.offsetHeight > 0 ||
			elem.getClientRects().length > 0
		);
	},
	isHidden(elem) {
		return !this.isVisible(elem);
	},
	findAncestors(elem, filter, ancestors = []) {
		if (!elem) return ancestors;

		if (filter.call(this, elem)) ancestors.push(elem);

		return this.findAncestors(elem.parentElement, filter, ancestors);
	},
	parseDataAttribute(value) {
		if (!value) return value;

		try {
			return JSON.parse(value);
		} catch {
			return value;
		}
	},
	randomId(prefix = "") {
		if (self.crypto.randomUUID !== undefined) return self.crypto.randomUUID();

		return `${prefix}_${Math.random().toString(36).slice(2)}`;
	},
	async renderImportConfirmationModal(field, sourceId, confirmationCallback) {
		const container = field.closest(".form-element");
		const label = container.getElementsByClassName("attribute-label-text")[0];
		const labelText = label?.textContent;
		const fieldId = sourceId || this.randomId("focus-field");
		container.dataset.focusId = fieldId;

		const text = `${await I18n.translate("frontend.override_warning", {
			data: labelText,
		})}<br><br><span class="focus-specific-field" data-field-id="${fieldId}">${await I18n.translate(
			"frontend.override_focus",
		)}</span>`;

		new ConfirmationModal({
			text: text,
			confirmationText: await I18n.translate("common.yes"),
			cancelText: await I18n.translate("common.no"),
			confirmationClass: "success",
			cancelable: true,
			confirmationCallback: confirmationCallback,
		});
	},
	getFormData(container, filterByPrefix = "", removeEmbeddedPrefix = false) {
		let formData = new FormData();
		if (container.nodeName === "FORM") formData = new FormData(container);
		else
			for (const element of $(container).find(":input").serializeArray())
				formData.append(element.name, element.value);

		if (removeEmbeddedPrefix)
			formData = this.removeEmbeddedPrefixFromFormdata(formData);
		if (filterByPrefix) this.rejectFormdataByPrefix(formData, filterByPrefix);

		return formData;
	},
	removeEmbeddedPrefixFromFormdata(formData) {
		if (!formData) return;

		const newFormData = new FormData();

		for (const [key, value] of Array.from(formData))
			newFormData.append(
				key.replace(/(datahash|translations)+.+(datahash|translations)+/, "$2"),
				value,
			);

		return newFormData;
	},
	rejectFormdataByPrefix(formData, prefix) {
		if (!formData) return;

		for (const [key, _value] of Array.from(formData))
			if (!key.startsWith(prefix)) formData.delete(key);
	},
	isScrollable(elem) {
		if (!(elem && elem instanceof Element)) return false;

		return window
			.getComputedStyle(elem)
			.overflow.split(" ")
			.every((o) => o === "auto" || o === "scroll");
	},
	fadeOut(target, duration = 500) {
		if (!(target && target instanceof Element)) return Promise.reject();

		target.style.transitionDuration = `${duration}ms`;
		target.classList.add("fadeout");

		return new Promise((resolve) =>
			setTimeout(() => {
				resolve(target);
			}, duration),
		);
	},
	slideDown(target, duration = 200) {
		if (!(target && target instanceof Element)) return Promise.reject();

		const height = target.offsetHeight;
		target.classList.add("sliding");
		target.offsetHeight;
		target.classList.add("sliding-base");
		target.style.cssText += `transition-duration: ${duration}ms; height: ${height}px;`;
		target.classList.remove("sliding");

		return new Promise((resolve) =>
			setTimeout(() => {
				target.style.removeProperty("height");
				target.classList.remove("sliding-base");
				target.style.removeProperty("transition-duration");
				resolve(target);
			}, duration),
		);
	},
	slideUp(target, duration = 200) {
		if (!(target && target instanceof Element)) return Promise.reject();

		target.style.cssText += `transition-duration: ${duration}ms; height: ${target.offsetHeight}px;`;
		target.classList.add("sliding-base");
		target.offsetHeight;
		target.classList.add("sliding");

		return new Promise((resolve) =>
			setTimeout(() => {
				target.style.display = "none";
				target.classList.remove("sliding-base", "sliding");
				target.style.removeProperty("height");
				target.style.removeProperty("transition-duration");
				resolve(target);
			}, duration),
		);
	},
	$cloneElement(element) {
		if (element instanceof $) element = element.get();

		const fragment = new DocumentFragment();

		if (Array.isArray(element))
			for (const e of element) fragment.append(e.cloneNode(true));
		else fragment.append(element.cloneNode(true));

		for (const dcjsElem of fragment.querySelectorAll('[class*="dcjs"]')) {
			for (const className of dcjsElem.classList)
				if (className.startsWith("dcjs-")) dcjsElem.classList.remove(className);

			if (
				dcjsElem.classList.contains("reveal") ||
				dcjsElem.classList.contains("dropdown-pane")
			) {
				const newId = DomElementHelpers.randomId();
				const elem = fragment.querySelector(
					`[data-open="${dcjsElem.id}"], [data-toggle="${dcjsElem.id}"]`,
				);
				dcjsElem.id = newId;
				if (elem.dataset.open) elem.dataset.open = newId;
				if (elem.dataset.toggle) elem.dataset.toggle = newId;
			}
		}

		return $(fragment.children);
	},
};

Object.freeze(DomElementHelpers);

export default DomElementHelpers;
