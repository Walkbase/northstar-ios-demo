# Setup

1. Clone this repository and ensure you are on the `main` branch (not
   `develop`).
1. Open the project in XCode.
1. Open the "Signing & Capabilities" tab in XCode’s project editor and edit the
   following:
   - `Team`: Select your team/account.
   - `Bundle Identifier`: Enter a valid ID.
1. Open the "General" tab and add `Northstar.xcframework` as a framework to the
   project.
   - You receive the file from Walkbase.
1. You can run now build and run the project! 🎉

## Notes

You can ignore the following warning in XCode's Issue Navigator:

```sh
sentry-cli - error: Auth token is required for this request. Please run `sentry-cli login` and try again!
```
