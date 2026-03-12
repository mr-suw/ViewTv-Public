TVHeadend iOS Library
=====================

> **Origin:** This library is derived from [zipleen/tvheadend-ios-lib](https://github.com/zipleen/tvheadend-ios-lib) — a split of the model/network code originally developed for the [TvhClient](https://github.com/zipleen/tvheadend-ios-lib) app.
>
> **Active development** happens in the **[ViewTv](https://github.com/mr-suw/ViewTv-Public)** repository, where this library is maintained as an integrated sub-package under `ViewTv/tvheadend-ios-lib/`.

---

The library provides the model and network layer for communicating with a [TVHeadend](https://github.com/tvheadend/tvheadend) server — a DVB receiver, DVR and streaming server.

Compared to the upstream zipleen repository, this fork has been modernised for tvOS 18 and modern tooling:

- **AFNetworking removed** — replaced with native `NSURLSession` (Objective-C compatible)
- **CocoaPods removed** — replaced with Swift Package Manager (`Package.swift`)
- **Target platform:** tvOS 18+

## Integration (Swift Package Manager)

This library is integrated as a **local SPM package** inside the ViewTv Xcode project. No CocoaPods installation required.

```swift
// Package.swift excerpt
.package(path: "../tvheadend-ios-lib")
```

Or add directly in Xcode: **File → Add Package Dependencies → Add Local** → select the `tvheadend-ios-lib/` folder.

## Building standalone

```bash
swift build \
  --sdk "$(xcrun --sdk appletvsimulator --show-sdk-path)" \
  --triple arm64-apple-tvos18-simulator
```

## Upstream / Contributing

- Upstream origin: https://github.com/zipleen/tvheadend-ios-lib
- This fork is developed as part of: https://github.com/mr-suw/ViewTv-Public
- Pull requests and issues → ViewTv-Public repository

## License

Source code licensed under the Mozilla Public License 2.0 (MPL-2.0).
See [LICENSE.md](LICENSE.md) for details.
