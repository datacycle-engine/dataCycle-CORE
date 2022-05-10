import '../../../../../app/assets/stylesheets/application.scss';

import DataCycleInit from '../../../../../app/assets/javascripts/application';

// Demo for AppSignal Integration
// import appSignalInit from '../../../../../app/assets/javascripts/initializers/app_signal_init';
// appSignalInit('some-appsignal-fronteend-key');
// DataCycleInit({}, () => {
//   DataCycle.notifications.addEventListener('error', ({ detail }) => appSignal.sendError(detail));
// });

DataCycleInit();
