import ClassificationNameButton from '../components/classification_administration/classification_name_button';
import ClassificationVisibilitySwitcher from '../components/classification_administration/classification_visibility_switcher';
import ClassificationLoadMoreButton from '../components/classification_administration/classification_load_more_button';
import ClassificationEditButton from '../components/classification_administration/classification_edit_button';
import ClassificationEditForm from '../components/classification_administration/classification_edit_form';
import ClassificationDestroyButton from '../components/classification_administration/classification_delete_button';
import ClassificationLoadAllButton from '../components/classification_administration/classification_load_all_button';
import ClassificationCloseAllButton from '../components/classification_administration/classification_close_all_button';
import DetailToggler from '../components/detail_toggler';

export default function () {
  if ($('#classification-administration').length) {
    for (const element of document.querySelectorAll(
      '[name="classification_tree_label[visibility][]"][value="show"], [name="classification_tree_label[visibility][]"][value="show_more"]'
    ))
      new ClassificationVisibilitySwitcher(element);
    DataCycle.htmlObserver.addCallbacks.push([
      e =>
        e.nodeName == 'INPUT' &&
        !e.classList.contains('dcjs-classification-visibility-switcher') &&
        e.name == 'classification_tree_label[visibility][]' &&
        ['show', 'show_more'].includes(e.value),
      e => new ClassificationVisibilitySwitcher(e)
    ]);

    for (const element of document.querySelectorAll('a.name')) new ClassificationNameButton(element);
    DataCycle.htmlObserver.addCallbacks.push([
      e =>
        e.nodeName == 'A' && e.classList.contains('name') && !e.classList.contains('dcjs-classification-name-button'),
      e => new ClassificationNameButton(e)
    ]);

    for (const element of document.querySelectorAll('.load-more-button')) new ClassificationLoadMoreButton(element);
    DataCycle.htmlObserver.addCallbacks.push([
      e => e.classList.contains('load-more-button') && !e.classList.contains('dcjs-classification-load-more-button'),
      e => new ClassificationLoadMoreButton(e)
    ]);

    for (const element of document.querySelectorAll('a.create, a.edit')) new ClassificationEditButton(element);
    DataCycle.htmlObserver.addCallbacks.push([
      e =>
        e.nodeName == 'A' &&
        (e.classList.contains('create') || e.classList.contains('edit')) &&
        !e.classList.contains('dcjs-classification-edit-button'),
      e => new ClassificationEditButton(e)
    ]);

    for (const element of document.querySelectorAll(
      'form.classification-tree-label-form, form.classification-alias-form'
    ))
      new ClassificationEditForm(element);
    DataCycle.htmlObserver.addCallbacks.push([
      e =>
        e.nodeName == 'FORM' &&
        (e.classList.contains('classification-tree-label-form') || e.classList.contains('classification-alias-form')) &&
        !e.classList.contains('dcjs-classification-edit-form'),
      e => new ClassificationEditForm(e)
    ]);

    for (const element of document.querySelectorAll('a.destroy')) new ClassificationDestroyButton(element);
    DataCycle.htmlObserver.addCallbacks.push([
      e =>
        e.nodeName == 'A' &&
        e.classList.contains('destroy') &&
        !e.classList.contains('dcjs-classification-destroy-button'),
      e => new ClassificationDestroyButton(e)
    ]);

    for (const element of document.querySelectorAll('.classification-load-all-children'))
      new ClassificationLoadAllButton(element);
    DataCycle.htmlObserver.addCallbacks.push([
      e =>
        e.classList.contains('classification-load-all-children') &&
        !e.classList.contains('dcjs-classification-load-all-button'),
      e => new ClassificationLoadAllButton(e)
    ]);

    for (const element of document.querySelectorAll('.classification-close-all-children'))
      new ClassificationCloseAllButton(element);
    DataCycle.htmlObserver.addCallbacks.push([
      e =>
        e.classList.contains('classification-close-all-children') &&
        !e.classList.contains('dcjs-classification-load-all-button'),
      e => new ClassificationCloseAllButton(e)
    ]);
  }

  for (const element of document.querySelectorAll('.toggle-details')) new DetailToggler(element);
  DataCycle.htmlObserver.addCallbacks.push([
    e => e.classList.contains('toggle-details') && !e.classList.contains('dcjs-detail-toggler'),
    e => new DetailToggler(e)
  ]);
}
