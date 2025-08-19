# Brain overview

This folder is the public snapshot I query by path/section.

Primary views
- brain.txt    : compact narrative snapshot
- brain.csv    : index of important artifacts

Indexes
- Indexes\listing.csv      : full inventory (relPath,sizeBytes,lastWriteUtc,sha256)
- Indexes\listing_prev.csv : previous inventory
- Indexes\recent.txt       : human-readable delta since last snapshot

Query order
1) Check Indexes\recent.txt to see what changed lately.
2) Use Indexes\listing.csv to resolve exact file paths.
3) Read the specific file/section you need (never dump whole files).
