# ROADMAP

Post-launch projects, recorded so a future session can pick them up cold.
(Pre-launch phase work is tracked in [PROGRESS.md](PROGRESS.md).)

---

## Over-the-air content packs

**Status:** recorded 2026-06-11, not started. Founder-approved design sketch below.
**Priority:** first post-launch project — or pre-launch if all phases complete early.
**Estimated scope:** ~2 days.

### Goal

Ship content updates (new politicians, government graph changes, concept cards) to all
installed apps without an App Store release. Content is data, not code, so this is
App Review compliant.

### Design sketch

- Host content YAMLs + a manifest (content version, checksums, minimum supported
  schema version) on static hosting, likely GitHub Pages alongside `docs/`.
- On app launch: fetch the manifest (single small request). If the remote checksum
  differs from the locally seeded version, download the pack, validate it with the
  same schema rules as CI, and upsert into Drift, preserving all FSRS memory state,
  streaks, and XP.
- Offline behavior unchanged: bundled YAML remains the fresh-install fallback; cached
  content keeps working with no connection.
- Integrity: hash/signature check on the downloaded pack; reject tampered or
  truncated files.
- Schema version pinning: old app versions ignore packs they cannot parse.
- Apply policy: packs apply at launch or between sessions only, never mid-round.
- Portraits: new politicians use a remote `photo_url` with `cached_network_image`
  rather than bundled images.

### Depends on

The Phase 3 checksum-based reseeding pipeline (see PROGRESS.md). This feature adds a
remote trigger to that same mechanism — build Phase 3's local checksum/reseed path
first, then OTA becomes "fetch, verify, hand the YAML to the same seeder."

### Tests required when built

- Simulate a v1.1 pack arriving on a device with live user state; verify no data loss.
- Offline fallback (no manifest reachable → app behaves exactly as today).
- Rejection of bad checksums (tampered/truncated pack is discarded, current content
  stays active).
- Rejection of packs above the supported schema version.
