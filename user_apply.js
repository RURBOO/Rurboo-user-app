const fs = require('fs');
const path = require('path');

// Mapping: [English text, new UI key]
const dict = [
  ["Please Login to track ride", "uiLoginToTrack"],
  ["Ride not found or expired", "uiRideNotFound"],
  ["Please Login to view shared ride", "uiLoginToView"],
  ["Fetching current location...", "uiFetchingLocation"],
  ["No Internet Connection", "uiNoInternet"],
  ["Enter valid 10-digit number", "uiEnterValidPhone"],
  ["No messages yet. Say Hi! 👋", "uiNoMessages"],
  ["Language Selection", "uiLanguageSelection"],
  ["Welcome to RURBOO", "uiWelcomeRurboo"],
  ["Choose your preferred language to continue", "uiChooseLanguage"],
  ["Select Language", "uiSelectLanguage"],
  ["Profile Updated Successfully! 📸", "uiProfileUpdated"],
  ["Open Settings", "uiOpenSettings"],
  ["Settings", "uiSettings"],
  ["Preferences", "uiPreferences"],
  ["App Language", "uiAppLanguage"],
  ["Push Notifications", "uiPushNotifications"],
  ["Receive updates about your ride", "uiReceiveRideUpdates"],
  ["Promotional Emails", "uiPromotionalEmails"],
  ["About", "uiAbout"],
  ["App Version", "uiAppVersion"],
  ["Failed to load image", "uiFailedToLoadImage"],
  ["Emergency Guidelines", "uiEmergencyGuidelines"],
  ["Cancel Ride?", "uiCancelRideTitle"],
  ["Please select a reason for cancellation:", "uiSelectCancelReason"],
  ["Back", "uiBack"],
  ["Cancel Ride", "uiCancelRideBtn"],
  ["Connection Error", "uiConnectionError"],
  ["Please check your internet connection.", "uiCheckInternet"],
  ["Retry", "uiRetry"],
  ["Close", "uiClose"],
];

function walk(dir, out = []) {
  for (const f of fs.readdirSync(dir)) {
    const fp = path.join(dir, f);
    if (fs.statSync(fp).isDirectory()) walk(fp, out);
    else if (f.endsWith('.dart')) out.push(fp);
  }
  return out;
}

const escapedRegex = (s) => s.replace(/[-[\]{}()*+?.,\\^$|#\s]/g, '\\$&');

let totalModified = 0;
for (const file of walk('lib')) {
  let content = fs.readFileSync(file, 'utf8');
  const original = content;
  let langImported = content.includes('LanguageViewModel');

  for (const [en, key] of dict) {
    const esc = escapedRegex(en);
    // Replace const Text('...') and Text('...') with lang.getText('key')
    const patterns = [
      new RegExp(`const\\s+Text\\(\\s*["']${esc}["']\\s*\\)`, 'g'),
      new RegExp(`Text\\(\\s*["']${esc}["']\\s*\\)`, 'g'),
    ];
    for (const pat of patterns) {
      if (pat.test(content)) {
        content = content.replace(pat, `Text(lang.getText('${key}'))`);
      }
    }
  }

  if (content !== original) {
    // Check if lang is injected in this file
    const hasLang = content.includes('lang.getText') && (
      content.includes('final lang') || content.includes('Provider.of<LanguageViewModel>')
    );
    if (!hasLang) {
      // We cannot safely add lang here — mark as needing manual check
      console.warn(`⚠️  ${file} uses lang.getText but may not have lang defined - check manually`);
    }
    fs.writeFileSync(file, content);
    totalModified++;
  }
}
console.log(`Modified ${totalModified} files.`);
