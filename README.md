# Pocket sunBEAR 🐻

**Research, collected. Wherever you are.**

Pocket sunBEAR is a native **iPhone and iPad research companion** to [sunBEAR](https://github.com/lux042/sunBEAR). It helps researchers explore academic and archival databases, capture citation metadata from search results, organize research sessions, download accessible PDFs, and export records for further analysis.

Designed for researchers who move between archives, journals, and databases, Pocket sunBEAR brings discovery and organization into a mobile workflow.

## Features

- **Browse research sources** through an embedded browser without leaving the app.
- **Capture metadata** from visible search-results pages using source-specific parsers.
- **Organize research sessions** locally for later reference.
- **Download available PDFs** when direct, authorized files are accessible; validate downloaded documents before saving.
- **Export citations and records** as EndNote tagged files (`.enw`) or tab-separated values (`.tsv`).
- **Share exports** using the native iOS share sheet.

## Supported research sources

| Source | Research focus |
| --- | --- |
| CIA FOIA Electronic Reading Room | Declassified intelligence and government documents |
| JSTOR | Scholarly journals and academic publications |
| ERIC | Education research |
| PubMed | Biomedical and life-sciences literature |
| National Archives Catalog | U.S. archival records and collections |

Metadata extraction depends on the currently visible results and the structure of each source's website. Pocket sunBEAR does not bypass paywalls, institutional logins, or publisher access restrictions.

## Built with

**Swift · SwiftUI · WebKit · Native iOS file and sharing APIs**

The project includes dedicated parsing components for supported research sources, a coordinator for gathering results, PDF download handling, and export services.

## How it works

1. **Choose a source** and browse its search results inside the app.
2. **Import visible records** into a research session.
3. **Download accessible PDFs** if the download option is enabled.
4. **Review saved records** and export them as EndNote or TSV files.

### Where files are saved

Downloaded PDFs are organized by research session in the **Downloads** tab. Files are stored under:

```text
Files → On My iPhone → Pocket sunBEAR → Pocket sunBEAR PDFs
```

Citation exports are saved under:

```text
Files → On My iPhone → Pocket sunBEAR → Pocket sunBEAR Exports
```

Exports can also be sent to other apps through the iOS share sheet.

## Getting started

**Requirements:** Xcode and an iPhone or iPad running **iOS 18 or later**, or a compatible simulator.

1. Clone the repository:
   ```bash
   git clone https://github.com/lux042/pocket-sunBEAR.git
   cd pocket-sunBEAR
   ```
2. Open `sunBEAR.xcodeproj` in Xcode.
3. Select the `PocketSunBEAR` scheme.
4. Build and run on a compatible iOS device or simulator.

Some research sites require authentication or institutional access. Those pages remain accessible through their original source links when direct PDF retrieval is unavailable.

## Project status

Pocket sunBEAR is an evolving research tool. Site-specific metadata extraction and PDF availability can change as external websites change. Future improvements may focus on parser resilience, accessibility, and research-session usability.

## Related project

**[sunBEAR](https://github.com/lux042/sunBEAR)** — the companion cross-platform research project.

---

Developed by [lux042](https://github.com/lux042).