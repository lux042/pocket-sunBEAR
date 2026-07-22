# Pocket sunBEAR

Pocket sunBEAR is the iPhone and iPad companion to sunBEAR. It opens supported research databases in an embedded browser, imports metadata from a visible search-results page, stores research sessions locally, and shares EndNote tagged files or TSV exports.

Supported sources:

- CIA FOIA Electronic Reading Room
- JSTOR
- ERIC
- PubMed
- National Archives Catalog

When **Download available PDFs** is enabled, Pocket sunBEAR downloads direct, authorized PDFs and validates each file before saving it. Downloads are grouped by research session in the app's **Downloads** tab and future downloads use matching session subfolders in **Files → On My iPhone → Pocket sunBEAR → Pocket sunBEAR PDFs**. Sources that require login, institutional access, or publisher interaction remain available through their source-record links.

EndNote (`.enw`) and TSV exports are saved in **Files → On My iPhone → Pocket sunBEAR → Pocket sunBEAR Exports** and are also presented in the iOS share sheet.

## Development

Open `PocketSunBEAR.xcodeproj` in Xcode and run the `PocketSunBEAR` scheme on an iOS 18 or newer iPhone/iPad simulator or device.
