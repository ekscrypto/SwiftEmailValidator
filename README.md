# SwiftEmailValidator

A Swift implementation of an international email address syntax validator.  Since email addresses are local @ remote
the validator also includes IPAddressValidator and EmailHostValidator classes.

## IPAddressValidator

    if IPAddressValidator.isIPv6Address("::1") {
        print("::1 is a valid IPv6 address")
    }

    if IPAddressValidator.isIPv4Address("127.0.0.1") {
        print("127.0.0.1 is a valid IPv4 address")
    }
    
    if IPAddressValidator.isIPAddress("8.8.8.8") {
        print("8.8.8.8 is a valid IP address")
    }
    
    if IPAddressValidator.isIPAddress("fe80::1") {
        print("fe80::1 is a valid IP address")
    }


## EmailHostSyntaxValidator
Validates if the name is following expected syntax rules and whether it is part of a known public suffix. Does NOT validate if the domain actually exists or even allowed by the registrar.

    if EmailHostValidator.isValidEmailHostSyntax("yahoo.com") {
        print("yahoo.com is a valid email host syntax")
    }
