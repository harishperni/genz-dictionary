# Release Stabilization Checklist

## App QA
- `flutter analyze`
- `flutter test`
- Manual smoke:
  - Home search + detail + share templates
  - Daily challenge completion
  - Quiz + badges
  - Battle create/join/share invite
  - Leaderboard tabs (global/city/campus)
  - GenZ+ pages (coach, persona, missions, trends, creator packs, community feed)

## Firestore
- Deploy rules and indexes:
  - `firebase deploy --only firestore:rules,firestore:indexes`
- Verify required indexes are active in Firebase console.

## Cloud Functions
- Install deps:
  - `cd functions && npm install`
- Deploy:
  - `firebase deploy --only functions`
- Validate scheduled jobs:
  - `resetWeeklySeasonStats`
  - `aggregateCityTrends`
- Validate trigger:
  - `aggregateSubmissionVotes` after vote writes.
