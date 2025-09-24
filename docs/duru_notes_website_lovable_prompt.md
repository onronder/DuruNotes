# Duru Notes Website - Lovable Development Prompt

> **Premium AI-Powered Note-Taking Application Website**
> 
> A striking, modern website that showcases Duru Notes as a cutting-edge productivity tool that goes beyond Notion and Obsidian

## 🎨 Brand Colors & Design System

### Core Logo Colors (EXACT VALUES - DO NOT CHANGE)
```css
/* Primary Brand Colors */
--primary-blue: #048ABF;      /* Logo gradient start - EXACT */
--accent-teal: #5FD0CB;        /* Logo gradient end - EXACT */
--deep-teal: #036693;          /* Darker variant for depth */
--light-aqua: #7DD8D3;         /* Lighter variant for accents */

/* Surface Colors */
--light-surface: #F8FAFC;      /* Light mode surface */
--dark-surface: #0F1E2E;        /* Dark mode surface */
--surface-white: #FFFFFF;      /* Pure white */
--surface-dark-alt: #122438;   /* Dark alternative */

/* Semantic Colors */
--success: #5FD0CB;            /* Use accent for success */
--warning: #FFA726;            /* Complementary orange */
--error: #EF5350;              /* Error red */
--info: #048ABF;               /* Use primary for info */

/* AI Feature Colors */
--ai-primary: #9333EA;         /* Purple for AI features */
--ai-secondary: #3B82F6;       /* Blue for AI secondary */
--ai-success: #10B981;         /* Green for AI success */

/* Text Colors */
--text-primary: #1A1C1E;       /* Main text */
--text-secondary: #44474E;     /* Secondary text */
--text-muted: #74777F;         /* Muted text */
--text-inverse: #E3E3E3;       /* Dark mode text */
```

### Gradients (Use These Exact Definitions)
```css
/* Primary Gradients */
.logo-gradient {
  background: linear-gradient(135deg, #048ABF 0%, #5FD0CB 100%);
}

.primary-gradient {
  background: linear-gradient(135deg, #048ABF 0%, #036693 100%);
}

.accent-gradient {
  background: linear-gradient(135deg, #5FD0CB 0%, #7DD8D3 100%);
}

/* Surface Gradients */
.surface-gradient-light {
  background: linear-gradient(180deg, #FCFDFE 0%, #F8FAFC 100%);
}

.surface-gradient-dark {
  background: linear-gradient(180deg, #122438 0%, #0F1E2E 100%);
}

/* AI Feature Gradient */
.ai-gradient {
  background: linear-gradient(135deg, #9333EA 0%, #3B82F6 100%);
}

/* Glassmorphism Effect */
.glass {
  background: rgba(255, 255, 255, 0.05);
  backdrop-filter: blur(10px);
  -webkit-backdrop-filter: blur(10px);
  border: 1px solid rgba(255, 255, 255, 0.1);
}
```

### Typography System
```css
/* Font: Inter - Load from Google Fonts */
@import url('https://fonts.googleapis.com/css2?family=Inter:wght@300;400;500;600;700&display=swap');

/* Type Scale */
--font-family: 'Inter', -apple-system, BlinkMacSystemFont, sans-serif;

/* Font Sizes */
--text-xs: 12px;
--text-sm: 14px;
--text-base: 16px;
--text-lg: 18px;
--text-xl: 20px;
--text-2xl: 24px;
--text-3xl: 32px;
--text-4xl: 40px;
--text-5xl: 48px;
--text-6xl: 64px;

/* Font Weights */
--font-light: 300;
--font-regular: 400;
--font-medium: 500;
--font-semibold: 600;
--font-bold: 700;

/* Line Heights */
--leading-tight: 1.25;
--leading-normal: 1.5;
--leading-relaxed: 1.75;
```

### Spacing System
```css
--space-xs: 4px;
--space-sm: 8px;
--space-md: 16px;
--space-lg: 24px;
--space-xl: 32px;
--space-2xl: 48px;
--space-3xl: 64px;
--space-4xl: 96px;
--space-5xl: 128px;
```

### Border Radius
```css
--radius-sm: 8px;
--radius-md: 12px;
--radius-lg: 16px;
--radius-xl: 20px;
--radius-2xl: 24px;
--radius-full: 9999px;
```

### Shadows
```css
--shadow-sm: 0 1px 2px 0 rgba(4, 138, 191, 0.05);
--shadow-md: 0 4px 6px -1px rgba(4, 138, 191, 0.1);
--shadow-lg: 0 10px 15px -3px rgba(4, 138, 191, 0.1);
--shadow-xl: 0 20px 25px -5px rgba(4, 138, 191, 0.15);
--shadow-2xl: 0 25px 50px -12px rgba(4, 138, 191, 0.25);
--shadow-glow: 0 0 20px rgba(95, 208, 203, 0.3);
```

## 📱 Site Architecture

### Navigation Structure
```
Header (Sticky, Glassmorphic)
├── Logo (Gradient)
├── Nav Links
│   ├── Features
│   ├── Product
│   ├── Compare
│   ├── Resources
│   └── Blog
└── CTA Buttons
    ├── Sign In (Ghost)
    └── Get Started (Gradient)

Main Content
├── Hero Section
├── Trust Bar
├── Features Overview
├── AI Intelligence
├── Product Demo
├── Comparison
├── Security & Privacy
├── Testimonials
├── FAQ
└── CTA Section

Footer
├── Product
├── Company
├── Resources
├── Legal
└── Newsletter
```

## 🚀 Page Sections & Components

### 1. Hero Section
```yaml
Design:
  - Full viewport height
  - Gradient mesh background animated
  - Glassmorphic floating elements
  - Particle network effect in background

Content:
  Headline: "Your Mind, Amplified by AI. Your Data, Protected by Design."
  Subheadline: "The note-taking app that thinks with you, not for you."
  
  CTA Buttons:
    Primary: "Start Free - No Credit Card"
      - Gradient background with glow effect
      - Hover: Increased glow, slight scale
    
    Secondary: "Watch 2-min Demo"
      - Glass background
      - Play icon animated

  Hero Visual:
    - 3 floating device mockups (iPhone 15 Pro, Pixel 8, MacBook)
    - Screens showing actual app interface
    - Subtle float animation
    - Connected by dotted lines showing sync

  Live Demo Area:
    - Typing animation showing AI completions
    - "Try it:" input field
    - Real-time AI suggestion preview

  Trust Badges (Bottom):
    - "256-bit Encryption"
    - "100% Offline Mode"
    - "Open Source"
    - "GDPR Compliant"
```

### 2. Trust Bar
```yaml
Design:
  - Glassmorphic bar
  - Subtle slide animation

Content:
  - "50,000+ professionals"
  - "4.9★ App Store"
  - "GitHub 5k+ stars"
  - "99.9% Uptime"
```

### 3. Features Overview - "Beyond Traditional Note-Taking"
```yaml
Design:
  - 3x2 grid on desktop, stack on mobile
  - Glassmorphic cards with gradient borders
  - Icon animations on hover
  - Parallax scroll effect

Feature Cards:

1. "Offline-First Intelligence"
   Icon: Brain with offline symbol
   Description: "AI that works without internet. Your thoughts, processed locally on your device."
   Highlight: "50MB AI Models"

2. "Modular Block Editor"
   Icon: Interconnected blocks
   Description: "More than text. Code, tables, todos, voice, images - all in perfect harmony."
   Highlight: "10+ Block Types"

3. "Privacy by Architecture"
   Icon: Shield with lock
   Description: "End-to-end encrypted. Your data never touches our servers unencrypted."
   Highlight: "Zero-Knowledge"

4. "Smart Templates"
   Icon: Magic document
   Description: "Dynamic templates with variables that adapt to your context."
   Highlight: "Infinite Customization"

5. "Native Share Extension"
   Icon: Share with sparkles
   Description: "Capture anything from any app in milliseconds."
   Highlight: "System-Level Integration"

6. "Semantic Knowledge Graph"
   Icon: 3D network
   Description: "Your notes don't just store. They understand, connect, and grow."
   Highlight: "Auto-Linking"
```

### 4. AI Intelligence Section
```yaml
Design:
  - Purple gradient accent background
  - Split layout: Features left, demo right
  - Interactive hover states
  - Animated transitions

Title: "Intelligence That Respects Your Privacy"
Subtitle: "On-device AI that never shares your thoughts"

AI Features:
  Real-Time Suggestions:
    - Live typing demo
    - Show suggestion appearing
    - Accept with Tab animation

  Semantic Search:
    - Search box with natural language
    - Instant results animation
    - Highlight relevance

  Smart Summarization:
    - Long text → Brief summary
    - Key points extraction
    - One-click summary

  Natural Commands:
    - "Remind me tomorrow at 3pm"
    - "Create a task list from this"
    - "Find related notes"

  Voice Intelligence:
    - Whisper integration
    - Real-time transcription
    - Speaker detection

  Knowledge Synthesis:
    - Connect disparate notes
    - Generate insights
    - Suggest relationships
```

### 5. Interactive Product Demo
```yaml
Design:
  - Centered iPhone mockup
  - Feature panels that slide in
  - Smooth scroll-triggered animations
  - Click or auto-advance

Demo Scenarios:

1. Quick Capture:
   - Show share sheet appearing
   - Content flowing into app
   - Instant organization

2. AI Writing:
   - Type "Meeting notes for"
   - AI completes the sentence
   - Accept and continue

3. Semantic Search:
   - Type "that idea about"
   - Instant fuzzy results
   - Jump to exact location

4. Template Magic:
   - Select template
   - Variables auto-fill
   - Instant document

5. Task Intelligence:
   - Natural language input
   - Auto-parse to tasks
   - Smart scheduling

6. Knowledge Graph:
   - 3D visualization
   - Connected notes
   - Discover patterns
```

### 6. Comparison Section - "See the Difference"
```yaml
Design:
  - Premium glassmorphic table
  - Gradient header
  - Duru column highlighted
  - Animated checkmarks
  - Hover for details

Table Structure:
Feature               | Duru Notes  | Notion     | Obsidian   | Apple Notes
---------------------|-------------|------------|------------|-------------
Offline-First        | ✓ Native    | ⚠ Limited  | ✓ Yes      | ✓ Yes
On-Device AI         | ✓ Built-in  | ✗ No       | ⚠ Plugins  | ✗ No
Block Editor         | ✓ Advanced  | ✓ Yes      | ✗ Markdown | ✗ Basic
E2E Encryption       | ✓ Default   | ✗ No       | ✓ Local    | ⚠ iCloud
Mobile Native        | ✓ Flutter   | ⚠ Web App  | ⚠ Limited  | ✓ Native
Share Extension      | ✓ System    | ⚠ Basic    | ✗ No       | ✓ Yes
Voice Notes          | ✓ Whisper   | ✗ No       | ⚠ Plugins  | ✓ Basic
Smart Templates      | ✓ Variables | ⚠ Basic    | ✓ Community| ✗ No
Knowledge Graph      | ✓ Semantic  | ⚠ Database | ✓ Links    | ✗ No
Open Source          | ✓ GitHub    | ✗ No       | ✓ Yes      | ✗ No
Cross-Platform       | ✓ All       | ✓ All      | ✓ Desktop  | ✗ Apple
API Access           | ✓ Full      | ✓ Limited  | ✗ No       | ✗ No

Unique Advantages (Cards below table):
- "True offline with AI - no competitors offer this"
- "Privacy-first from architecture up"
- "Native performance on all platforms"
```

### 7. Security & Privacy Section
```yaml
Design:
  - Dark gradient background
  - Lock pattern overlay
  - Glassmorphic feature cards
  - Security badges

Title: "Your Thoughts Are Yours Alone"
Subtitle: "Military-grade encryption meets Swiss privacy laws"

Security Features (Grid):
  - End-to-End Encryption (AES-256)
  - Local-First Architecture
  - Zero-Knowledge Backend
  - No Analytics Tracking
  - GDPR/CCPA Compliant
  - Regular Security Audits
  - Open Source Codebase
  - Self-Hosting Option

Trust Indicators:
  - ISO 27001 (coming)
  - SOC 2 Type II (planned)
  - Swiss Privacy Shield
  - GitHub Security Badge

Code Transparency:
  - Link to GitHub repo
  - Audit reports
  - Security whitepaper
```

### 8. Testimonials
```yaml
Design:
  - Carousel with glassmorphic cards
  - Profile photos with gradient border
  - Company logos
  - Auto-scroll with pause on hover

Testimonials:
  1. "Switched from Notion. The offline AI is a game-changer for my flights."
     - Sarah Chen, Product Manager at Google

  2. "Finally, a note app that respects privacy without sacrificing features."
     - Michael Torres, Privacy Advocate

  3. "The semantic search finds things I forgot I even wrote."
     - Dr. Emily Watson, Researcher at MIT

  4. "Templates with variables saved me 2 hours daily."
     - James Park, Startup Founder

  5. "It just works. Everywhere. Always. Even offline."
     - Lisa Anderson, Digital Nomad
```

### 9. FAQ Section
```yaml
Design:
  - Accordion style
  - Gradient accent on active
  - Smooth expand animations

Questions:
  1. "How does offline AI work?"
  2. "Is my data really private?"
  3. "Can I import from Notion/Obsidian?"
  4. "What happens if I lose internet?"
  5. "How do I sync across devices?"
  6. "Can I self-host?"
  7. "What AI models do you use?"
  8. "Is there a web version?"
```

### 10. CTA Section
```yaml
Design:
  - Gradient background
  - Large centered CTA
  - Benefit points

Content:
  Headline: "Start Your Journey to Amplified Thinking"
  Subheadline: "Join 50,000+ professionals using Duru Notes"

  CTA Button: "Get Started Free"
    - Large gradient button
    - Glow effect
    - Arrow animation

  Benefits:
    ✓ No credit card required
    ✓ 30-day premium trial
    ✓ Import your existing notes
    ✓ Cancel anytime
```

### 11. Footer
```yaml
Design:
  - Dark gradient mesh background
  - 4-column layout
  - Newsletter signup
  - Social links

Sections:
  Product:
    - Features
    - Roadmap
    - Changelog
    - API Docs
    - Downloads

  Company:
    - About Us
    - Blog
    - Careers
    - Press Kit
    - Contact

  Resources:
    - Documentation
    - Community Forum
    - Video Tutorials
    - Templates
    - Support

  Legal:
    - Privacy Policy
    - Terms of Service
    - Security
    - GDPR
    - Licenses

Newsletter:
  Title: "Monthly productivity tips"
  Input: Email with gradient border
  Button: "Subscribe" (gradient)
  Note: "No spam, unsubscribe anytime"

Social:
  - GitHub (with star count)
  - Twitter/X
  - Discord
  - LinkedIn
  - YouTube
```

## ✨ Micro-Interactions & Animations

### Scroll Animations
```yaml
Parallax Effects:
  - Hero background: 0.5x speed
  - Floating devices: 0.7x speed
  - Feature cards: Stagger fade-in
  - Section reveals: Fade up

Triggered Animations:
  - Number counters: Count up on view
  - Progress bars: Fill on scroll
  - Icons: Subtle bounce on appear
  - Text: Typewriter effect for key phrases
```

### Hover Effects
```yaml
Buttons:
  - Scale: 1.05
  - Glow: Increase opacity
  - Shadow: Elevate
  - Background: Brighten gradient

Cards:
  - Lift: translateY(-4px)
  - Shadow: Increase blur
  - Border: Gradient appear
  - Content: Reveal additional info

Links:
  - Color: Gradient text
  - Underline: Animated draw
  - Icon: Rotate/slide
```

### Interactive Elements
```yaml
Forms:
  - Focus: Gradient border
  - Valid: Green check appear
  - Invalid: Shake animation
  - Submit: Loading spinner

Toggles:
  - Smooth slide
  - Color transition
  - Icon morph

Tabs:
  - Slide indicator
  - Fade content
  - Height animation

Tooltips:
  - Fade in/out
  - Follow cursor
  - Smart positioning
```

### Loading States
```yaml
Skeleton Screens:
  - Shimmer effect
  - Gradient animation
  - Pulse opacity

Progress:
  - Gradient fill
  - Percentage counter
  - Success checkmark

Lazy Load:
  - Blur to focus
  - Fade in
  - Placeholder to content
```

## 📱 Responsive Design

### Breakpoints
```css
/* Mobile First Approach */
@media (min-width: 640px) { /* Tablet */ }
@media (min-width: 1024px) { /* Desktop */ }
@media (min-width: 1440px) { /* Wide */ }
```

### Mobile Optimizations
```yaml
Navigation:
  - Hamburger menu
  - Full-screen overlay
  - Gesture dismissal

Hero:
  - Single device mockup
  - Vertical layout
  - Reduced animations

Features:
  - Stack cards vertically
  - Swipeable carousel option
  - Tap to expand

Tables:
  - Horizontal scroll
  - Sticky first column
  - Collapse less important

Images:
  - Responsive sizing
  - Touch to zoom
  - Lazy loading
```

## 🎯 Key Marketing Messages

### Primary Messages
```
Headline: "Your Mind, Amplified by AI. Your Data, Protected by Design."

Taglines:
- "The note-taking app that thinks with you, not for you"
- "Offline-first intelligence. Privacy-first architecture."
- "Where thoughts become knowledge"
- "Built for deep work. Designed for privacy."

Value Props:
- "Only note app with true offline AI"
- "Military-grade encryption by default"
- "Open source and auditable"
- "Native apps, not web wrappers"
```

### Feature Benefits
```
Offline AI → "Work anywhere, even on a plane"
Block Editor → "Express ideas in any format"
Privacy → "Your thoughts stay yours"
Templates → "Save hours with smart automation"
Share Extension → "Capture ideas in one tap"
Knowledge Graph → "Discover hidden connections"
```

## 🚀 Performance Requirements

### Core Metrics
```yaml
Lighthouse Scores:
  - Performance: 95+
  - Accessibility: 100
  - Best Practices: 100
  - SEO: 100

Loading:
  - First Paint: <1s
  - Interactive: <2s
  - Fully Loaded: <3s

Optimization:
  - Image: WebP with fallbacks
  - Code: Minified & bundled
  - Fonts: Preloaded
  - Critical CSS: Inlined
  - JavaScript: Deferred
```

### Technical Implementation
```yaml
Framework: 
  - Next.js 14+ with App Router
  - OR Astro for static generation

Styling:
  - Tailwind CSS with custom design tokens
  - CSS Variables for theming
  - PostCSS for optimization

Animation:
  - Framer Motion for complex animations
  - CSS animations for simple effects
  - Intersection Observer for triggers

3D Graphics:
  - Three.js for knowledge graph
  - React Three Fiber wrapper

Components:
  - Radix UI for accessibility
  - Custom glassmorphic components
  - Headless UI patterns

Analytics:
  - Privacy-focused (Plausible/Umami)
  - No cookies by default
  - GDPR compliant

Performance:
  - Static generation where possible
  - Edge caching
  - Image optimization
  - Lazy loading
  - Code splitting
```

## 🎨 Visual Style Guidelines

### Design Principles
```
1. Glassmorphism First
   - Subtle transparency
   - Blur effects
   - Light borders
   - Depth through layers

2. Gradient Everything
   - Buttons: Logo gradient
   - Headers: Subtle gradients
   - Accents: AI purple gradient
   - Backgrounds: Mesh gradients

3. Modern Typography
   - Clear hierarchy
   - Generous spacing
   - Inter font family
   - High contrast

4. Smooth Motion
   - 60fps animations
   - Natural easing
   - Purposeful movement
   - No jarring transitions

5. Premium Feel
   - Lots of whitespace
   - High-quality images
   - Consistent spacing
   - Attention to detail

6. Accessibility
   - WCAG AAA contrast
   - Keyboard navigation
   - Screen reader friendly
   - Focus indicators
```

### Component Patterns
```
Cards:
  - Glass background
  - 16px radius
  - Subtle shadow
  - Gradient border on hover

Buttons:
  - 12px radius
  - Gradient or glass
  - Clear hover state
  - Loading states

Inputs:
  - 12px radius
  - Glass background
  - Gradient focus border
  - Clear labels

Sections:
  - Full width
  - Generous padding
  - Clear separation
  - Smooth transitions
```

## 📋 Content Requirements

### Copy Style
```
Tone:
  - Professional but friendly
  - Confident without arrogance
  - Technical but accessible
  - Privacy-focused

Voice:
  - Active voice preferred
  - Short sentences
  - Clear benefits
  - No jargon

Structure:
  - Scannable headlines
  - Bullet points for features
  - Short paragraphs
  - Clear CTAs
```

### SEO Optimization
```yaml
Meta Tags:
  - Title: "Duru Notes - AI-Powered Notes with Privacy"
  - Description: Under 160 chars
  - Keywords: Relevant, not stuffed
  - Open Graph: Complete

Content:
  - H1: One per page
  - H2-H3: Logical hierarchy
  - Alt text: All images
  - Schema markup: Product/Software

Performance:
  - Mobile-first indexing
  - Core Web Vitals optimized
  - XML sitemap
  - Robots.txt configured
```

## 🚢 Launch Checklist

### Pre-Launch
- [ ] Cross-browser testing
- [ ] Mobile responsive check
- [ ] Accessibility audit
- [ ] Performance optimization
- [ ] SEO audit
- [ ] Content review
- [ ] Legal pages complete
- [ ] Analytics setup
- [ ] Form testing
- [ ] 404 page designed

### Post-Launch
- [ ] Monitor analytics
- [ ] A/B testing setup
- [ ] User feedback collection
- [ ] Performance monitoring
- [ ] SEO tracking
- [ ] Conversion optimization
- [ ] Content updates
- [ ] Security monitoring

---

## 📝 Implementation Notes for Lovable

This website should feel **premium, modern, and trustworthy**. Every interaction should reinforce that Duru Notes is a **professional tool** that respects user privacy while delivering **cutting-edge AI features**.

The gradient branding (#048ABF → #5FD0CB) should be prominent but not overwhelming. Use it strategically for:
- Primary CTAs
- Hero elements
- Active states
- Success indicators

The glassmorphic design should create depth and sophistication without sacrificing readability or performance.

Remember: This isn't just a landing page—it's the digital embodiment of a **premium productivity tool** that stands apart from Notion, Obsidian, and every other note-taking app by being both **more intelligent** and **more private**.

Make it stunning. Make it memorable. Make it convert.
```

This comprehensive prompt includes everything needed to create a world-class website for Duru Notes, with your exact brand colors, unique features, and competitive positioning. The design emphasizes your premium gradient branding and modern glassmorphic aesthetics while clearly differentiating from competitors.
