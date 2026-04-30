# MailMind

MailMind is an iOS app that helps Chinese-speaking users understand English physical mail. Users can upload photos or PDFs of mail, extract the text on-device, generate a concise Chinese summary with AI, classify the mail type, and turn important actions into trackable to-do items.

The app is designed for everyday mail such as bills, government notices, insurance letters, tax documents, banking mail, healthcare notices, school letters, advertisements, and personal correspondence.

## Features

- Upload mail from the photo library, including multiple photos for multi-page letters.
- Import PDF files and analyze them as a single mail item.
- Run on-device OCR with Apple Vision for images and rendered PDFs.
- Use OpenAI's Responses API to summarize English mail in Simplified Chinese.
- Categorize mail into practical categories such as bills, government, banking, insurance, healthcare, tax, legal, school, advertisement, personal, and other.
- Extract actionable tasks and suggested deadlines from each mail item.
- Add suggested tasks to a built-in to-do list.
- Track pending and completed tasks.
- View historical mail analyses and generated action items.
- Continue as a guest with local-only data.
- Sign in with Google through Firebase Authentication.
- Sync authenticated user data to Cloud Firestore under each user's own `users/{uid}` path.

## Tech Stack

- **Platform:** iOS
- **Language:** Swift
- **UI:** SwiftUI
- **Local persistence:** SwiftData
- **OCR:** Apple Vision, PDFKit, PhotosUI
- **Authentication:** Firebase Authentication, Google Sign-In
- **Cloud sync:** Cloud Firestore
- **AI analysis:** OpenAI Responses API with structured JSON output
- **Testing:** XCTest and XCUITest
- **Package management:** Swift Package Manager

## Project Structure

```text
MailMind/
  MailMindApp.swift              App entry point and Firebase initialization
  ContentView.swift              Main tab flow and login screen
  UploadView.swift               Mail upload, OCR, AI analysis, and result UI
  OCRService.swift               Vision OCR and PDF text extraction
  MailAnalysisService.swift      OpenAI Responses API integration
  AuthSession.swift              Auth state, Google sign-in, guest mode, cloud sync flow
  FirestoreCloudSyncService.swift
  CloudSyncModels.swift          Firestore DTOs
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
3. Add Google Sign-In packages if not already present:
   - `GoogleSignIn`
   - `GoogleSignInSwift`
4. In Firebase Console, create an iOS app with the same bundle identifier as the Xcode target.
5. Download `GoogleService-Info.plist` from Firebase Console and add it to the local Xcode app target.
6. Enable Google sign-in in Firebase Authentication.
7. Create a Cloud Firestore database.
8. Configure Firestore rules so signed-in users can only read and write their own data.

Example Firestore rule:

```js
rules_version = '2';

service cloud.firestore {
  match /databases/{database}/documents {
    match /users/{userId} {
      allow read, write: if request.auth != null && request.auth.uid == userId;

      match /{document=**} {
        allow read, write: if request.auth != null && request.auth.uid == userId;
      }
    }
  }
}
```

## OpenAI Configuration

The app includes an in-app AI settings screen where a developer/tester can enter:

- OpenAI API key
- OpenAI model name, defaulting to `gpt-4.1-mini`

During local development, OCR runs on-device and only the extracted English text is sent to OpenAI for analysis.

For a production release, the OpenAI call should be moved behind a backend service so API keys are not stored or entered directly in the app.

## Security Notes

Do not commit local Firebase configuration or API keys to the repository.

The repository ignores:

```text
GoogleService-Info.plist
**/GoogleService-Info.plist
.env
.env.*
```

If a Firebase API key or configuration file was committed accidentally:

1. Remove it from Git tracking.
2. Restrict the API key in Google Cloud Console to the iOS bundle identifier.
3. Rotate the key if needed.
4. Resolve the GitHub secret scanning alert after the key is restricted or rotated.

## Data Model

Authenticated user data is stored in Firestore under:

```text
users/{uid}/mailRecords/{recordId}
users/{uid}/todoItems/{todoId}
```

Guest data is stored locally with SwiftData and is not synced to Firestore.

## Current Status

MailMind currently supports local mail analysis, to-do management, Google sign-in, and Firestore-backed sync for authenticated users. Apple sign-in is present in the UI but still requires provider implementation before it can be used.
