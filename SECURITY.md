# Security Policy

## Supported Versions

| Version | Supported          |
| ------- | ------------------ |
| 1.6.x   | :white_check_mark: |
| < 1.6   | :x:                |

Only the 1.6.x line receives security fixes. It bundles:

- **1.6.1** — Default_Ignorable hardening (RFC 5892 §2.6) in both local-part
  and domain-label paths, leading-combining-mark rejection, empty quoted
  local-part rejection, IPv6 regex case + leading-zero fixes, RFC 2047 §2
  75-octet encoder cap, base64 residue-1 self-check, and UTS #39 §5.1
  Augmented_Script_Set + §5.2 Recommended-script gating.
- **1.6.0** — IANA TLD validator with RFC 6761 / 6762 / 7686 / 8375 / 9476
  special-use blocklist (and RFC 3172 `.arpa` rejection), replacing the
  prior public-suffix dependency.
- **1.5.0** — opt-in UTS #39 companion target (Identifier_Status,
  mixed-script restriction levels, §4 confusable skeletons).
- **1.4.x** — IP-literal validator DoS hardening (length-capped wrappers)
  and RFC 4291 §2.2 format-2 IPv6 acceptance.
- **1.2.x** — Unicode/RFC hardening shipped April 2026: Zs-category space
  spoofing, supplementary-plane noncharacters, Variation Selectors, the
  Unicode Tags block, and RFC 2047 Q-decode C1 rejection.

Earlier releases accept inputs that should be rejected and are no longer
supported.

## Reporting a Vulnerability

If a security vulnerability is identified, please send an email to
`dave /@/ encoded.life` with the details. Please do not file a public issue
for vulnerabilities; private disclosure first lets a fix ship before details
are public.

Security fixes ship as a priority update on the supported branch. Please
test this library against your own corpus before relying on it for
business-critical mail handling.
