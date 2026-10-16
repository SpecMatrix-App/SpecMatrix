# EXPECTED UPDATE BY JANUARY 2027

# SpecMatrix

SpecMatrix is an iOS application designed to provide an innovative solution for users. It offers a comprehensive suite of tools to monitor and analyze your device's performance, network, and hardware capabilities, all in one intuitive interface. By providing real-time insights and detailed metrics, SpecMatrix empowers users to better understand and manage their devices.

## Features
- **Network Monitoring**:
  - Show connection status and type (Wi‑Fi or Cellular).
- **Device Information**:
  - Display detailed information about the device, including GPU and CPU specifications.
- **Performance Tracking**:
  - Real-time monitoring of RAM usage.
  - View storage usage and manage available space.
- **Battery Health**:
  - Monitor battery status and performance.
- **Camera Information**:
  - Access and display technical details about the device's camera system.

## Installation
To install and run the app, follow these steps based on your role:

### For Developers:
1. Clone this repository:
   ```bash
   git clone https://github.com/belligerently/SpecMatrix
   ```
2. Open the project in Xcode and connect your iOS device or simulator.
3. Build and run the project directly through Xcode.

### For Normal Users:
1. Download on the App Store: [SpecMatrix](https://apps.apple.com/us/app/specmatrix/id6740110428)

OR
   
1. Download the IPA file from the [release section](https://github.com/Belligerently/SpecMatrix/releases) of this repository (most up to date).
2. Install the IPA file using a sideloading app such as [SideStore](https://sidestore.io) or [AltStore](https://altstore.io), which allow sideloading of up to 3 apps.

   Alternatively, you can use a certificate (.p12 and .mobileprovision) from an Apple Developer account, [KravaSign](https://kravasign.com), or another certificate-providing service. Certificates are required for sideloading because Apple restricts the installation of apps outside the App Store for security reasons. These certificates verify the app's authenticity and allow it to be installed on your device. After obtaining the certificate, you can use an app like [Feather Sign](https://github.com/khcrysalis/Feather) to sign and install the app.

3. Follow the instructions provided by the sideloading app or signing tool to complete the installation.

## Building and Testing

The project uses one shared Xcode scheme, `SpecMatrix`, which builds the app and both test bundles (`SpecMatrixTests`, `SpecMatrixUITests`). The project has no package dependencies.

**Requirements:** a version of Xcode that can open this project (it was created with Xcode 16.2) and an iOS Simulator runtime of iOS 18.2 or later. The commands below were verified with Xcode 27.0 and the iOS 27.0 simulator.

If `xcode-select -p` prints `/Library/Developer/CommandLineTools`, `xcodebuild` will not work. Either select Xcode with `sudo xcode-select -s /Applications/Xcode.app`, or prefix each command with `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer`.

List the available simulators with `xcrun simctl list devices available`. Replace `iPhone 17` below with any iPhone simulator from that list.

```bash
# Build for the simulator (no signing required)
xcodebuild build -project SpecMatrix.xcodeproj -scheme SpecMatrix \
  -destination 'platform=iOS Simulator,name=iPhone 17' CODE_SIGNING_ALLOWED=NO

# Run the unit tests
xcodebuild test -project SpecMatrix.xcodeproj -scheme SpecMatrix \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -only-testing:SpecMatrixTests CODE_SIGNING_ALLOWED=NO
```

**UI tests.** The UI tests can't run with `CODE_SIGNING_ALLOWED=NO`, because the UI test runner app must be signed. To run them on a simulator without a development team, use ad-hoc signing:

```bash
xcodebuild test -project SpecMatrix.xcodeproj -scheme SpecMatrix \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -only-testing:SpecMatrixUITests \
  CODE_SIGN_IDENTITY=- CODE_SIGN_STYLE=Manual DEVELOPMENT_TEAM=
```

The UI tests launch the app several times (`testLaunchPerformance`), so expect them to take several minutes.

**Foundation package tests.** Most unit tests live in the local package `Packages/SpecMatrixKit` (see its [README](Packages/SpecMatrixKit/README.md)). The `-only-testing:SpecMatrixTests` command above does not run them.

```bash
# macOS (fast)
swift test --package-path Packages/SpecMatrixKit

# iOS Simulator (run from Packages/SpecMatrixKit)
xcodebuild test -scheme SpecMatrixKit -destination 'platform=iOS Simulator,name=iPhone 17'
```

**Running on a physical device** requires signing with your own Apple ID or team in Xcode (*Signing & Capabilities*).

## Requirements
- iOS 18.2 or later.

## Compatibility
Currently, the app is designed to work only on iPhones. Support for other devices will be added in future updates.

## App Metadata
- **App Name**: SpecMatrix
- **Bundle Identifier**: `com.zacdevv.SpecMatrix`
- **Version**: 1.0
- **Build Number**: 1

## Assets
- Compiled assets catalog (`Assets.car`) for optimized resource management.

## License
This project is licensed under the MIT License.

## Contributing
Contributions are welcome! Please submit a pull request or create an issue to discuss your idea.

## Contact
For any inquiries or support, please contact [spec.matrix.app@gmail.com] or create an issue and we will assist you!
