# Prompt.md

## Product
电子票据夹 / 发票归档 App

## Users
Students, interns, freelancers, and people who need to manage reimbursement materials.

## MVP features
- Home page with quick stats
- Ticket list page
- Add/edit ticket page
- Ticket detail page
- Reimbursement sheet list page
- Reimbursement sheet detail page
- Settings page
- Local file import: image and PDF
- Ticket fields: title, amount, date, type, status, note
- Filter by month, type, and reimbursement status
- CSV export
- Local notifications
- SQLite storage via Drift

## Non-goals
- No OCR
- No cloud sync
- No login
- No backend
- No invoice authenticity verification

## Done when
- App can run on Android emulator
- Core pages are navigable
- Tickets can be created, edited, deleted, and listed
- Reimbursement sheets can be created and linked to tickets
- CSV export works
- Project builds successfully
- flutter analyze passes

## UI language
- All visible UI must be Simplified Chinese.
- Bottom tabs must use Chinese:
  - 首页
  - 票据
  - 报销单
  - 设置
- Forms, buttons, placeholders, empty states, and status labels must all be Chinese.
- Do not implement multilingual switching in MVP.