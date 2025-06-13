# MirrorCast Design System

## Color Palette

### Primary Colors
- Primary: `#2563EB` (Modern Blue)
- Primary Dark: `#1D4ED8`
- Primary Light: `#60A5FA`

### Secondary Colors
- Secondary: `#7C3AED` (Modern Purple)
- Secondary Dark: `#6D28D9`
- Secondary Light: `#A78BFA`

### Neutral Colors
- Background: `#F8FAFC`
- Surface: `#FFFFFF`
- Text Primary: `#1E293B`
- Text Secondary: `#64748B`
- Border: `#E2E8F0`

### Status Colors
- Success: `#10B981`
- Error: `#EF4444`
- Warning: `#F59E0B`
- Info: `#3B82F6`

## Typography

### Font Family
- Primary: Inter
- Secondary: Roboto Mono (for code/technical elements)

### Font Sizes
- Display Large: 48px
- Display Medium: 40px
- Display Small: 36px
- Heading 1: 32px
- Heading 2: 24px
- Heading 3: 20px
- Body Large: 16px
- Body Medium: 14px
- Body Small: 12px
- Caption: 10px

### Font Weights
- Regular: 400
- Medium: 500
- SemiBold: 600
- Bold: 700

## Spacing System
- 4px (xs)
- 8px (sm)
- 16px (md)
- 24px (lg)
- 32px (xl)
- 48px (2xl)
- 64px (3xl)

## Border Radius
- Small: 4px
- Medium: 8px
- Large: 12px
- Full: 9999px

## Shadows
- Small: `0 1px 2px rgba(0, 0, 0, 0.05)`
- Medium: `0 4px 6px -1px rgba(0, 0, 0, 0.1)`
- Large: `0 10px 15px -3px rgba(0, 0, 0, 0.1)`

## Components

### Buttons
- Primary Button
  - Background: Primary
  - Text: White
  - Hover: Primary Dark
  - Border Radius: Medium
  - Padding: 12px 24px

- Secondary Button
  - Background: Transparent
  - Border: 1px solid Primary
  - Text: Primary
  - Hover: Primary Light (10% opacity)
  - Border Radius: Medium
  - Padding: 12px 24px

### Input Fields
- Background: Surface
- Border: 1px solid Border
- Border Radius: Medium
- Padding: 12px 16px
- Focus: 2px solid Primary

### Cards
- Background: Surface
- Border Radius: Large
- Shadow: Medium
- Padding: 24px

## Splash Screen Design

### Android
- Full-screen gradient background (Primary to Secondary)
- Centered logo with subtle animation
- Loading indicator at bottom
- Brand name in Display Large
- Tagline in Body Large

### Windows
- Matching gradient background
- Centered logo with matching animation
- Loading indicator
- Same typography and spacing
- Consistent branding elements

## Animation Guidelines
- Duration: 300ms for standard interactions
- Easing: Ease-in-out for smooth transitions
- Splash screen fade: 800ms
- Button hover: 150ms
- Page transitions: 400ms

## Iconography
- Line weight: 2px
- Size: 24px (standard)
- Color: Inherits from parent
- Style: Rounded corners, modern look

## Responsive Breakpoints
- Mobile: 320px - 480px
- Tablet: 481px - 768px
- Desktop: 769px - 1024px
- Large Desktop: 1025px+ 