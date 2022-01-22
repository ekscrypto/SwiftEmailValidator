# SwiftEmailValidator

A Swift implementation of an international email address syntax validator.  Since email addresses are local @ remote
the validator also includes IPAddressSyntaxValidator and EmailHostSyntaxValidator classes.  This framework does not
require any Internet connection to work.

## IPAddressSyntaxValidator

    if IPAddressSyntaxValidator.matchIPv6("::1") {
        print("::1 is a valid IPv6 address")
    }

    if IPAddressSyntaxValidator.matchIPv4("127.0.0.1") {
        print("127.0.0.1 is a valid IPv4 address")
    }
    
    if IPAddressSyntaxValidator.match("8.8.8.8") {
        print("8.8.8.8 is a valid IP address")
    }
    
    if IPAddressSyntaxValidator.match("fe80::1") {
        print("fe80::1 is a valid IP address")
    }


## EmailHostSyntaxValidator
Validates if the name is following expected syntax rules and whether it is part of a known public suffix. Does NOT validate if the domain actually exists or even allowed by the registrar.

    if EmailHostSyntaxValidator.match("yahoo.com") {
        print("yahoo.com has valid email host syntax")
    }
