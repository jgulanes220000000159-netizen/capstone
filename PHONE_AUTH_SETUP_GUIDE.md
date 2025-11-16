# Phone Authentication Setup Guide

## Step 1: Get SHA-1 and SHA-256 Certificates

### Option A: Using Gradle (Recommended)
1. Open terminal/command prompt in your project root
2. Navigate to android folder:
   ```bash
   cd android
   ```
3. Run this command:
   ```bash
   gradlew signingReport
   ```
   (On Windows: `gradlew.bat signingReport`)

4. Look for output like this:
   ```
   Variant: debug
   Config: debug
   Store: C:\Users\...\.android\debug.keystore
   Alias: AndroidDebugKey
   SHA1: XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX
   SHA-256: XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX
   ```

5. **Copy both SHA-1 and SHA-256 values** (you'll need them in Step 2)

### Option B: Using Keytool (Alternative)
If gradlew doesn't work, use keytool:
```bash
keytool -list -v -keystore "%USERPROFILE%\.android\debug.keystore" -alias androiddebugkey -storepass android -keypass android
```

---

## Step 2: Configure Firebase Console

### 2.1 Enable Phone Authentication
1. Go to [Firebase Console](https://console.firebase.google.com/)
2. Select your project: **mango-leaf-analyzer**
3. Click **Authentication** in the left menu
4. Click **Sign-in method** tab
5. Find **Phone** in the list and click on it
6. Toggle **Enable** to ON
7. Click **Save**

### 2.2 Add SHA Certificates to Android App
1. In Firebase Console, click the **⚙️ Settings** (gear icon) next to "Project Overview"
2. Select **Project settings**
3. Scroll down to **Your apps** section
4. Find your Android app (package: `com.example.capstone`)
5. Click **Add fingerprint** button
6. Add both:
   - **SHA-1**: Paste the SHA-1 value from Step 1
   - **SHA-256**: Paste the SHA-256 value from Step 1
7. Click **Save**

### 2.3 (Optional) Add Test Phone Numbers
For testing during development (to avoid SMS costs):
1. In **Authentication → Sign-in method → Phone**
2. Scroll to **Phone numbers for testing** section
3. Click **Add phone number** button
4. Add test numbers in Philippine format:
   - **Phone number:** `+639123456789` (use +63 country code)
   - **Verification code:** `123456` (any 6-digit code you want)
5. Click **Add** button
6. Click **Save** at the bottom

**Note:** 
- Test numbers bypass SMS verification, so you won't receive real SMS during testing
- You can use the test verification code you set (e.g., 123456) instead of waiting for SMS
- This is OPTIONAL - you can skip this and use real SMS if you prefer
- For production, real SMS will be sent to Philippine numbers automatically

---

## Step 3: Download Updated google-services.json (if needed)
After adding SHA certificates:
1. In Firebase Console → Project settings → Your apps
2. Click **Download google-services.json**
3. Replace the file at: `android/app/google-services.json`

---

## Step 4: Test the Implementation
After completing the code changes:
1. Run the app
2. Try signing up with phone number only (no email)
3. You should receive an SMS with verification code
4. Enter the code to complete registration

---

## Troubleshooting

### Issue: "reCAPTCHA verification failed"
- **Solution:** Make sure SHA-1 and SHA-256 are correctly added in Firebase Console
- Wait a few minutes after adding certificates for changes to propagate

### Issue: "Invalid phone number format"
- **Solution:** Phone numbers must be in E.164 format: +[country code][number]
- Example: +639123456789 (Philippines)

### Issue: SMS not received
- **Solution:** 
  - Check if you're using a test phone number (use test code instead)
  - Verify phone number format is correct
  - Check Firebase Console for quota limits
  - For production, ensure Firebase Blaze plan (paid) is enabled

---

## Important Notes

1. **Free Tier Limitation:** Firebase Phone Auth has limited free SMS per day. For production, you may need a Blaze (pay-as-you-go) plan.

2. **Phone Number Format:** Always use international format with country code (e.g., +63 for Philippines)

3. **Testing:** Use test phone numbers during development to avoid SMS costs

4. **Production:** Make sure to add release keystore SHA certificates before releasing to production

