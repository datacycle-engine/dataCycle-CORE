export const newDirectItemsConfig = {
	childList: true,
};
export const newItemsConfig = {
	subtree: true,
	childList: true,
};
export const changedClassConfig = {
	attributes: true,
	attributeFilter: ["class"],
	attributeOldValue: true,
};
export const changedClassWithSubtreeConfig = {
	subtree: true,
	attributes: true,
	attributeFilter: ["class"],
	attributeOldValue: true,
};
export const intersectionObserverConfig = {
	rootMargin: "0px 0px 50px 0px",
	threshold: 0.1,
};
export function changedAttributeConfig(attributeFilter = []) {
	return Object.assign({}, changedClassConfig, {
		attributeFilter: attributeFilter,
	});
}
export function checkForConditionRecursive(node, selector, callback) {
	if (node.querySelector(selector))
		for (const element of node.querySelectorAll(selector)) callback(element);
	if (node.matches(selector)) callback(node);
}

const ObserverHelpers = {
	newItemsConfig,
	newDirectItemsConfig,
	changedClassConfig,
	changedClassWithSubtreeConfig,
	intersectionObserverConfig,
	changedAttributeConfig,
	checkForConditionRecursive,
};

Object.freeze(ObserverHelpers);

export default ObserverHelpers;
