# Design System Strategy: The Tactile Concierge

## 1. Overview & Creative North Star
The "Tactile Concierge" is a design philosophy that marries high-end professional reliability with an approachable, human touch. This system moves away from the rigid, boxy constraints of traditional enterprise software, favoring a "Digital Editorial" approach. 

**Creative North Star: The Seamless Host.**
The interface should feel like a premium concierge service—anticipatory, soft to the touch, and effortlessly organized. We achieve this through **intentional asymmetry**, where large `display-lg` typography interacts with overlapping `ROUND_FULL` containers, breaking the "standard grid" to create a sense of bespoke craftsmanship. By utilizing a high-contrast typography scale and deep, tonal layering, we move beyond "utility" into an "experience."

---

## 2. Colors: Depth and Soul
Our palette is anchored in professional blues with vibrant, organic greens that symbolize growth and validation (derived from the checkmark in the logo).

*   **Primary Tier:** `primary` (#005bbf) and `primary_container` (#1a73e8). These are for high-action moments and brand anchoring.
*   **The Green Accent:** `tertiary` (#3e6900) and `tertiary_container` (#51840a). Use these sparingly for "Success" states or as a vibrant highlight to the professional blue.
*   **The "No-Line" Rule:** To maintain a premium editorial feel, **1px solid borders are prohibited for sectioning.** Boundaries must be defined by background shifts. For example, a `surface_container_low` section should sit directly on a `surface` background.
*   **Surface Hierarchy & Nesting:** Treat the UI as physical layers. An inner card (`surface_container_lowest`) should be nested within a section (`surface_container_low`) to create natural depth without visual clutter.
*   **The "Glass & Gradient" Rule:** Floating navigation bars or modal headers should use **Glassmorphism**. Apply `surface` at 80% opacity with a `backdrop-filter: blur(20px)` to create a frosted-glass effect that lets background colors bleed through.
*   **Signature Textures:** For Hero sections or primary CTAs, use a subtle linear gradient transitioning from `primary` to `primary_container` at a 135-degree angle. This adds "soul" and prevents the UI from feeling flat or "off-the-shelf."

---

## 3. Typography: The Editorial Voice
We use **Manrope** exclusively. Its geometric yet humanist qualities provide the perfect balance for a professional concierge.

*   **The Power of Display:** Use `display-lg` (3.5rem) with tight letter-spacing (-0.02em) for hero moments. Don't be afraid to let display text overlap with background elements or image containers.
*   **Hierarchical Authority:** 
    *   **Headlines:** Use `headline-lg` (2rem) for major section titles to command attention.
    *   **Titles:** `title-lg` (1.375rem) serves as the primary "anchor" for cards and list groups.
    *   **Body:** `body-lg` (1rem) is the workhorse for readability.
*   **The Label Intent:** `label-md` and `label-sm` should be used for metadata and micro-copy, often paired with `on_surface_variant` (#414754) to create a clear visual distinction from primary content.

---

## 4. Elevation & Depth: Tonal Layering
Traditional drop shadows are a fallback, not a first resort. We prioritize **Tonal Layering** to convey hierarchy.

*   **The Layering Principle:** Stack `surface_container` tiers. A `surface_container_highest` element naturally feels "closer" to the user than a `surface_container_low` background.
*   **Ambient Shadows:** For elements that truly "float" (like FABs or active modals), use extra-diffused shadows.
    *   *Shadow Recipe:* `box-shadow: 0 20px 40px rgba(25, 28, 35, 0.06);` (using a 6% opacity of the `on_surface` color). This mimics natural ambient light.
*   **The "Ghost Border" Fallback:** If a border is required for accessibility, use the `outline_variant` token at **15% opacity**. Never use 100% opaque borders.
*   **Logo Integration:** The logo (pin + checkmark) should be used as a watermark in large header containers or as a simplified icon within `primary_container` surfaces.

---

## 5. Components: Soft & Approachable
All interactive components must adhere to the `ROUND_FULL` (9999px) or `xl` (3rem) rounding scale to reinforce the "Tactile" theme.

*   **Buttons:** 
    *   **Primary:** `ROUND_FULL`, `primary` background, `on_primary` text. Use the signature gradient on hover.
    *   **Secondary:** `ROUND_FULL`, `secondary_container` background.
*   **Input Fields:** Use `surface_container_highest` as the fill. No bottom borders—only a subtle `outline_variant` (at 20% opacity) that becomes `primary` on focus.
*   **Cards & Lists:** **Strictly forbid divider lines.** Use `1.5rem` (`spacing-6`) of vertical white space or a shift from `surface` to `surface_container_low` to separate content blocks.
*   **Chips:** Use `ROUND_FULL`. For "Validated" states, use the `tertiary_container` (green) with `on_tertiary_fixed` text to mirror the logo's checkmark.
*   **Custom Concierge Component - "The Floating Action Sheet":** Instead of standard bottom sheets, use a "glass" sheet that floats 1rem from the screen edges, using `xl` rounding and an ambient shadow.

---

## 6. Do's and Don'ts

### Do:
*   **Do** use generous whitespace (`spacing-12` and `spacing-16`) between major editorial sections.
*   **Do** let the logo's blue and green colors drive the visual hierarchy of the page.
*   **Do** use `ROUND_FULL` for all interactive elements to make them feel "touchable."
*   **Do** prioritize typographic scale over color to show importance.

### Don't:
*   **Don't** use 1px solid dividers or borders to separate content.
*   **Don't** use harsh, high-opacity black shadows.
*   **Don't** cram content. If it feels crowded, increase the `spacing` token by two levels.
*   **Don't** use "default" system fonts. Manrope is the brand's signature; it must be used consistently across all platforms.