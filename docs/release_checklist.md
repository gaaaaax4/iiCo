# iiCo Release Checklist

## 1. Versioning

- [ ] Decide release version (CFBundleShortVersionString)
- [ ] Decide build number (CFBundleVersion)
- [ ] Update changelog / release notes text

## 2. App Configuration

- [x] Bundle ID is set: com.n2o.iico
- [x] iOS deployment target: 16.0
- [x] Photo library usage description present
- [x] Microphone usage description present
- [x] Non-exempt encryption flag set to false

## 3. Build Validation

- [x] Debug simulator build succeeded
- [x] Release simulator build succeeded
- [x] Release archive build succeeded (unsigned local validation)

## 4. Functional QA (manual)

- [ ] Add image(s) from photo library
- [ ] Confirm image registration cap at 100
- [ ] Confirm iiCo button disabled when conditions are unmet
- [ ] Confirm iiCo button enabled only when total probability is 100%
- [ ] Confirm weighted random output follows configured probabilities
- [ ] Confirm per-image effect setting works (none / vibration)
- [ ] Confirm per-image audio recording auto-stops at 5 seconds
- [ ] Confirm per-image audio playback on display
- [ ] Confirm deleting image also removes associated audio

## 5. Store Submission Preparation

- [ ] Finalize app name/subtitle/description/keywords
- [ ] Prepare screenshots for target devices
- [ ] Prepare App Privacy answers
- [ ] Prepare age rating answers (kids app)
- [ ] Publish privacy policy page with operator/contact details filled in
- [ ] Confirm Privacy Policy URL is set in App Store Connect
- [ ] Confirm support URL and privacy policy URL both resolve without login

## 6. Signing and Distribution

- [ ] Archive with signing in Xcode Organizer
- [ ] Validate archive in Organizer
- [ ] Upload to App Store Connect
- [ ] Enable TestFlight build and internal testing
- [ ] Review feedback and promote to external testing / submit for review
