---
name: ui-design-expert
description: Applies polished UI design principles based on "Refactoring UI." Use when building or reviewing user interfaces, selecting typography, creating color palettes, or defining layout systems. Trigger when asked to "design a component," "improve the look," or "refactor the UI."
---

# UI Design Expert

This skill provides specialized logic and constraints for building high-quality, professional user interfaces by focusing on visual hierarchy and systematic design.

## Instructions

When tasked with designing or critiquing an interface, apply the following logic:

1.  **Feature-First Design**: Start with actual functionality instead of the application shell or navigation.
2.  **Grayscale First**: Begin in grayscale to force spacing, contrast, and size to handle the visual hierarchy.
3.  **Establish Systems**: Define a restrictive set of options for font sizes, weights, colors, and spacing in advance to ensure consistency.
4.  **Emphasize by De-emphasizing**: If an element doesn't stand out, de-emphasize competing elements rather than adding more style to the primary one.
5.  **Smallest Useful Version**: Design only what you are ready to build to avoid unnecessary implementation complexity.

## Guidelines

### Visual Hierarchy
- **Size isn't everything**: Use **font weight** or **color** to communicate importance rather than relying solely on font size.
- **Labels as Last Resort**: Use data format and context to communicate meaning; combine labels and values (e.g., "12 left in stock" instead of "Stock: 12").
- **Balance Weight**: Use softer colors for heavy elements like solid icons to balance them with surrounding text.

### Layout and Spacing
- **Whitespace**: Start with too much white space and remove it until it feels right.
- **Spacing Systems**: Use a non-linear scale based on a **16px base** where values are at least 25% apart.
- **Fixed vs. Fluid**: Use fixed widths for elements that don't need to scale (like sidebars) and avoid the "960px" mindset—only use the space you need.

### Typography
- **Type Scale**: Hand-craft a scale using **px or rem** units; avoid `em` units for defining the scale as they cause scaling inconsistencies.
- **Readability**: Limit paragraphs to **45–75 characters** per line.
- **Alignment**: Align mixed font sizes by their **baseline**, not their vertical center.
- **Line Height**: Use taller line-heights for small text and shorter line-heights for large headings.

### Color and Depth
- **HSL over Hex**: Use **Hue, Saturation, and Lightness** for intuitive color adjustments.
- **Define Shades**: Create a palette of 8–10 shades per color up front.
- **Saturation**: Increase saturation as lightness moves away from 50% to prevent colors from looking washed out.
- **Elevation**: Emulate light coming from **above**; use larger, softer shadows to make elements feel closer to the user.

### Images
- **Consistency**: Add overlays or lower image contrast to ensure text remains readable over dynamic photos.
- **Intended Size**: Never scale up small icons; enclose them in a shape to fill space while keeping the icon at its intended size.
- **User Content**: Use `background-size: cover` and subtle **inner box shadows** to prevent light-colored user images from bleeding into the background.

## Examples

- **Task**: "Add a 'Delete' button to this card."
- **Response**: Apply a **tertiary** style (like a link) if it isn't the primary action of the page, and use a confirmation step where the button becomes a prominent **bold red** action.

- **Task**: "Design a pricing table."
- **Response**: Right-align numbers to make them easier to compare and use a **fixed-width** layout that doesn't necessarily fill the whole screen.
