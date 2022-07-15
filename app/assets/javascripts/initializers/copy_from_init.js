import CopyFromAttribute from './../components/copy_from_attribute';

export default function () {
  let copyFromAttributeFeatures = [];

  for (const element of document.querySelectorAll('.copy-from-attribute-feature'))
    copyFromAttributeFeatures.push(new CopyFromAttribute(element));

  DataCycle.htmlObserver.addCallbacks.push([
    e => e.classList.contains('copy-from-attribute-feature'),
    e => copyFromAttributeFeatures.push(new CopyFromAttribute(e))
  ]);
}
