# Google Sign-In Setup Instructions

## 1. Add Google Sign-In SDK via Swift Package Manager

1. Open your project in Xcode
2. Go to **File** → **Add Package Dependencies...**
3. Enter the package URL: `https://github.com/google/GoogleSignIn-iOS`
4. Select version **7.0.0** or later
5. Click **Add Package**
6. Select the **GoogleSignIn** library and click **Add Package**

## 2. Create Google Cloud Project and OAuth 2.0 Client

1. Go to [Google Cloud Console](https://console.cloud.google.com/)
2. Create a new project or select an existing one
3. Enable **Google Sign-In API**:
   - Go to **APIs & Services** → **Library**
   - Search for "Google Sign-In API"
   - Click **Enable**
4. Create OAuth 2.0 Client ID:
   - Go to **APIs & Services** → **Credentials**
   - Click **Create Credentials** → **OAuth client ID**
   - Select **iOS** as application type
   - Enter your **Bundle ID** (e.g., `vjiki`)
   - Click **Create**
   - Copy the **Client ID**

## 3. Download and Add GoogleService-Info.plist

1. Go to [Firebase Console](https://console.firebase.google.com/)
2. Create a new project or select existing one
3. Add iOS app with your Bundle ID
4. Download `GoogleService-Info.plist`
5. Add `GoogleService-Info.plist` to your Xcode project:
   - Drag the file into the `byrdio` folder in Xcode
   - Make sure "Copy items if needed" is checked
   - Select your target

## 4. Configure URL Scheme

The URL scheme will be automatically configured from `GoogleService-Info.plist` (REVERSED_CLIENT_ID).

If you need to add it manually:
1. Open your project in Xcode
2. Select your target
3. Go to **Info** tab
4. Under **URL Types**, click **+**
5. Add URL Scheme from `REVERSED_CLIENT_ID` in `GoogleService-Info.plist`

## 5. Verify Setup

After completing the above steps:
- The app should be able to sign in with Google
- The Client ID will be automatically read from `GoogleService-Info.plist`
- URL handling is configured in `byrdioApp.swift`

## Troubleshooting

- If you see "Google Client ID is missing" error, make sure `GoogleService-Info.plist` is added to the project and contains `CLIENT_ID`
- If sign-in doesn't work, verify the Bundle ID matches the one configured in Google Cloud Console
- Make sure the URL scheme is properly configured in Info.plist

