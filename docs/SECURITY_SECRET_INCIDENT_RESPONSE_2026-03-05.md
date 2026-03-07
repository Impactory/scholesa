# Secret Exposure Response (2026-03-05, Updated 2026-03-06)

## Scope
Tracked credential files were removed from the repository working tree:

- `scholesa-10cfaceb0561.json`
- `client_secret_97120825720-bbnvrtprshupk1qglnrtl34nj5jd1s5d.apps.googleusercontent.com.json`
- `.idx/studio-3328096157-e3f79-firebase-adminsdk-fbsvc-9d9be1eb80.json`

## Completed Actions (2026-03-06)
1. Revoked leaked service-account keys in `studio-3328096157-e3f79` for:
   - `firebase-adminsdk-fbsvc@studio-3328096157-e3f79.iam.gserviceaccount.com`
   - Deleted key IDs:
     - `9d9be1eb801048f8cc718777e256de49724cd7ee`
     - `fea5509b73bd1109bd0b6f93b501f677c7dded3e`
2. Rewrote git history to purge the leaked files, then force-pushed rewritten refs:
   - `main`: `b12f61d72f4e0e8d9da419eca034d55bf10455d8`
   - `release/rc2`: `2e4a5f45c4d71da9dd392dc2074159fbc75a3031`
   - `rc2-freeze-2026-02-20`: `fd00eaf062c2249139b1cd2d3f0f4e21dbb4f959`
   - `v1.0.0-rc.2`: `055340b33df45f108275bc1d0346aa3658d35b30`
3. Removed local copy of compromised key material (`firebase-service-account.json`).
4. Rotated Secret Manager payload for `firebase-adminsdk-fbsvc`:
   - Added version `4` with key `37dc572e77e926cba8ee898973e917fb85a506b5`
   - Destroyed compromised historical versions `1`, `2`, and `3`

## Remaining Required Rotations
1. Verify/revoke the `scholesa@scholesa.iam.gserviceaccount.com` leaked key (`10cface...`) in project `scholesa`.
   - Current blocker: no IAM permissions to `scholesa` project from this account.
2. Rotate the Google OAuth client secret for:
   - `97120825720-bbnvrtprshupk1qglnrtl34nj5jd1s5d.apps.googleusercontent.com`
   - This must be reset in Google Cloud Console (APIs & Services > Credentials), then propagated to all runtime environments.
3. Verify GitHub Actions `GCP_SA_KEY` does not contain the leaked `scholesa-10cface...` key.
   - If it does, replace it with a newly issued key from an authorized service account.
4. Replace any other deployed secrets in Secret Manager / CI that still reference revoked credentials.

## History Rewrite Command (executed)
Used from a clean mirror clone:

```bash
git filter-repo \
  --path scholesa-10cfaceb0561.json \
  --path client_secret_97120825720-bbnvrtprshupk1qglnrtl34nj5jd1s5d.apps.googleusercontent.com.json \
  --path .idx/studio-3328096157-e3f79-firebase-adminsdk-fbsvc-9d9be1eb80.json \
  --invert-paths
```

Then force-push rewritten branches/tags and invalidate old clones.

## New Guardrails Added
- `.gitignore` now blocks common service-account/client-secret JSON patterns and `.idx/`.
- `scripts/secret_scan.py` enforces no obvious key material in tracked files.
- `npm run compliance:gate` now includes `npm run qa:secret-scan`.
