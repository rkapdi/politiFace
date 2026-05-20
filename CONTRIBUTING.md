# Contributing to Politiface

Politiface is fully open source (MIT License). Contributions are welcome and appreciated.

There are two distinct contribution paths depending on your background:

---

## Path 1: Adding a Country Deck (No Programming Required)

If you are an IR student, MUN participant, or political scientist, you can add your country's politicians without writing any code. You only need to edit YAML files — a structured text format that looks like this:

```yaml
- id: uk-commons-starmer
  name: "Keir Starmer"
  title: "Prime Minister"
  party: "Labour"
  source: "https://www.gov.uk/government/people/keir-starmer"
```

### Step 1: Check what already exists

Browse `content/governments/` to see which countries have been defined. Browse `content/decks/` to see which decks exist for those countries.

### Step 2: Fork the repository

Click "Fork" at the top of this page. This creates your own copy where you can make changes.

### Step 3: Add or edit YAML files

**To add a new country government:**
Copy `content/governments/us/government.yaml` as a template. Edit it to define your country's nodes (institutions) and edges (relationships between them). Every field is documented inline.

**To add cards to an existing deck:**
Find the appropriate deck YAML in `content/decks/` and add your cards following the existing format.

### Step 4: Verify your card sources

Every card **must** have a `source` field pointing to an official government website. This is non-negotiable for accuracy and neutrality. Examples:
- `https://www.parliament.uk/biographies/commons/...`
- `https://www.gov.uk/government/people/...`
- `https://www.bundestag.de/abgeordnete/...`

### Step 5: Check the neutrality guidelines

Read the [Editorial Neutrality Guidelines](#editorial-neutrality) below before submitting.

### Step 6: Open a pull request

Submit your changes. The CI pipeline will automatically validate your YAML for structure errors. A maintainer will review for content accuracy and neutrality before merging.

---

## Path 2: Code Contributions (Developers)

### Prerequisites

- Flutter SDK ≥ 3.22.0
- Dart SDK ≥ 3.3.0
- Supabase account (free tier is fine for development)

### Setup

```bash
# 1. Fork and clone the repo
git clone https://github.com/your-username/politiface.git
cd politiface

# 2. Install Flutter dependencies
cd app
flutter pub get

# 3. Generate Drift + Riverpod code
dart run build_runner build --delete-conflicting-outputs

# 4. Set up environment variables
cp .env.example .env
# Edit .env with your Supabase credentials

# 5. Run the tests (must pass before any code changes)
flutter test test/

# 6. Start the app
flutter run
```

### Before Submitting a PR

- [ ] All existing tests pass: `flutter test`
- [ ] No lint errors: `flutter analyze`
- [ ] New features have unit tests
- [ ] The FSRS algorithm tests pass: `flutter test test/features/session/domain/`
- [ ] The PR description explains what changed and why

---

## Editorial Neutrality Guidelines

Politiface is built on trust. Any perception of political bias can destroy that trust permanently. Every contributor is responsible for maintaining strict neutrality.

### The rules

**Identical structure for all parties.** Every card has the same fields in the same format regardless of the politician's party.

**Official sources only.** Card content must be sourced from official government websites, official party websites, or nonpartisan biographical sources. No newspaper articles, no opinion pieces, no campaign materials.

**No controversy content.** Scandals, allegations, legal proceedings, and political controversies are never included in card content. The one-liner describes their role, not their reputation.

**Neutral language.** Describe what they do, not how you feel about it. "Leads the Department of Education" not "oversees education policy" (which implies commentary on whether the department leads or oversees anything).

**Symmetry in selection.** If you include the RNC chair, include the DNC chair. If you include a prominent former Republican president, include a prominent former Democratic president. This applies to every country's political landscape.

**Photo consistency.** Use official government headshots for everyone. Not campaign photos, not press photos, not photos you chose because they are flattering or unflattering.

### When in doubt

If you are unsure whether something is neutral, it probably is not. Ask in the PR comments and a maintainer will help.

---

## Reporting a Security Vulnerability

Do not open a public GitHub issue for security vulnerabilities.

Email: security@politiface.io

We will respond within 48 hours.

---

## Analytics and Privacy

Politiface collects minimal, opt-in analytics. The complete list of events we track is in [VERIFIED.md](VERIFIED.md). We never collect:

- Which specific politicians you review
- Whether you got a specific card right or wrong
- Your political preferences or affiliations (this is the whole point of being open source)

---

## License

By contributing, you agree that your contributions will be licensed under the MIT License.
