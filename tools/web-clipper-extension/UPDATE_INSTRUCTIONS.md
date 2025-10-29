# Web Clipper Extension - Update Instructions

## ✅ Anon Key Updated

The extension has been updated with the new Supabase anon key.

**Updated File:** `background.js` (line 9)

**New Key:** `eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imp0YWVkZ3B4ZXNzaGRybmJndmpyIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTg5MjE0ODAsImV4cCI6MjA3NDQ5NzQ4MH0.3X5rNG8hgRrXMrfHMmO4T2iRyYtA4wj-Y62e_eO3WLs`

---

## 🔄 How to Reload the Extension

### Method 1: Reload in Chrome Extensions Page

1. Open Chrome and go to: `chrome://extensions/`
2. Enable "Developer mode" (toggle in top-right)
3. Find "Duru Notes Web Clipper"
4. Click the **reload icon** (circular arrow) on the extension card

### Method 2: Remove and Re-add

1. Go to: `chrome://extensions/`
2. Click "Remove" on the old extension
3. Click "Load unpacked"
4. Select: `/Users/onronder/duru-notes/tools/web-clipper-extension/`

---

## 🧪 Testing the Login

### Step 1: Open Extension Popup
1. Click the Duru Notes extension icon in Chrome toolbar
2. You should see the login screen

### Step 2: Try Login
- **Email:** test@duru.com
- **Password:** TestPassword123!

### Expected Behavior

#### If User Exists:
- ✅ Login succeeds
- ✅ Extension shows "Logged in as test@duru.com"
- ✅ You can now clip pages

#### If User Doesn't Exist:
- ❌ Error: "Invalid login credentials" or "User not found"
- **Solution:** Create the user account first

---

## 👤 Create Test User (If Needed)

### Option 1: Via App
1. Open your Duru Notes app
2. Go to Settings → Create Account
3. Email: test@duru.com
4. Password: TestPassword123!

### Option 2: Via Supabase Dashboard
1. Go to: https://supabase.com/dashboard/project/mizzxiijxtbwrqgflpnp/auth/users
2. Click "Add user"
3. Email: test@duru.com
4. Password: TestPassword123!
5. Auto-confirm email: ✅ (enable this)

### Option 3: Via API (Signup)
```bash
curl -X POST "https://mizzxiijxtbwrqgflpnp.supabase.co/auth/v1/signup" \
  -H "Content-Type: application/json" \
  -H "apikey: YOUR_ANON_KEY" \
  -d '{
    "email": "test@duru.com",
    "password": "TestPassword123!",
    "options": {
      "email_redirect_to": "https://durunotes.com"
    }
  }'
```

---

## 🐛 Troubleshooting

### "Login failed" Error

**Possible Causes:**
1. ❌ User doesn't exist → Create account first
2. ❌ Wrong password → Check password matches
3. ❌ Email not confirmed → Auto-confirm in dashboard or check email
4. ❌ Auth not enabled → Check Supabase Auth settings

**Debug Steps:**
1. Open Chrome DevTools (F12)
2. Go to Console tab
3. Try login again
4. Look for error messages

### Check Console Logs

The extension logs authentication details:
```javascript
// Look for these messages:
"Login error:" // Shows why login failed
"Fetched aliases:" // Shows user's aliases
"Using existing alias:" // Confirms alias found
```

### Network Tab Check

1. Open DevTools → Network tab
2. Try login
3. Find request to: `/auth/v1/token`
4. Check:
   - Status: Should be 200 (OK)
   - Response: Should contain `access_token`

---

## ✅ Verify Extension Works

### Test Login
1. ✅ Extension icon appears in toolbar
2. ✅ Click icon → Login form appears
3. ✅ Enter credentials → Success message
4. ✅ Extension remembers login (check after browser restart)

### Test Clipping
1. ✅ Go to any website (e.g., wikipedia.org)
2. ✅ Select some text
3. ✅ Right-click → "Clip Selection to Duru Notes"
4. ✅ Notification appears "Clip saved successfully"
5. ✅ Open Duru Notes app → Check inbox → Clip appears

### Test Full Page Clip
1. ✅ Go to a website
2. ✅ Right-click anywhere → "Clip Full Page to Duru Notes"
3. ✅ Check inbox → Full page content appears

---

## 📦 Files Updated

- ✅ `background.js` - Updated anon key
- ✅ `duru-notes-clipper-updated.zip` - Ready to distribute

---

## 🚀 Publishing to Chrome Web Store (Optional)

If you want to publish the extension:

1. Update `manifest.json` version number
2. Create a production build:
   ```bash
   cd tools/web-clipper-extension
   zip -r duru-notes-clipper-v1.1.0.zip . -x "*.DS_Store" "node_modules/*" ".git/*" "*.zip" "UPDATE_INSTRUCTIONS.md"
   ```
3. Upload to Chrome Web Store Developer Dashboard

---

## 📝 Summary

✅ **Anon key updated** - Extension now has valid Supabase credentials
⏳ **Reload extension** - Apply the changes
⏳ **Test login** - Verify with test@duru.com
⏳ **Create user** - If account doesn't exist
⏳ **Test clipping** - Confirm end-to-end workflow

**Next:** Reload the extension and try logging in!
