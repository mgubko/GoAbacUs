# GoAbacUs licence server

Signs family licences for GoAbacUs Scan and Tutor. The child's app checks the
signature offline with the public key built into it, so the server is the only
place that can make a licence.

What it stores: family id, hash of the family secret, paid-until date, store
purchase token. No names, children or homework.

## API (POST, JSON)

| Path | Body | Does |
|---|---|---|
| `/v1/redeem` | `code, family, keyHash` | Kit activation code: the first family gets +90 days (code's `days`). Same family again = same licence. |
| `/v1/play` | `family, keyHash, product, token` | Google Play subscription, checked with the Play Developer API and acknowledged. |
| `/v1/refresh` | `family, keyHash` | Current licence; re-checks the store, so renewals show up. |
| `/v1/apple` | | 501 for now (App Store Server API not wired yet). |

## Set up (once)

1. Key pair: `dart run bin/keygen.dart`. Put the seed in Secret Manager as
   `LICENSE_SEED`. Put the public key in `productionLicenseKeys` in
   `packages/tutor_tasks/lib/src/license_keys.dart`, then rebuild both apps.
   Release builds trust only production keys. Debug builds also trust the
   public dev key, which the server uses when `LICENSE_SEED` is not set.
2. Firestore (native mode) in the same Google Cloud project.
3. Cloud Run, built from the repository root:
   ```
   gcloud run deploy goabacus-license --source . \
     --set-env-vars STORE=firestore:PROJECT,PLAY_PACKAGE=com.goabacus.scan \
     --set-secrets LICENSE_SEED=LICENSE_SEED:latest --allow-unauthenticated
   ```
   (or `docker build -f server/license/Dockerfile .`).
4. Play Console:
   - Create the subscriptions `goabacus_family_monthly` and `goabacus_family_yearly`.
   - Under Users and permissions, invite the Cloud Run service account with
     "View financial data" and "Manage orders and subscriptions".
5. Build Scan with `--dart-define=LICENSE_SERVER=https://...run.app`.

## Kit codes

```
dart run bin/mint_codes.dart 500 --days 90 --store firestore:PROJECT > batch-001.csv
```

Each CSV line holds the printed code (`GA7K-3MQ9-X2PD`) and the link for the QR
code on the card (`goabacus-scan://activate?code=…`), which opens Scan with the
code filled in. Codes are 60 random bits; each one works for one family.
