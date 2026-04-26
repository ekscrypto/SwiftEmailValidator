//
//  TLDDomainValidator.swift
//  SwiftEmailValidator
//
//  Copyrights (C) 2026, Dave Poirier.  Distributed under MIT license
//
//  Default domain validator for EmailSyntaxValidator: confirms the rightmost
//  DNS label is a currently-delegated IANA TLD and that the domain is not
//  (and is not under) a special-use name reserved by RFC 6761 / RFC 6762 /
//  RFC 7686 / RFC 8375 / RFC 9476.
//

import Foundation

/// Default domain validator for ``EmailSyntaxValidator``.
///
/// Answers the question: *"Is this host plausibly a publicly-deliverable
/// email domain?"* — by checking the rightmost DNS label against the IANA
/// root zone and rejecting names reserved by IETF special-use registries.
///
/// ## Why not the Public Suffix List?
/// The PSL was designed for cookie scoping ("where does the administrative
/// boundary lie?"), not email deliverability. Its multi-level entries
/// (`co.uk`, `github.io`, `vercel.app`) are policy artifacts of specific
/// registries, with inconsistent coverage and weekly churn driven by
/// non-email concerns. For email syntax validation the relevant question
/// is "does the rightmost label name an IANA-delegated TLD that is not a
/// reserved special-use name?" — which the IANA root zone answers
/// directly, with much smaller data and slower update cadence.
///
/// ## Special-use names rejected
/// Per the IANA Special-Use Domain Names registry:
/// - `.test` (RFC 6761 §6.2)
/// - `.example`, `example.com`, `example.net`, `example.org` (RFC 6761 §6.5)
/// - `.invalid` (RFC 6761 §6.4)
/// - `.localhost` (RFC 6761 §6.3)
/// - `.local` (RFC 6762 — mDNS / link-local)
/// - `.onion` (RFC 7686 — Tor hidden services)
/// - `.alt` (RFC 9476 — non-DNS use)
/// - `home.arpa` (RFC 8375 — homenet)
///
/// Subdomains under any of these are also rejected.
///
/// ## IDN handling
/// Both ACE (`xn--…`) and Unicode U-label TLD forms are accepted. The
/// generator script (`Tools/generate_tlds.py`) emits both.
///
/// ## Overriding for non-public contexts
/// Intranet domains, dev environments (`mail.corp`), `localhost`, and
/// other non-public mail systems will fail this default. Pass a custom
/// `domainValidator` closure to ``EmailSyntaxValidator/correctlyFormatted(_:options:compatibility:allowAddressLiteral:domainValidator:localPartValidator:)``
/// or ``EmailSyntaxValidator/mailbox(from:options:compatibility:allowAddressLiteral:domainValidator:localPartValidator:)``
/// to opt out:
///
/// ```swift
/// EmailSyntaxValidator.correctlyFormatted(
///     "user@mail.corp",
///     domainValidator: { _ in true })
/// ```
public enum TLDDomainValidator {

    /// Special-use TLD labels that are not deliverable on the public Internet.
    /// Source: IETF Special-Use Domain Names registry
    /// (`https://www.iana.org/assignments/special-use-domain-names/`).
    public static let specialUseTLDs: Set<String> = [
        "test",      // RFC 6761 §6.2
        "example",   // RFC 6761 §6.5
        "invalid",   // RFC 6761 §6.4
        "localhost", // RFC 6761 §6.3
        "local",     // RFC 6762  (mDNS)
        "onion",     // RFC 7686  (Tor)
        "alt",       // RFC 9476
    ]

    /// Reserved second-level (and deeper) names that are not deliverable.
    public static let specialUseDomains: Set<String> = [
        "example.com",  // RFC 6761 §6.5
        "example.net",  // RFC 6761 §6.5
        "example.org",  // RFC 6761 §6.5
        "home.arpa",    // RFC 8375
    ]

    /// Validate `domain` as a publicly-deliverable email host.
    ///
    /// Returns `true` iff:
    /// 1. The rightmost label names a currently-delegated IANA TLD
    ///    (ACE or Unicode U-label form), AND
    /// 2. The domain is not (and is not a subdomain of) a special-use
    ///    name reserved by IETF.
    ///
    /// Case-insensitive on the ASCII range. A single trailing root-label
    /// dot is tolerated (`example.com.` ≡ `example.com`).
    ///
    /// Single-label inputs (`localhost`, `mailserver`) are rejected:
    /// RFC 5321 requires fully-qualified domain names in SMTP paths.
    public static func isPubliclyDeliverable(_ domain: String) -> Bool {
        var d = domain.lowercased()
        if d.hasSuffix(".") { d.removeLast() }
        guard !d.isEmpty else { return false }

        let labels = d.split(separator: ".", omittingEmptySubsequences: false)
        guard labels.count >= 2,
              labels.allSatisfy({ !$0.isEmpty })
        else { return false }

        let tld = String(labels.last!)

        if specialUseTLDs.contains(tld) { return false }
        if specialUseDomains.contains(d) { return false }
        for reserved in specialUseDomains where d.hasSuffix("." + reserved) {
            return false
        }

        return IANATLDs.all.contains(tld)
    }
}
