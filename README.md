# MailMind

MailMind is an iOS app that helps Chinese-speaking users understand English physical mail. Users can upload photos or PDFs of mail, extract the text on-device, generate a concise Chinese summary with AI, classify the mail type, and turn important actions into trackable to-do items.

The app is designed for everyday mail such as bills, government notices, insurance letters, tax documents, banking mail, healthcare notices, school letters, advertisements, and personal correspondence.

## Features

- Upload mail from the photo library, including multiple photos for multi-page letters.
- Import PDF files and analyze them as a single mail item.
- Run on-device OCR with Apple Vision for images and rendered PDFs.
- Use Gemini 3 Flash to summarize English mail in Simplified Chinese.
- Categorize mail into practical categories such as bills, government, banking, insurance, healthcare, tax, legal, school, advertisement, personal, and other.
- Extract actionable tasks and suggested deadlines from each mail item.
- Add suggested tasks to a built-in to-do list.
- Track pending and completed tasks.
- View historical mail analyses and generated action items.
- Continue as a guest with local-only data.
- Sign in with Google through Firebase Authentication.
- Sync authenticated user data through Firebase Functions to Cloud Firestore.

## Tech Stack

- **Platform:** iOS
- **Language:** Swift
- **UI:** SwiftUI
- **Local persistence:** SwiftData
- **OCR:** Apple Vision, PDFKit, PhotosUI
- **Authentication:** Firebase Authentication, Google Sign-In
- **Cloud sync:** Firebase Functions + Cloud Firestore
- **AI analysis:** Gemini API with Gemini 3 Flash structured JSON output through backend functions
- **Testing:** XCTest and XCUITest
- **Package management:** Swift Package Manager

## Project Structure

```text
MailMind/
  MailMindApp.swift              App entry point and Firebase initialization
  ContentView.swift              Main tab flow and login screen
  UploadView.swift               Mail upload, OCR, AI analysis, and result UI
  OCRService.swift               Vision OCR and PDF text extraction
  BackendMailAnalysisService.swift
                                  Callable Functions AI analysis integration
  AuthSession.swift              Auth state, Google sign-in, guest mode, cloud sync flow
  FirestoreCloudSyncService.swift
                                  Callable Functions cloud sync service
  CloudSyncModels.swift          Cloud sync DTOs
  MailModels.swift               SwiftData models for mail records and to-do items
  TodoListView.swift             Pending/completed task views
  HistoryView.swift              Mail analysis history
```

## Setup

1. Open `MailMind.xcodeproj` in Xcode.
2. Add Firebase iOS SDK packages to the app target:
   - `FirebaseCore`
   - `FirebaseAuth`
   - `FirebaseFirestore`
   - `FirebaseFunctions`
3. Add Google Sign-In packages if not already present:
   - `GoogleSignIn`
   - `GoogleSignInSwift`
4. In Firebase Console, create an iOS app with the same bundle identifier as the Xcode target.
5. Download `GoogleService-Info.plist` from Firebase Console and add it to the local Xcode app target.
6. Enable Google sign-in in Firebase Authentication.
7. Install Firebase CLI and Functions dependencies:

   ```bash
   npm install -g firebase-tools
   cd functions
   npm install
   ```

8. Create `functions/.env` from `functions/env.example`. Generate the encryption key with:

   ```bash
   node -e "console.log(require('crypto').randomBytes(32).toString('base64'))"
   ```

9. Run the app in Debug on iOS Simulator. Debug builds use the deployed Firebase backend by default.

For production, Firestore rules should block direct client access because authenticated sync goes through backend functions using the Admin SDK:

```js
rules_version = '2';

service cloud.firestore {
  match /databases/{database}/documents {
    match /{document=**} {
      allow read, write: if false;
    }
  }
}
```

## Backend Configuration

The app does not store or ask users for a Gemini API key. OCR runs on-device, then the extracted English text is sent to Firebase Functions. The backend calls Gemini 3 Flash and writes encrypted sensitive fields to Firestore.

Set the production Gemini API key before deploying Functions:

```bash
firebase functions:secrets:set MAILMIND_GEMINI_API_KEY
```

For local Functions development, create `functions/.env` from `functions/env.example` and set `GEMINI_API_KEY`.

Sensitive Firestore fields are encrypted with AES-256-GCM before storage:

- mail record `summary`
- mail record `suggestedTodoTitles`
- todo item `title`
- todo item `mailSummary`

## Security Notes

Do not commit local Firebase configuration or API keys to the repository.

The repository ignores:

```text
GoogleService-Info.plist
**/GoogleService-Info.plist
.env
.env.*
functions/node_modules/
functions/lib/
```

If a Firebase API key or configuration file was committed accidentally:

1. Remove it from Git tracking.
2. Restrict the API key in Google Cloud Console to the iOS bundle identifier.
3. Rotate the key if needed.
4. Resolve the GitHub secret scanning alert after the key is restricted or rotated.

## Data Model

Authenticated user data is stored by backend functions in Firestore under:

```text
users/{uid}/mailRecords/{recordId}
users/{uid}/todoItems/{todoId}
```

Guest data is stored locally with SwiftData and is not synced to Firestore.

## Current Status

MailMind currently supports local mail OCR, to-do management, Google sign-in, backend-backed Gemini analysis, and encrypted Firestore sync for authenticated users. Apple sign-in is present in the UI but still requires provider implementation before it can be used.
