import ConditionalField from '../components/conditional_field';

export default function () {
  const conditionalFields = [];

  for (const element of document.querySelectorAll('.conditional-form-field'))
    conditionalFields.push(new ConditionalField(element));

  DataCycle.htmlObserver.addCallbacks.push([
    e => e.classList.contains('conditional-form-field') && !e.classList.contains('dcjs-conditional-field'),
    e => conditionalFields.push(new ConditionalField(e))
  ]);
}
