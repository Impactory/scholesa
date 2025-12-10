import * as functions from 'firebase-functions';

export const nightlyStudioSummary = functions.pubsub
  .schedule('every 24 hours')
  .onRun((context) => {
    // ...
  });
