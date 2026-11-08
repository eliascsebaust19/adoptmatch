# CI workflow (not installed yet)

`ci.yml` in this directory is the intended GitHub Actions workflow for AdoptMatch. It runs:

- `backend`: `npm ci`, `npm test`, `npm audit`
- `server` (legacy): `npm ci`, `npm test`, `npm audit`
- `src-frontend`: `npm ci`, `npm run build`, `npm audit`
- `ai-service`: `pip install -r requirements.txt pytest`, `pytest -q`
- Flutter: `flutter pub get`, `flutter analyze`, `flutter test`
- `backend_laravel`: `composer install`, `vendor/bin/phpunit`

## Why it is here instead of `.github/workflows/`

The branch was pushed with a GitHub App credential that does not have the
`workflows` permission, so GitHub rejected any commit that creates or updates
`.github/workflows/ci.yml`. The workflow content is preserved here unchanged so
no work is lost.

## How to enable it

Someone with permission to modify workflows (repo admin, or a token/PAT with the
`workflow` scope) should run:

```bash
mkdir -p .github/workflows
cp docs/ci/ci.yml .github/workflows/ci.yml
git add .github/workflows/ci.yml
git commit -m "ci: install AdoptMatch verification workflow"
git push
```

Until that is done, **no CI has run for this repository state**. Do not quote CI
results; only the local checks listed in `README.md` and
`audit-resolution-report.md` were actually executed.
