// The platform-neutral primitives (units, provenance, hardware identifiers, formatting) live in
// SpecMatrixShared so the macOS app can use them without linking the iOS catalog. Re-exporting them
// keeps every existing `import SpecMatrixCore` (iOS app, Platform, State, tests) working unchanged.
@_exported import SpecMatrixShared
