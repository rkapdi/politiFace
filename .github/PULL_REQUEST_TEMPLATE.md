## What changed

<!-- Brief description of what this PR does -->

## Type of change

- [ ] Bug fix
- [ ] New feature (app code)
- [ ] New country deck (YAML content)
- [ ] New politician cards (YAML content)
- [ ] Infrastructure / CI change
- [ ] Documentation

## Testing

- [ ] All existing tests pass (`flutter test`)
- [ ] New code has unit tests
- [ ] Tested on iOS simulator
- [ ] Tested on Android emulator
- [ ] Tested on web (Chrome)
- [ ] FSRS algorithm tests pass (`flutter test test/features/session/domain/`)

## Content changes (fill in if adding/editing YAML)

- [ ] All cards have official `source` URLs (government websites only)
- [ ] `last_verified` date is today
- [ ] Card descriptions are neutral (no partisan language, no controversy content)
- [ ] Description length is consistent across parties
- [ ] Photo sources are official government headshots
- [ ] If adding a party chair from one party, the opposing party chair is also included
- [ ] Government YAML validation passes locally:
  ```
  python3 scripts/validate_government.py content/governments/{country}/government.yaml
  ```

## Screenshots (if UI changes)

<!-- Add before/after screenshots for any visual changes -->
