const ObserverHelpers = {
	newItemsConfig: {
		subtree: true,
		childList: true,
	},
	changedClassConfig: {
		attributes: true,
		attributeFilter: ["class"],
		attributeOldValue: true,
	},
	changedClassWithSubtreeConfig: {
		subtree: true,
		attributes: true,
		attributeFilter: ["class"],
		attributeOldValue: true,
	},
	intersectionObserverConfig: {
		rootMargin: "0px 0px 50px 0px",
		threshold: 0.1,
	},
	changedAttributeConfig(attributeFilter = []) {
		return Object.assign({}, this.changedClassConfig, {
			attributeFilter: attributeFilter,
		});
	},
	checkForConditionRecursive(node, selector, callback) {
		if (node.querySelector(selector))
			for (const element of node.querySelectorAll(selector)) callback(element);
		if (node.matches(selector)) callback(node);
	},
};

Object.freeze(ObserverHelpers);

export default ObserverHelpers;
