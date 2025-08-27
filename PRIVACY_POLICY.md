# Privacy Policy for Duru Notes

**Effective Date:** December 26, 2024  
**Last Updated:** December 26, 2024  
**Version:** 1.0.0

---

## Introduction

Duru Notes ("we," "our," or "us") is committed to protecting your privacy and ensuring the security of your personal information. This Privacy Policy explains how we collect, use, store, and protect your data when you use the Duru Notes mobile application (the "App").

**Key Privacy Principles:**
- **Privacy by Design**: Built with privacy as a core principle
- **End-to-End Encryption**: Your data is encrypted locally before leaving your device
- **Minimal Data Collection**: We collect only what's necessary for app functionality
- **No Third-Party Sharing**: We never sell or share your personal data
- **User Control**: You maintain full control over your data

---

## Information We Collect

### 1. Account Information
When you create an account, we collect:
- **Email address** (for authentication and account recovery)
- **Encrypted authentication tokens** (managed by Supabase Auth)
- **Account creation and last login timestamps**

### 2. Note Content
- **Note text and metadata** (encrypted end-to-end before storage)
- **Attachments** (images, files - encrypted before upload)
- **Voice recordings** (converted to text locally, audio optionally stored encrypted)
- **OCR scan results** (text extracted from images, processed locally)

### 3. Usage Analytics (Optional)
When analytics are enabled, we collect:
- **Feature usage statistics** (which features you use, anonymized)
- **Performance metrics** (app launch times, operation durations)
- **Error reports** (crash logs, anonymized error data)
- **Device information** (OS version, device model - no unique identifiers)

### 4. Technical Data
- **IP address** (temporarily for secure connections)
- **Device type and OS version** (for compatibility)
- **App version** (for support and updates)

---

## How We Use Your Information

### Primary Uses
1. **Provide Core Functionality**
   - Sync your notes across devices
   - Enable search and organization features
   - Process voice notes and OCR scanning
   - Deliver location-based and time-based reminders

2. **Improve App Performance**
   - Optimize app speed and reliability
   - Fix bugs and technical issues
   - Develop new features based on usage patterns

3. **Ensure Security**
   - Protect against unauthorized access
   - Detect and prevent security threats
   - Maintain data integrity

### We Do NOT Use Your Data For
- ❌ Advertising or marketing purposes
- ❌ Selling to third parties
- ❌ Training AI models on your content
- ❌ Profiling or behavioral analysis
- ❌ Social media integration or sharing

---

## Data Encryption & Security

### End-to-End Encryption
**Your content is encrypted before it leaves your device:**
- **Algorithm**: XChaCha20-Poly1305 with HKDF key derivation
- **Key Management**: Encryption keys stored securely in device Keychain/Keystore
- **Zero Knowledge**: We cannot read your encrypted notes, even if we wanted to

### Security Measures
1. **Local Encryption**: All sensitive data encrypted locally
2. **Secure Transmission**: TLS 1.3 for all network communications
3. **Secure Storage**: Encrypted database with row-level security
4. **Password Security**: PBKDF2 with unique salts for password hashing
5. **Access Control**: Multi-factor authentication support

### Data Processing Locations
- **Voice Recognition**: Processed locally on your device
- **OCR Text Extraction**: Processed locally on your device
- **Note Content**: Encrypted on device, stored in secure cloud infrastructure
- **Analytics**: Processed anonymously and aggregated

---

## Data Sharing and Third Parties

### Service Providers
We use the following trusted service providers:

1. **Supabase** (Backend Infrastructure)
   - **Purpose**: Secure cloud database and authentication
   - **Data Shared**: Encrypted note content, account information
   - **Location**: Global infrastructure with data residency controls
   - **Security**: SOC 2 Type II certified, GDPR compliant

2. **Sentry** (Error Monitoring)
   - **Purpose**: Crash reporting and performance monitoring
   - **Data Shared**: Anonymized error logs, performance metrics
   - **Privacy**: No personal data or note content shared
   - **Controls**: Sampling and filtering to minimize data collection

### No Data Selling
- We **never sell** your personal information
- We **never share** note content with advertisers
- We **never use** your data for marketing to other companies

---

## Your Rights and Controls

### Data Access Rights
- **View**: See all data we have about your account
- **Download**: Export your notes in standard formats (Markdown, PDF)
- **Correct**: Update or correct your account information
- **Delete**: Permanently delete your account and all associated data

### Privacy Controls
1. **Analytics Toggle**: Disable usage analytics in app settings
2. **Crash Reporting**: Opt out of error reporting
3. **Location Services**: Control location-based reminder permissions
4. **Voice Recognition**: Control microphone and speech recognition access

### Data Portability
- **Export Format**: Standard Markdown and PDF formats
- **Import Support**: Import from other note-taking apps
- **No Lock-in**: Your data remains accessible in open formats

---

## Data Retention

### Active Accounts
- **Note Content**: Retained as long as your account is active
- **Account Information**: Retained for account functionality
- **Analytics Data**: Aggregated data retained for up to 2 years

### Account Deletion
When you delete your account:
- **Immediate**: Note content and personal data deleted within 24 hours
- **30 Days**: Encrypted backups permanently purged
- **90 Days**: All traces removed from backup systems
- **Analytics**: Anonymized usage data may remain in aggregated form

### Inactive Accounts
- **2 Years**: Accounts inactive for 24+ months receive deletion notice
- **3 Years**: Inactive accounts automatically deleted after 36 months

---

## Children's Privacy

Duru Notes is not intended for children under 13 years of age. We do not knowingly collect personal information from children under 13. If we become aware that we have collected personal information from a child under 13, we will take steps to delete such information promptly.

---

## International Transfers

Your data may be transferred to and processed in countries other than your own. We ensure appropriate safeguards are in place:

- **Adequacy Decisions**: Transfers to countries with adequate privacy protection
- **Standard Contractual Clauses**: EU-approved data transfer mechanisms
- **Encryption**: All data encrypted in transit and at rest

---

## Cookies and Tracking

### What We Use
- **Essential Cookies**: Required for app authentication and functionality
- **Analytics Cookies**: Optional, only if analytics are enabled
- **No Tracking**: We do not use advertising or social media tracking

### Third-Party Cookies
- **Supabase**: Session management and authentication cookies
- **Sentry**: Error tracking cookies (anonymized)

---

## California Privacy Rights (CCPA)

California residents have specific rights regarding their personal information:

### Your Rights
1. **Right to Know**: What personal information we collect and how it's used
2. **Right to Delete**: Request deletion of your personal information
3. **Right to Opt-Out**: Opt out of sale of personal information (we don't sell data)
4. **Right to Non-Discrimination**: Equal service regardless of privacy choices

### How to Exercise Rights
- **Email**: privacy@durunotes.app
- **In-App**: Use privacy settings and account deletion options
- **Response Time**: We respond to requests within 45 days

---

## European Privacy Rights (GDPR)

Under GDPR, you have the following rights:

### Legal Basis for Processing
- **Contract Performance**: Providing the note-taking service you signed up for
- **Legitimate Interests**: Improving app functionality and security
- **Consent**: Optional analytics and marketing communications

### Your Rights
1. **Access**: Request a copy of your personal data
2. **Rectification**: Correct inaccurate personal data
3. **Erasure**: Request deletion of your personal data
4. **Portability**: Receive your data in a machine-readable format
5. **Object**: Object to processing based on legitimate interests
6. **Restrict**: Limit how we process your data

### Data Protection Officer
- **Contact**: dpo@durunotes.app
- **Response Time**: 30 days for most requests

---

## Changes to This Policy

### Notification of Changes
- **Email Notification**: Sent to your registered email for material changes
- **In-App Notice**: Prominent notice in the app for 30 days
- **Website Posting**: Updated policy posted at durunotes.app/privacy

### Your Options
- **Continue Using**: Continued use indicates acceptance of changes
- **Opt Out**: You may delete your account if you disagree with changes
- **Transition Period**: 30 days to review changes before they take effect

---

## Contact Information

### Privacy Questions
- **Email**: privacy@durunotes.app
- **Subject Line**: "Privacy Policy Question"
- **Response Time**: Within 7 business days

### Data Requests
- **Email**: data-requests@durunotes.app
- **Required Info**: Account email and specific request type
- **Response Time**: Within 30 days

### Security Issues
- **Email**: security@durunotes.app
- **Emergency**: critical-security@durunotes.app
- **Response Time**: Within 24 hours for security issues

### General Support
- **Email**: support@durunotes.app
- **Help Center**: durunotes.app/help
- **Response Time**: Within 2 business days

---

## Legal Information

### Governing Law
This Privacy Policy is governed by the laws of:
- **Primary Jurisdiction**: [Your Company's Legal Jurisdiction]
- **International Users**: Local data protection laws also apply

### Dispute Resolution
- **First Step**: Contact our privacy team directly
- **Mediation**: Binding arbitration for unresolved disputes
- **Courts**: Local courts for legal violations

### Data Controller
**Duru Notes, Inc.**  
[Your Company Address]  
[City, State, ZIP Code]  
Email: legal@durunotes.app

---

## Transparency Report

We are committed to transparency about how we handle your data:

### Annual Statistics (When Available)
- Number of data requests received and processed
- Types of law enforcement requests (if any)
- Security incidents and response measures
- Changes to data practices

### Commitment to Openness
- Regular security audits
- Open-source components where possible
- Clear communication about any changes

---

## Conclusion

Your privacy is fundamental to our service. We built Duru Notes with privacy-first principles and continue to enhance our protections based on best practices and user feedback.

**Remember:**
- Your note content is encrypted and unreadable to us
- You maintain full control over your data
- We never sell or inappropriately share your information
- You can delete your account and data at any time

Thank you for trusting Duru Notes with your digital thoughts and ideas.

---

*This privacy policy is written in plain language to ensure transparency and understanding. If you have any questions, please don't hesitate to contact us.*

**Document Version:** 1.0.0  
**Effective Date:** December 26, 2024  
**Next Review:** June 26, 2025
