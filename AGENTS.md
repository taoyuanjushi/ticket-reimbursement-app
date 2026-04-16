# AGENTS.md

## Project
Flutter mobile app: 电子票据夹 / 发票归档 App

## Goal
Build the first MVP of a local-first Flutter app for storing receipts/invoices,
organizing them into reimbursement sheets, and exporting CSV summaries.

## Tech stack
- Flutter
- flutter_riverpod
- drift + sqlite
- local file storage
- no login
- no cloud sync
- Android first

## Product scope for MVP
Must have:
- import image or PDF
- create/edit/delete ticket
- ticket list with filters
- reimbursement sheet list/detail
- attach tickets to reimbursement sheets
- CSV export
- local notifications for pending reimbursement
- clean project structure

Do not build yet:
- cloud sync
- OCR
- invoice verification
- team collaboration
- web admin
- iOS-specific polishing

## Coding rules
- Keep code simple and readable
- Prefer small files and clear feature folders
- Avoid over-engineering
- Use Riverpod for state
- Use Drift for local DB
- Keep UI clean and minimal
- Add comments only where logic is non-obvious

## Validation
Before finishing any milestone:
- run flutter pub get
- run dart run build_runner build --delete-conflicting-outputs
- run flutter analyze
- run flutter test if tests exist

## Output style
For each completed milestone:
1. summarize what changed
2. list files added/modified
3. list commands run
4. list anything still incomplete

## Language
- All user-facing app text must be in Simplified Chinese.
- Use Chinese labels for navigation, buttons, forms, status text, and empty states.
- Keep code identifiers in English, but UI copy must be Chinese.

## Localization scope for MVP
- MVP is Chinese-only.
- Do not add full i18n support yet.
- Use RMB currency style where needed.
- Use Chinese-friendly dates and wording.