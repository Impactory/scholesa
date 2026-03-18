import { setGlobalOptions } from 'firebase-functions/v2/options';

export const SCHOLESA_GEN2_REGION = 'us-central1';

// Apply a single Gen 2 baseline for v2 entry modules so new functions do not
// silently drift onto a different region or deployment shape.
setGlobalOptions({
  region: SCHOLESA_GEN2_REGION,
});
