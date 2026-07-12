# SPEC-SLUG-1: URL slug generation

The `slugify` function in `slug.py` generates URL slugs for the CMS. The
following rules are contractual; the SEO pipeline depends on each of them.

1. All ASCII letters are lowercased.
2. Spaces AND underscores each become a single hyphen `-`.
3. Runs of consecutive hyphens collapse to a single hyphen.
4. Leading and trailing hyphens are stripped.
5. Characters outside `[a-z0-9 _-]` (after lowercasing) are DROPPED, never
   transliterated. REQ-7 from the SEO team: `café` becomes `caf`, not `cafe`.
6. If the resulting slug is empty, raise `ValueError`; never return an
   empty string.
