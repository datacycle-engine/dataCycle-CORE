import ResultCount from '../components/result_count';

export default function () {
  DataCycle.initNewElements('.result-count:not(.dcjs-result-count)', e => new ResultCount(e));
}
