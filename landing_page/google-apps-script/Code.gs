/**
 * NoPlace beta signups -> Google Sheet.
 *
 * NOT part of the website. Do not move this into export-site/ — that folder is published.
 * Paste this into the Apps Script editor bound to the sheet.
 *
 * The shared secret and the sheet id live in Script Properties, never in this file, so this
 * file is safe to commit. Setup:
 *  1. Open the sheet -> Extensions -> Apps Script. Delete the stub, paste this file.
 *  2. Project Settings (gear icon) -> Script Properties -> Add script property, twice:
 *       Property: SHARED_SECRET
 *       Value:    <a long random string>
 *     The Cloudflare secret SHEET_WEBHOOK_SECRET must match this value exactly.
 *       Property: SHEET_ID
 *       Value:    <the id in the sheet URL, between /d/ and /edit>
 *     The id is not a credential, but it is the link to the signup list, so it stays
 *     out of this repo.
 *  3. Deploy -> New deployment -> type "Web app".
 *       Execute as:    Me
 *       Who has access: Anyone            <- required; the worker calls it unauthenticated
 *  4. Authorise when prompted ("Advanced" -> "Go to ... (unsafe)" is expected for your own script).
 *  5. Copy the /exec URL into the Cloudflare secret SHEET_WEBHOOK_URL.
 *
 * After ANY edit here you must run Deploy -> Manage deployments -> edit -> Version: New version.
 * Saving alone does not update the live /exec URL.
 */

var SHEET_NAME = 'Beta signups';

var HEADERS = ['Timestamp', 'Email', 'Language', 'Country', 'Source'];

function doPost(e) {
  try {
    var params = (e && e.parameter) || {};
    var props = PropertiesService.getScriptProperties();
    var secret = props.getProperty('SHARED_SECRET');

    if (!secret) {
      return json({ ok: false, error: 'secret_not_set' });
    }
    if (params.secret !== secret) {
      return json({ ok: false, error: 'unauthorized' });
    }

    // Checked after auth so an unauthenticated caller learns nothing about our config.
    var sheetId = props.getProperty('SHEET_ID');
    if (!sheetId) {
      return json({ ok: false, error: 'sheet_id_not_set' });
    }

    var email = String(params.email || '').trim().toLowerCase();
    if (!email || email.indexOf('@') === -1) {
      return json({ ok: false, error: 'invalid_email' });
    }

    // Two people submitting at once would otherwise race on the same row.
    var lock = LockService.getScriptLock();
    if (!lock.tryLock(20000)) return json({ ok: false, error: 'busy' });

    try {
      var sheet = getSheet(sheetId);
      if (hasEmail(sheet, email)) {
        return json({ ok: true, duplicate: true });
      }
      sheet.appendRow([
        new Date(),
        email,
        String(params.lang || ''),
        String(params.country || ''),
        String(params.referer || ''),
      ]);
    } finally {
      lock.releaseLock();
    }

    return json({ ok: true, duplicate: false });
  } catch (err) {
    return json({ ok: false, error: String(err && err.message || err) });
  }
}

/** Lets you confirm in a browser that the deployment is live. */
function doGet() {
  return json({ ok: true, service: 'noplace-beta-signups' });
}

function getSheet(sheetId) {
  var book = SpreadsheetApp.openById(sheetId);
  var sheet = book.getSheetByName(SHEET_NAME);

  if (!sheet) {
    sheet = book.insertSheet(SHEET_NAME);
  }
  // Fresh or hand-emptied sheet: lay down headers once and freeze them.
  if (sheet.getLastRow() === 0) {
    sheet.appendRow(HEADERS);
    sheet.getRange(1, 1, 1, HEADERS.length).setFontWeight('bold');
    sheet.setFrozenRows(1);
  }
  return sheet;
}

function hasEmail(sheet, email) {
  var lastRow = sheet.getLastRow();
  if (lastRow < 2) return false;

  var column = sheet.getRange(2, 2, lastRow - 1, 1).getValues();
  for (var i = 0; i < column.length; i++) {
    if (String(column[i][0]).trim().toLowerCase() === email) return true;
  }
  return false;
}

function json(payload) {
  return ContentService
    .createTextOutput(JSON.stringify(payload))
    .setMimeType(ContentService.MimeType.JSON);
}
