# DuruNotes Web Clipper - Publishing Guide

## Pre-Publication Checklist

### 1. Code Review
- [ ] All console.log statements removed or wrapped in DEBUG flag
- [ ] No hardcoded secrets or test values
- [ ] Error handling covers all edge cases
- [ ] Retry logic tested
- [ ] Timeout behavior verified

### 2. Testing
- [ ] Extension loads without errors
- [ ] Configuration saves and persists
- [ ] Right-click menu appears
- [ ] Clipping works with selection
- [ ] Clipping works without selection (full page)
- [ ] Success notifications show domain
- [ ] Error notifications are helpful
- [ ] Network retry works
- [ ] Invalid configuration shows friendly error

### 3. Package Preparation
- [ ] Run `./scripts/pack.sh` to create web-clipper.zip
- [ ] Verify zip is under 10MB
- [ ] Test loading the .zip file as an extension
- [ ] Ensure all features work from packaged version

### 4. Store Assets
- [ ] Create 5 screenshots (1280×800)
- [ ] Create promotional images:
  - [ ] Small tile (440×280)
  - [ ] Large tile (920×680)
  - [ ] Marquee tile (1400×560)
- [ ] Prepare store listing text
- [ ] Review privacy policy section

## Publishing Steps

### Step 1: Chrome Web Store Developer Account
1. Go to https://chrome.google.com/webstore/devconsole
2. Sign in with Google account
3. Pay one-time $5 developer fee (if not already registered)
4. Complete developer profile

### Step 2: Create New Item
1. Click "New Item" button
2. Upload `dist/web-clipper.zip`
3. Wait for initial validation

### Step 3: Complete Store Listing

#### Basic Information
- **Name**: DuruNotes Web Clipper
- **Short Description**: Copy from STORE-LISTING.md
- **Category**: Productivity
- **Language**: English

#### Detailed Description
- Copy full description from STORE-LISTING.md
- Format with markdown where supported

#### Graphics
Upload from `store/` directory:
- Icon: Use `icons/icon-128.png`
- Screenshots: Upload all 5 (or create first)
- Promotional images (optional for unlisted)

#### Additional Fields
- **Websites**:
  - Homepage: Your DuruNotes URL
  - Support URL: GitHub wiki or docs page
- **Regions**: All regions
- **Pricing**: Free

### Step 4: Privacy & Permissions

#### Privacy Practices
Answer survey questions:
- Personal communications: NO
- Personal information: NO
- Website content: YES (user-initiated only)
- Authentication: YES (user provides token)
- Analytics: NO
- Third parties: NO

#### Permission Justifications
Copy from STORE-LISTING.md permission section

#### Privacy Policy
- Single purpose: YES (web clipping)
- Policy URL: Link to your privacy policy
- Or paste inline from STORE-LISTING.md

### Step 5: Distribution Settings

For initial release:
- **Visibility**: Unlisted
- **Distribution**: Public (but unlisted)
- **Test accounts**: Add test email addresses

### Step 6: Submit for Review

1. Review all information
2. Click "Submit for Review"
3. Typical review time: 1-3 business days
4. Check email for approval/rejection

## Post-Publication

### Once Approved (Unlisted)

1. **Get the installation link**:
   - Format: `https://chrome.google.com/webstore/detail/[EXTENSION_ID]`
   - Share with beta users only

2. **Monitor feedback**:
   - Check developer dashboard for crashes
   - Gather user feedback
   - Track installation count

3. **Test installation flow**:
   - Install from store link
   - Verify auto-updates work
   - Test on different Chrome versions

### Moving to Public (When Ready)

1. Incorporate beta feedback
2. Update version number
3. Upload new package
4. Change visibility to "Public"
5. Submit for review again

### Version Updates

1. Update `manifest.json` version
2. Document changes in CHANGELOG
3. Run `./scripts/pack.sh`
4. Upload new package
5. Update store listing if needed
6. Submit for review

## Common Rejection Reasons

### Avoid These Issues
- **Single Purpose Violation**: Keep focused on clipping only
- **Permission Overreach**: Only request needed permissions
- **Privacy Policy Missing**: Must be clear and complete
- **Misleading Description**: Be accurate about functionality
- **Keyword Stuffing**: Use natural language
- **Low Quality Screenshots**: Use high-res, professional images
- **Broken Functionality**: Test thoroughly before submission

### If Rejected
1. Read rejection reason carefully
2. Fix the specific issue
3. Update version number
4. Resubmit with explanation of changes
5. Response time is usually faster for resubmissions

## Alternative Distribution

### For Internal/Enterprise Use
Instead of Chrome Web Store:
1. Host the .zip file internally
2. Use Chrome policy to force-install
3. Or distribute .crx file with instructions

### GitHub Releases
1. Create GitHub release
2. Attach web-clipper.zip
3. Provide installation instructions
4. Keep auto-update URL updated

## Support Documentation

### Create These Pages
1. **Installation Guide**: Step-by-step with screenshots
2. **Configuration Guide**: How to find credentials
3. **Troubleshooting**: Common issues and solutions
4. **FAQ**: Anticipated questions
5. **Privacy Policy**: Standalone page

### User Communication
- Set up support email
- Create FAQ in GitHub wiki
- Consider Discord/Slack community
- Monitor Chrome Web Store reviews

## Maintenance Schedule

### Weekly
- Check developer dashboard for issues
- Review any user feedback
- Monitor error reports

### Monthly
- Test all functionality
- Review and update documentation
- Check for Chrome API changes

### Quarterly
- Security audit
- Dependency updates (if any added)
- Feature roadmap review

## Success Metrics

Track these for future decisions:
- Installation count
- Active users
- Uninstall rate
- User reviews/ratings
- Support ticket volume
- Feature requests

---

**Remember**: Start with Unlisted distribution to validate with a smaller audience before going fully public. This reduces risk and allows for iteration based on real user feedback.
