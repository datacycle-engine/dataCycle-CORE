import ConditionalField from '../components/conditional_field';

export default function () {
  DataCycle.initNewElements('.conditional-form-field:not(.dcjs-conditional-field)', e => new ConditionalField(e));
}
