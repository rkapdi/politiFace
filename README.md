# Politiface

Civic-education app: spaced-repetition practice on how the US government works, plus
Florida Civic Literacy Exam (FCLE) practice, a cited civic reference (Atlas), and live
class sessions. Available on the App Store; website at [politiface.app](https://politiface.app).

Open source under the MIT license so anyone can audit exactly what students see and
what the app does with their data. See [LICENSE](LICENSE).

## Repository layout

| Path | What it is |
| --- | --- |
| `app/` | Flutter app (iOS). See [`app/README.md`](app/README.md). |
| `web/` | React + Vite web app served at politiface.app/app. See [`web/README.md`](web/README.md). |
| `supabase/` | Backend: Postgres migrations, row-level security, RPCs, Edge Functions, tests. See [`supabase/README.md`](supabase/README.md). |
| `content/` | Canonical content as YAML: government structure, people, Atlas, FCLE objectives and question bank. See [`content/questions/README.md`](content/questions/README.md). |
| `scripts/` | Content ingest, validation and data refresh scripts. |
| `docs/` | The public website (GitHub Pages), including the privacy policy and support pages. |

## Privacy

The privacy policy is at [politiface.app/privacy-policy](https://politiface.app/privacy-policy/).
The app never collects political affiliation or voting history.

## Contributing

Corrections to civic content are welcome: open an issue with the fix and a primary
source.

## License

MIT. See [LICENSE](LICENSE).
