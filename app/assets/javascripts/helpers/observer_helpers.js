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
	checkForConditionRecursive(node, selector, callback) {
		if (node.querySelector(selector))
			for (const element of node.querySelectorAll(selector)) callback(element);
		if (node.matches(selector)) callback(node);
	},
};

Object.freeze(ObserverHelpers);

export default ObserverHelpers;
