## ADDED Requirements

### Requirement: Home Page Nighttime Visual Aesthetic
The home page shell SHALL implement the "nighttime" visual styling, featuring a dark background, primary cyan/neon accent colors, and glassmorphic panels for the sidebar and content cards.

#### Scenario: Shell Rendering
- **WHEN** the application starts and the home page is displayed
- **THEN** the sidebar and top navigation areas should have a translucent glass effect over the animated background

### Requirement: Animated Particle Background
The application shell SHALL display an animated background containing drifting particles, rendered behind the main content panels, to provide dynamic visual depth.

#### Scenario: Background Rendering
- **WHEN** the user is viewing the home page
- **THEN** particles float slowly across the background layer

### Requirement: Hero Content Carousel
The home page SHALL include an auto-sliding hero carousel displaying featured content banners at the top of the content area.

#### Scenario: Auto-Slide Rotation
- **WHEN** the user views the home page without interacting with the carousel
- **THEN** the carousel automatically advances to the next item every few seconds

### Requirement: Hot Updates Carousel
The home page SHALL include a horizontal scrolling section for "Hot Updates" (热门更新) displaying landscape cards with dynamic status and ratings.

#### Scenario: Hot Updates Horizontal Scroll
- **WHEN** the user views the Hot Updates section
- **THEN** they can scroll horizontally or use navigation arrows to view additional items
