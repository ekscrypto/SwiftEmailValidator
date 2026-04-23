import Foundation

// Test corpus harvested from each competitor library's own test suite.
// Each case is (input, competitor-expected-valid, source-file). Used by
// `--reverse` mode to surface places where our library disagrees with
// a competitor's own assertion, separate from where competitors disagree
// with us.
//
// Note on the "internationalTrueIfUnicodeMode" flag: evanrobertson's
// testValidInternationalAddresses uses `allowInternational: true`. Those
// cases are expected-valid only in our `.unicode` compatibility mode; in
// `.ascii` / `.asciiWithUnicodeExtension` modes the upstream library also
// rejects them (matches their `allowInternational: false` default).
//
// MimeEmailParser's suite validates `Name <mailbox>` envelopes. We extract
// the inner mailbox portion (the part they call `Address`) because that's
// what our library parses — we are not a full RFC 5322 address-list parser.
struct ReverseCase {
    enum Expectation {
        case valid
        case invalid
        case validOnlyInUnicodeMode
    }
    let email: String
    let expectation: Expectation
    let source: String
}

enum ReverseCorpus {
    // evanrobertson/EmailValidator — EmailValidatorTests.swift
    //   Static arrays: validAddresses, invalidAddresses, validInternationalAddresses.
    //   Ref: https://github.com/evanrobertson/EmailValidator/blob/master/EmailValidatorTests/EmailValidatorTests.swift
    static let evanrobertson: [ReverseCase] = [
        // validAddresses
        ReverseCase(email: #""Abc\@def"@example.com"#, expectation: .valid, source: "evanrobertson"),
        ReverseCase(email: #""Fred Bloggs"@example.com"#, expectation: .valid, source: "evanrobertson"),
        ReverseCase(email: #""Joe\\Blow"@example.com"#, expectation: .valid, source: "evanrobertson"),
        ReverseCase(email: #""Abc@def"@example.com"#, expectation: .valid, source: "evanrobertson"),
        ReverseCase(email: "customer/department=shipping@example.com", expectation: .valid, source: "evanrobertson"),
        ReverseCase(email: "$A12345@example.com", expectation: .valid, source: "evanrobertson"),
        ReverseCase(email: "!def!xyz%abc@example.com", expectation: .valid, source: "evanrobertson"),
        ReverseCase(email: "_somename@example.com", expectation: .valid, source: "evanrobertson"),
        ReverseCase(email: "valid.ipv4.addr@[123.1.72.10]", expectation: .valid, source: "evanrobertson"),
        ReverseCase(email: "valid.ipv6.addr@[IPv6:0::1]", expectation: .valid, source: "evanrobertson"),
        ReverseCase(email: "valid.ipv6.addr@[IPv6:2607:f0d0:1002:51::4]", expectation: .valid, source: "evanrobertson"),
        ReverseCase(email: "valid.ipv6.addr@[IPv6:fe80::230:48ff:fe33:bc33]", expectation: .valid, source: "evanrobertson"),
        ReverseCase(email: "valid.ipv6.addr@[IPv6:fe80:0000:0000:0000:0202:b3ff:fe1e:8329]", expectation: .valid, source: "evanrobertson"),
        ReverseCase(email: "valid.ipv6v4.addr@[IPv6:aaaa:aaaa:aaaa:aaaa:aaaa:aaaa:127.0.0.1]", expectation: .valid, source: "evanrobertson"),
        ReverseCase(email: "niceandsimple@example.com", expectation: .valid, source: "evanrobertson"),
        ReverseCase(email: "very.common@example.com", expectation: .valid, source: "evanrobertson"),
        ReverseCase(email: "a.little.lengthy.but.fine@dept.example.com", expectation: .valid, source: "evanrobertson"),
        ReverseCase(email: "disposable.style.email.with+symbol@example.com", expectation: .valid, source: "evanrobertson"),
        ReverseCase(email: "user@[IPv6:2001:db8:1ff::a0b:dbd0]", expectation: .valid, source: "evanrobertson"),
        ReverseCase(email: #""much.more unusual"@example.com"#, expectation: .valid, source: "evanrobertson"),
        ReverseCase(email: #""very.unusual.@.unusual.com"@example.com"#, expectation: .valid, source: "evanrobertson"),
        ReverseCase(email: #""very.(),:;<>[]\".VERY.\"very@\\ \"very\".unusual"@strange.example.com"#, expectation: .valid, source: "evanrobertson"),
        ReverseCase(email: "postbox@com", expectation: .valid, source: "evanrobertson"),
        ReverseCase(email: "admin@mailserver1", expectation: .valid, source: "evanrobertson"),
        ReverseCase(email: "!#$%&'*+-/=?^_`{}|~@example.org", expectation: .valid, source: "evanrobertson"),
        ReverseCase(email: #""()<>[]:,;@\\\"!#$%&'*+-/=?^_`{}| ~.a"@example.org"#, expectation: .valid, source: "evanrobertson"),
        ReverseCase(email: #"" "@example.org"#, expectation: .valid, source: "evanrobertson"),
        ReverseCase(email: #""\e\s\c\a\p\e\d"@sld.com"#, expectation: .valid, source: "evanrobertson"),
        ReverseCase(email: #""back\slash"@sld.com"#, expectation: .valid, source: "evanrobertson"),
        ReverseCase(email: #""escaped\"quote"@sld.com"#, expectation: .valid, source: "evanrobertson"),
        ReverseCase(email: #""quoted"@sld.com"#, expectation: .valid, source: "evanrobertson"),
        ReverseCase(email: #""quoted-at-sign@sld.org"@sld.com"#, expectation: .valid, source: "evanrobertson"),
        ReverseCase(email: "&'*+-./=?^_{}~@other-valid-characters-in-local.net", expectation: .valid, source: "evanrobertson"),
        ReverseCase(email: "01234567890@numbers-in-local.net", expectation: .valid, source: "evanrobertson"),
        ReverseCase(email: "a@single-character-in-local.org", expectation: .valid, source: "evanrobertson"),
        ReverseCase(email: "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ@letters-in-local.org", expectation: .valid, source: "evanrobertson"),
        ReverseCase(email: "backticksarelegit@test.com", expectation: .valid, source: "evanrobertson"),
        ReverseCase(email: "bracketed-IP-instead-of-domain@[127.0.0.1]", expectation: .valid, source: "evanrobertson"),
        ReverseCase(email: "country-code-tld@sld.rw", expectation: .valid, source: "evanrobertson"),
        ReverseCase(email: "country-code-tld@sld.uk", expectation: .valid, source: "evanrobertson"),
        ReverseCase(email: "letters-in-sld@123.com", expectation: .valid, source: "evanrobertson"),
        ReverseCase(email: "local@dash-in-sld.com", expectation: .valid, source: "evanrobertson"),
        ReverseCase(email: "local@sld.newTLD", expectation: .valid, source: "evanrobertson"),
        ReverseCase(email: "local@sub.domains.com", expectation: .valid, source: "evanrobertson"),
        ReverseCase(email: "mixed-1234-in-{+^}-local@sld.net", expectation: .valid, source: "evanrobertson"),
        ReverseCase(email: "one-character-third-level@a.example.com", expectation: .valid, source: "evanrobertson"),
        ReverseCase(email: "one-letter-sld@x.org", expectation: .valid, source: "evanrobertson"),
        ReverseCase(email: "punycode-numbers-in-tld@sld.xn--3e0b707e", expectation: .valid, source: "evanrobertson"),
        ReverseCase(email: "single-character-in-sld@x.org", expectation: .valid, source: "evanrobertson"),
        ReverseCase(email: "the-character-limit@for-each-part.of-the-domain.is-sixty-three-characters.this-is-exactly-sixty-three-characters-so-it-is-valid-blah-blah.com", expectation: .valid, source: "evanrobertson"),
        ReverseCase(email: "the-total-length@of-an-entire-address.cannot-be-longer-than-two-hundred-and-fifty-four-characters.and-this-address-is-254-characters-exactly.so-it-should-be-valid.and-im-going-to-add-some-more-words-here.to-increase-the-length-blah-blah-blah-blah-bla.org", expectation: .valid, source: "evanrobertson"),
        ReverseCase(email: "uncommon-tld@sld.mobi", expectation: .valid, source: "evanrobertson"),
        ReverseCase(email: "uncommon-tld@sld.museum", expectation: .valid, source: "evanrobertson"),
        ReverseCase(email: "uncommon-tld@sld.travel", expectation: .valid, source: "evanrobertson"),

        // invalidAddresses
        ReverseCase(email: #""asdasd@asdas.com"#, expectation: .invalid, source: "evanrobertson"),
        ReverseCase(email: "", expectation: .invalid, source: "evanrobertson"),
        ReverseCase(email: "invalid", expectation: .invalid, source: "evanrobertson"),
        ReverseCase(email: "invalid@", expectation: .invalid, source: "evanrobertson"),
        ReverseCase(email: "invalid @", expectation: .invalid, source: "evanrobertson"),
        ReverseCase(email: "invalid@[555.666.777.888]", expectation: .invalid, source: "evanrobertson"),
        ReverseCase(email: "invalid@[IPv6:123456]", expectation: .invalid, source: "evanrobertson"),
        ReverseCase(email: "invalid@[127.0.0.1.]", expectation: .invalid, source: "evanrobertson"),
        ReverseCase(email: "invalid@[127.0.0.1].", expectation: .invalid, source: "evanrobertson"),
        ReverseCase(email: "invalid@[127.0.0.1]x", expectation: .invalid, source: "evanrobertson"),
        ReverseCase(email: "Abc.example.com", expectation: .invalid, source: "evanrobertson"),
        ReverseCase(email: "A@b@c@example.com", expectation: .invalid, source: "evanrobertson"),
        ReverseCase(email: #"a"b(c)d,e:f;g<h>i[j\k]l@example.com"#, expectation: .invalid, source: "evanrobertson"),
        ReverseCase(email: #"just"not"right@example.com"#, expectation: .invalid, source: "evanrobertson"),
        ReverseCase(email: #"this is"not\allowed@example.com"#, expectation: .invalid, source: "evanrobertson"),
        ReverseCase(email: #"this\ still\"not\\allowed@example.com"#, expectation: .invalid, source: "evanrobertson"),
        ReverseCase(email: "! #$%`|@invalid-characters-in-local.org", expectation: .invalid, source: "evanrobertson"),
        ReverseCase(email: "(),:;`|@more-invalid-characters-in-local.org", expectation: .invalid, source: "evanrobertson"),
        ReverseCase(email: "* .local-starts-with-dot@sld.com", expectation: .invalid, source: "evanrobertson"),
        ReverseCase(email: "<>@[]`|@even-more-invalid-characters-in-local.org", expectation: .invalid, source: "evanrobertson"),
        ReverseCase(email: "@missing-local.org", expectation: .invalid, source: "evanrobertson"),
        ReverseCase(email: "IP-and-port@127.0.0.1:25", expectation: .invalid, source: "evanrobertson"),
        ReverseCase(email: "another-invalid-ip@127.0.0.256", expectation: .invalid, source: "evanrobertson"),
        ReverseCase(email: "invalid-characters-in-sld@! \"#$%(),/;<>_[]`|.org", expectation: .invalid, source: "evanrobertson"),
        ReverseCase(email: "invalid-ip@127.0.0.1.26", expectation: .invalid, source: "evanrobertson"),
        ReverseCase(email: "local-ends-with-dot.@sld.com", expectation: .invalid, source: "evanrobertson"),
        ReverseCase(email: "missing-at-sign.net", expectation: .invalid, source: "evanrobertson"),
        ReverseCase(email: "missing-sld@.com", expectation: .invalid, source: "evanrobertson"),
        ReverseCase(email: "missing-tld@sld.", expectation: .invalid, source: "evanrobertson"),
        ReverseCase(email: "sld-ends-with-dash@sld-.com", expectation: .invalid, source: "evanrobertson"),
        ReverseCase(email: "sld-starts-with-dashsh@-sld.com", expectation: .invalid, source: "evanrobertson"),
        ReverseCase(email: "the-character-limit@for-each-part.of-the-domain.is-sixty-three-characters.this-is-exactly-sixty-four-characters-so-it-is-invalid-blah-blah.com", expectation: .invalid, source: "evanrobertson"),
        ReverseCase(email: "the-local-part-is-invalid-if-it-is-longer-than-sixty-four-characters@sld.net", expectation: .invalid, source: "evanrobertson"),
        ReverseCase(email: "the-total-length@of-an-entire-address.cannot-be-longer-than-two-hundred-and-fifty-four-characters.and-this-address-is-255-characters-exactly.so-it-should-be-invalid.and-im-going-to-add-some-more-words-here.to-increase-the-lenght-blah-blah-blah-blah-bl.org", expectation: .invalid, source: "evanrobertson"),
        ReverseCase(email: "two..consecutive-dots@sld.com", expectation: .invalid, source: "evanrobertson"),
        ReverseCase(email: "unbracketed-IP@127.0.0.1", expectation: .invalid, source: "evanrobertson"),
        ReverseCase(email: "No longer available.", expectation: .invalid, source: "evanrobertson"),
        ReverseCase(email: "Moved.", expectation: .invalid, source: "evanrobertson"),

        // validInternationalAddresses
        ReverseCase(email: "伊昭傑@郵件.商務", expectation: .validOnlyInUnicodeMode, source: "evanrobertson"),
        ReverseCase(email: "राम@मोहन.ईन्फो", expectation: .validOnlyInUnicodeMode, source: "evanrobertson"),
        ReverseCase(email: "юзер@екзампл.ком", expectation: .validOnlyInUnicodeMode, source: "evanrobertson"),
        ReverseCase(email: "θσερ@εχαμπλε.ψομ", expectation: .validOnlyInUnicodeMode, source: "evanrobertson"),
    ]

    // bdolewski/SwiftEmailValidator — SwiftEmailValidatorTests.swift
    // Ref: https://github.com/bdolewski/SwiftEmailValidator/blob/master/Tests/SwiftEmailValidatorTests/SwiftEmailValidatorTests.swift
    static let bdolewski: [ReverseCase] = [
        ReverseCase(email: "john.appleseed@apple.com", expectation: .valid, source: "bdolewski"),
        ReverseCase(email: "john_appleseed@apple.com", expectation: .valid, source: "bdolewski"),
        ReverseCase(email: "JOHN_APPLESEED@apple.com", expectation: .valid, source: "bdolewski"),
        ReverseCase(email: "john_appleseed@APPLE.COM", expectation: .valid, source: "bdolewski"),
        ReverseCase(email: "", expectation: .invalid, source: "bdolewski"),
        // nil case skipped — Swift optional, not a string
        ReverseCase(email: "john@apple..com", expectation: .invalid, source: "bdolewski"),
        ReverseCase(email: "john@apple,com", expectation: .invalid, source: "bdolewski"),
        ReverseCase(email: "john@apple?com", expectation: .invalid, source: "bdolewski"),
        ReverseCase(email: "@", expectation: .invalid, source: "bdolewski"),
        ReverseCase(email: "john", expectation: .invalid, source: "bdolewski"),
        ReverseCase(email: "@apple.com", expectation: .invalid, source: "bdolewski"),
        ReverseCase(email: "@@apple.com", expectation: .invalid, source: "bdolewski"),
        ReverseCase(email: "some john@apple.com", expectation: .invalid, source: "bdolewski"),
        ReverseCase(email: "some,john@apple.com", expectation: .invalid, source: "bdolewski"),
        ReverseCase(email: "john;@apple.com", expectation: .invalid, source: "bdolewski"),
        ReverseCase(email: "john<>@apple.com", expectation: .invalid, source: "bdolewski"),
        ReverseCase(email: "john..@apple.com", expectation: .invalid, source: "bdolewski"),
        ReverseCase(email: "1234567890123456789012345678901234567890123456789012345678901234+x@@apple.com", expectation: .invalid, source: "bdolewski"),
    ]

    // jwelton/EmailValidator — EmailValidatorTests.swift
    // Ref: https://github.com/jwelton/EmailValidator/blob/master/Tests/EmailValidatorTests/EmailValidatorTests.swift
    static let jwelton: [ReverseCase] = [
        ReverseCase(email: "", expectation: .invalid, source: "jwelton"),
        ReverseCase(email: "testexample.com", expectation: .invalid, source: "jwelton"),
        ReverseCase(email: "test@example", expectation: .invalid, source: "jwelton"),
        ReverseCase(email: "testexample", expectation: .invalid, source: "jwelton"),
        ReverseCase(email: "test1@example.com test2@example.com", expectation: .invalid, source: "jwelton"),
        ReverseCase(email: "test@example.com", expectation: .valid, source: "jwelton"),
    ]

    // igorrendulic/MimeEmailParser — MimeEmailParserTests.swift
    // Their suite validates `Name <mailbox>` envelopes. We extract only the
    // pure mailbox portion (Address.Address field) — display-name parsing
    // is out of scope for SwiftEmailValidator.
    // Ref: https://github.com/igorrendulic/MimeEmailParser/blob/master/Tests/MimeEmailParserTests/MimeEmailParserTests.swift
    static let mimeParser: [ReverseCase] = [
        ReverseCase(email: "igor@mail.io", expectation: .valid, source: "igorrendulic"),
        ReverseCase(email: "jdoe@machine.example", expectation: .valid, source: "igorrendulic"),
        ReverseCase(email: "john.q.public@example.com", expectation: .valid, source: "igorrendulic"),
        ReverseCase(email: "groupaddr1@example.com", expectation: .valid, source: "igorrendulic"),
        ReverseCase(email: "mary@x.test", expectation: .valid, source: "igorrendulic"),
        ReverseCase(email: "jdoe@example.org", expectation: .valid, source: "igorrendulic"),
        ReverseCase(email: "one@y.test", expectation: .valid, source: "igorrendulic"),
        ReverseCase(email: "boss@nil.test", expectation: .valid, source: "igorrendulic"),
        ReverseCase(email: "sysservices@example.net", expectation: .valid, source: "igorrendulic"),
        ReverseCase(email: "c@a.test", expectation: .valid, source: "igorrendulic"),
        ReverseCase(email: "joe@where.test", expectation: .valid, source: "igorrendulic"),
        ReverseCase(email: "jdoe@one.test", expectation: .valid, source: "igorrendulic"),
        ReverseCase(email: "addr1@example.com", expectation: .valid, source: "igorrendulic"),
        ReverseCase(email: "addr2@example.com", expectation: .valid, source: "igorrendulic"),
        ReverseCase(email: "addr3@example.com", expectation: .valid, source: "igorrendulic"),
        ReverseCase(email: "joerg@example.com", expectation: .valid, source: "igorrendulic"),
        ReverseCase(email: "PIRARD@vm1.ulg.ac.be", expectation: .valid, source: "igorrendulic"),
        ReverseCase(email: "noreply@example.com", expectation: .valid, source: "igorrendulic"),
        ReverseCase(email: "gopher@example.com", expectation: .valid, source: "igorrendulic"),
        ReverseCase(email: "micro@example.com", expectation: .valid, source: "igorrendulic"),
        ReverseCase(email: "emptystring@example.com", expectation: .valid, source: "igorrendulic"),
        ReverseCase(email: "cfws@example.com", expectation: .valid, source: "igorrendulic"),
        ReverseCase(email: "john@example.com", expectation: .valid, source: "igorrendulic"),
        ReverseCase(email: "asjo@example.com", expectation: .valid, source: "igorrendulic"),
    ]

    static var all: [ReverseCase] {
        evanrobertson + bdolewski + jwelton + mimeParser
    }
}
