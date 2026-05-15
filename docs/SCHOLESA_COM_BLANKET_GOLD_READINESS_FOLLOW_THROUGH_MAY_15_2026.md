# Scholesa.com Blanket Gold Readiness Follow-Through - May 15 2026

Status: current live evidence record and blocker table.

Verdict: `scholesa.com` public web is live, attractive, and aligned with the updated capability evidence language. Complete blanket Gold across all requested surfaces is not yet claimable because macOS Developer ID notarization readiness is currently blocked by keychain access. iOS TestFlight build visibility is proven.

## Scope

Included in this May 15 packet:

- Public `scholesa.com` Flutter front door: `/welcome`, `/login`.
- Public Next pages proxied through `scholesa.com`: `/en`, `/en/summer-camp-2026`.
- Email login routing behavior already proven in the prior live pass.
- Security and compliance gates listed below.
- iOS TestFlight visibility check for the current Flutter build.

Not included as complete until rerun:

- macOS Developer ID signing, notarization, stapling, and Gatekeeper proof.
- Full live role-account UAT refresh across Learner, Educator, Family, site, HQ, and partner roles.
- Guarded aggregate native proof after macOS unblocks.

## Live Deployment Evidence

| Service | Evidence |
| --- | --- |
| Primary Next web | `scholesa-web-00070-wx6` serving 100 percent traffic after Cloud Build `b0eb894d-21f4-4cf5-aefd-1d0d42928a1e`. |
| Primary Next image | `gcr.io/studio-3328096157-e3f79/scholesa:20260515-marketing-parity`, digest `sha256:6f9ec2af9381b564e890efe87089c4e2577a0eb80e288ff40909c29297a1fb6a`. |
| Flutter web | Current public route/login fixes previously deployed to `empire-web-00101-tv9`, serving 100 percent traffic. |
| Public domain split | Flutter owns `/welcome`, `/login`, and app shell routes; Flutter nginx proxies locale public Next routes such as `/en` and `/en/summer-camp-2026`. |

## Live Browser Proof

| URL | Result | Proof notes |
| --- | --- | --- |
| `https://scholesa.com/en` | PASS | Returned `200`, final URL remained `/en`, body included `The Proof Engine for Real Capability Growth`, body included `Growth Reports`, and no localized app links matched `/en/login`, `/en/learner`, `/en/educator`, `/en/site`, `/en/hq`, or `/en/partner`. |
| `https://scholesa.com/en/summer-camp-2026` | PASS | Returned `200`, final URL remained `/en/summer-camp-2026`, body included Summer Camp and learner language. |
| `https://scholesa.com/welcome` | PASS | Returned `200` from Flutter public app. |
| `https://scholesa.com/login` | PASS | Returned `200` from Flutter public app. |

Screenshot artifacts created under `audit-pack/reports/screenshots/`:

- `live-scholesa-next-en-marketing-parity.png`
- `live-scholesa-summer-camp-2026-parity.png`
- `live-scholesa-flutter-welcome-parity.png`
- `live-scholesa-flutter-login-parity.png`

## Local And Security Gate Evidence

| Gate | Result | Gold relevance |
| --- | --- | --- |
| `npm run typecheck -- --pretty false` | PASS | Web TypeScript safety. |
| `npm run lint` | PASS | Web/static code quality. |
| `npm run build` | PASS | Next production build. |
| `flutter test test/public_entry_routes_test.dart` | PASS | Public Flutter route/login/Summer Camp regression. |
| `npm run qa:secret-scan` | PASS | No tracked secret patterns. |
| `npm run ai:internal-only:all` | PASS | AI dependency/import/domain/egress boundary. |
| `npm run qa:k8s:manifests` | PASS | Kubernetes manifest structure and security posture render. |
| `npm run qa:workflow:no-mock` | PASS | No mock workflow findings in strict audit. |
| `npm run qa:coppa:guards` | PASS | Minor-safety guard regression suite. |
| `npm run test:integration:rules` | PASS | Firestore and Storage rules passed 238 emulator tests. |
| `npm run compliance:scan` | PASS | Compliance repo-structure scan passed. |
| `npm audit --audit-level=high` | PASS with low advisories | No high or critical advisories; 9 low transitive advisories remain. |

## Native Channel Evidence

| Channel | Result | Evidence |
| --- | --- | --- |
| iOS | PASS for current TestFlight visibility | `./scripts/apple_release_local.sh verify_testflight_build` verified build `5` for `com.scholesa.app`; processing state `VALID`. |
| Android | PASS for local distribution readiness | `npm run native:distribution:readiness` reported Android Play local distribution PASS. |
| macOS | BLOCKED | `npm run native:distribution:readiness` reported Developer ID notarization blocked by `errSecInternalComponent` during codesign probe. |
| Native aggregate | BLOCKED | Aggregate native-channel distribution is not Gold-ready until macOS keychain/signing/notarization proof passes again. |

## Blanket Gold Blockers

| Blocker | Current state | Required closure proof |
| --- | --- | --- |
| macOS Developer ID keychain access | Blocked by `errSecInternalComponent`. | Unlock/approve Developer ID private key access locally, rerun `npm run native:distribution:readiness`, then run macOS sign/notarize/staple proof. |
| Aggregate native proof | Blocked by macOS readiness. | Guarded native proof packet containing TestFlight, Play internal, and notarized macOS logs. |
| Full live role UAT refresh | Not rerun in this May 15 packet. | Live role-account automation over Learner, Educator, Family, site, HQ, and partner with screenshots and route assertions. |
| Full blanket-gold release gate | Security subset passed; full `test:uat:blanket-gold` was not rerun in this packet. | Run full blanket-gold gate or a release-owner-approved equivalent command bundle after macOS unblocks. |

## Gold Readiness Rule

`scholesa.com` public web can be described as live and currently passing the May 15 public web/security validation packet. The whole Scholesa platform must not be described as complete blanket Gold across web and native until the blocker table above is closed.

## Next Command Sequence

Run after the release owner repairs or approves macOS Developer ID private-key access:

```bash
npm run native:distribution:readiness
./scripts/macos_release_local.sh sign_notarize_staple
./scripts/apple_release_local.sh verify_testflight_build
```

Then run the full web/security/native proof bundle:

```bash
npm run test:uat:blanket-gold
npm run test:uat:live-role-accounts
SCHOLESA_NATIVE_DISTRIBUTION_CONFIRM=I_UNDERSTAND_THIS_UPLOADS_NATIVE_BUILDS bash scripts/native_distribution_proof.sh execute-live
```

Stop if any command requires a secret or keychain password in the terminal output. The release owner must enter or approve those secrets locally; they must not be recorded in logs, docs, shell history, or proof artifacts.