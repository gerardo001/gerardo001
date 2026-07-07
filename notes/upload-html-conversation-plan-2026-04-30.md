# Upload HTML Local Docker + SAS Troubleshooting Plan

Date: 2026-04-30
Project root: C:/repos/gerardo001

## Objective
Run `utilities/files/upload.html` locally in a reliable browser origin and fix the file list loading failure for Azure Blob SAS access.

## Summary Of What Was Done
1. Hardened client-side SAS URL handling in `utilities/files/upload.html`.
2. Added HTTP status checks and Azure XML error parsing for list requests.
3. Improved user-facing error details for list failures (SAS/CORS/time-window guidance).
4. Added upload and delete non-2xx handling.
5. Created Docker image support to serve the HTML via localhost origin.
6. Built and validated image locally with HTTP 200 smoke test.

## Implemented Changes
### File: utilities/files/upload.html
- Added URL-safe helpers:
  - `getBlobUrl(blobName)`
  - `getListUrl()`
- Added `escapeHtml()` for safe error rendering.
- Upload path now uses helper URLs and checks `xhr.status`.
- List path now checks `response.ok` and extracts Azure XML `Code` and `Message`.
- Delete path now checks `response.ok` and reports failures.

### File: utilities/files/Dockerfile
- Added minimal nginx-based image to serve `upload.html` as:
  - `/`
  - `/upload.html`

## Verified Results
1. Docker image build succeeded: `upload-html-local`.
2. Container smoke test on `http://localhost:8080` returned HTTP 200.

## Required Azure Configuration For Local Dev
Use Blob CORS with local origin:
1. Allowed origins: `http://localhost:8080`
2. Allowed methods: `GET,PUT,DELETE,OPTIONS`
3. Allowed headers: `*`
4. Exposed headers: `*`
5. Max age: `3600`

## Key Troubleshooting Notes
1. SAS token must include list permission (`sp` contains `l`) for container listing.
2. SAS start time (`st`) must not be in the future relative to current UTC time.
3. If listing still fails, the page now displays Azure error details from XML response.

## Runbook
1. Build image:
   - `docker build -t upload-html-local ./utilities/files`
2. Run container:
   - `docker run --name upload-html-local -p 8080:80 upload-html-local`
3. Open app:
   - `http://localhost:8080`
4. Stop/remove container when done:
   - `docker rm -f upload-html-local`

## Remaining Optional Improvements
1. Add `docker-compose.yml` for one-command startup.
2. Move SAS token out of HTML into environment-backed config.
3. Add retry/backoff for transient storage failures.
4. Add filename escaping in checkbox `onchange` attribute to handle special characters robustly.

Use one of these, depending on how you started it:

If it is running in the same terminal (foreground):
Press Ctrl+C

If you started with docker compose:
Run:
docker compose down

If you want to stop only the container:
Run:
docker stop upload-html-local

If you also want to remove that container after stopping:
Run:
docker rm -f upload-html-local

If you want, I can run the exact stop command for you now.
