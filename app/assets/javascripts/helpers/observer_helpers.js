export default {
	newItemsConfig: {
		attributes: false,
		characterData: false,
		subtree: true,
		childList: true,
		attributeOldValue: false,
		characterDataOldValue: false,
	},
	changedClassConfig: {
		subtree: false,
		attributes: true,
		attributeFilter: ["class"],
		characterData: false,
		childList: false,
		attributeOldValue: true,
		characterDataOldValue: false,
	},
	changedClassWithSubtreeConfig: {
		subtree: true,
		attributes: true,
		attributeFilter: ["class"],
		characterData: false,
		childList: false,
		attributeOldValue: true,
		characterDataOldValue: false,
	},
	checkForConditionRecursive: function (node, selector, callback) {
		if (node.querySelector(selector))
			for (const element of node.querySelectorAll(selector)) callback(element);
		if (node.matches(selector)) callback(node);
	},
};
