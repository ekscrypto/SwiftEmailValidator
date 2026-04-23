# Security Policy

## Supported Versions

| Version | Supported          |
| ------- | ------------------ |
| 1.2.x   | :white_check_mark: |
| < 1.2   | :x:                |

The 1.2.x line consolidates the Unicode/RFC security hardening shipped in
April 2026 (Zs-category space spoofing, supplementary-plane noncharacters,
Variation Selectors, the Unicode Tags block, RFC 2047 Q-decode C1 rejection,
and others). Earlier versions accept inputs that should be rejected and are
no longer supported.

## Reporting a Vulnerability

If a security vulnerability is identified, please send an email to
`dave /@/ encoded.life` with the details. Please do not file a public issue
for vulnerabilities; private disclosure first lets a fix ship before details
are public.

Security fixes ship as a priority update on the supported branch. Please
test this library against your own corpus before relying on it for
business-critical mail handling.
