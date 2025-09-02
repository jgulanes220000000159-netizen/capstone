# Cloud Functions for MangoSense Notifications

## What this does

- `notifyExpertsOnNewRequest`: Sends a notification to all users with role `expert` when a new `scan_requests/{id}` document is created with `status: 'pending'` or `'pending_review'`.
- `notifyUserOnReviewCompleted`: Sends a notification to the requesting user when a `scan_requests/{id}` document transitions to `status: 'completed'` or `'reviewed'`.

## Prerequisites

- Install Firebase CLI and log in.
- Ensure your Firebase project is selected (`firebase use <projectId>`).
- From the repository root, run `cd functions && npm install`.

## Deploy

```bash
cd functions
npm install
firebase deploy --only functions
```

## Test locally (emulator)

```bash
firebase emulators:start --only functions
```

## Notes

- Make sure your Flutter app writes `fcmToken` to `users/{uid}` for both farmers and experts.
- The notifications use the standard FCM `notification` payloads so Android displays them when the app is backgrounded or terminated.
