export default {
  newItemsConfig: {
    attributes: false,
    characterData: false,
    subtree: true,
    childList: true,
    attributeOldValue: false,
    characterDataOldValue: false
  },
  changedClassConfig: {
    subtree: false,
    attributes: true,
    attributeFilter: ['class'],
    characterData: false,
    childList: false,
    attributeOldValue: true,
    characterDataOldValue: false
  },
  changedClassWithSubtreeConfig: {
    subtree: true,
    attributes: true,
    attributeFilter: ['class'],
    characterData: false,
    childList: false,
    attributeOldValue: true,
    characterDataOldValue: false
  },
  checkForConditionRecursive: function (node, condition, callback) {
    for (const child of node.children) this.checkForConditionRecursive(child, condition, callback);

    if (condition(node)) callback(node);
  }
};
