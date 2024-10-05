---
title: "Why is Rust OpenSSL suddenly making invalid SANS?"
date: 2024-10-05T08:00:00-04:00
type: article
---

If you have a Rust app that uses the [openssl crate] to generate
certificates, and one day out of the blue those certs. are being rejected for
malformed subject alternative names (SANs) with confusing errors like:

> `certificate is valid for example.com, www.example.com, not example.com`

or:

> `Cannot issue for "example.com, dns:www.example.com": Domain name contains an invalid character`

Then the root cause is almost certainly that your app was relying on an API quirk
in the `openssl` crate that went away with a bugfix that landed in 2023.

# The short story

While I find the longer story interesting, if you just want to fix your app
immediately you should:

* Check if you, or a transitive dependency, updated to `openssl >= 0.10.48`.
* Replace any invocations of [SubjectAlternativeName] builder fns that were
  provided comma separated values to use one builder invocation per value
  instead:

```rust
// Bad:
let example = SubjectAlternativeName::new()
    .dns("example.com, www.example.com")
    .ip("127.0.0.1, 8.8.8.8")
    .build(...)

// Good:
let example = SubjectAlternativeName::new()
    .dns("example.com")
    .dns("www.example.com")
    .ip("127.0.0.1")
    .ip("8.8.8.8")
    .build(...)
```

If you _haven't_ updated `openssl` past that point then I'm afraid this story
won't help you fix your bug (and you are missing security fixes for
vulnerabilities!).

If you're interested in gory OpenSSL themed horror, read on.

# The long story

I first bumped into this confusing situation after [rustls#1292] was created by
a user confused by an error emitted by Rustls when talking to a server using
a certificate generated with the Rust `openssl` crate. I bumped into it _again_
this week after helping a friend debug a problem with a Rust ACME client,
prompting the idea to write this stuff down :)

## Beware OpenSSL text

Often the first thing folks reach for in these cases is the `openssl` command
line tool to dump a textual representation of a problematic PEM encoded X.509
certificate to check its subject alternative names:

```bash
openssl x509 -in $PATH_TO_PEM_CERT -noout -text | \
  grep --after-context=2 "Subject Alternative Name:"
```

Which in the case of [the cert provided] in issue 1292, printed:
```
    X509v3 Subject Alternative Name:
        DNS:localhost, IP:127.0.0.1, DNS:localhost
```

The duplicate `"localhost"` `dNSName` type SAN stands out, but I'll spoil the
surprise a bit and say it's a red herring. The real issue is that OpenSSL's
text output is a pretty crummy tool for this sort of debugging. It's deceived us
by not providing any delimiters around each SAN's `GeneralName` values! What
appears to be _three_ SANs is actually just **two**.

1. One `dNSName` type general name with the value `"localhost, IP:127.0.0.1"`
2. One `dnsName` type general name with the value `"localhost"`

You can verify this with a more capable low-level tool like [der-ascii]:

```bash
der2ascii -pem -i $PATH_TO_PEM_CERT
```

This will print a lot decoded ASN.1 data[^1], but most importantly, the `subjectAltName`
extension where the invalid SAN problem is easily visible:
```
<snipped>
SEQUENCE {
  # subjectAltName
  OBJECT_IDENTIFIER { 2.5.29.17 }
  OCTET_STRING {
    SEQUENCE {
      [2 PRIMITIVE] { "localhost, IP:127.0.0.1" }
      [2 PRIMITIVE] { "localhost" }
    }
  }
}
<snipped>
```

A valid certificate for both `localhost` and `127.0.0.1` should instead have
a SAN extension like:
```
<snipped>
SEQUENCE {
  # subjectAltName
  OBJECT_IDENTIFIER { 2.5.29.17 }
  OCTET_STRING {
    SEQUENCE {
      [2 PRIMITIVE] { "localhost" }
      [7 PRIMITIVE] { "127.0.0.1" }
    }
  }
}
<snipped>
```

OpenSSL also has a way to dump a more accurate ASN.1 representation of the
certificate DER (`openssl asn1parse`) but it's lackluster compared to
`der-ascii` and only shows the whole SAN extension as a hex encoded octet
string. It's also perhaps not a great idea to be piping data expected to be
malformed in some way through a tool written in C with a history of memory
safety vulns in its parsing code... In contrast, `der-ascii` is written in Go.

In either case I think we can all agree this certificate is busted: it has
a clearly invalid `dNSName` SAN and no `iPAddress` SAN at all.

## What changed?

Knowing the problem with the certificate doesn't explain why certificate
generation code that _used to_ produce valid certificates is now producing
certificates with freak-show conjoined SANs.

In the case of issue 1292 the generation code in question used the [openssl
crate] and was building the [SubjectAlternativeName] as follows:

```rust
    let subject_alt_name = SubjectAlternativeName::new()
        .dns("localhost, IP:127.0.0.1")
        .build(&cert_builder.x509v3_context(Some(&ca_cert_x590), None))?;
```

This pointed to the root cause being a change in the way the [dns()][dns] fn
handled values. It's not a large leap to theorize it must have previously
allowed specifying multiple comma-separated values and now is treating it as one
domain name value.

The old behaviour does seem confusing: it was using `dns()` but also providing an
`IP:` prefixed SAN value. Shouldn't it have used the `ip()` fn for that? 
Changing `dns()` to disallow that kind of mixed usage seems like great sense.
With this insight in hand it didn't take long to backtrack to
[rust-openssl#1854], "Fix a series of security issues". 

but wait... Security issues? I thought we were just chasing down a benign API
change........

## Horror Shows

The change in question was to fix [RUSTSEC-2023-0023], a bug reported by [David
Benjamin] that says:

> SubjectAlternativeName and ExtendedKeyUsage arguments were parsed using the
> OpenSSL function X509V3_EXT_nconf. This function parses all input using an
> OpenSSL mini-language which can perform arbitrary file reads.

😱 "an OpenSSL mini-language".

😱😱 "which can perform arbitrary file reads".

I believe this situation was correctly summarized by [Alex Gaynor] as
a [horror show] and certainly seemed perfect for a spooky October blog post.

# Stop the Madness

So now we understand why the certificate is invalid, when & why the `openssl`
crate changed its `SubjectAlternativeName` builder behaviour, and how OpenSSL
continues to provide new and exciting ways to shoot your feet off.

I'd be remiss if I didn't close this story by suggesting it might be time to
reconsider your OpenSSL dependencies. 

For certificate generation needs consider [rcgen] for simpler situations, or the
Rust Crypto project's [x509-cert] crate if you have more complex needs. For TLS,
consider [rustls]. It's safer, and faster too. 

Your sanity deserves it.

[openssl crate]: https://crates.io/crates/openssl
[SubjectAlternativeName]: https://docs.rs/openssl/latest/openssl/x509/extension/struct.SubjectAlternativeName.html
[rustls#1292]: https://github.com/rustls/rustls/issues/1292
[the cert provided]: https://gist.github.com/cpu/43697ca55fccd04e91f66540ea66ae62
[der-ascii]: https://github.com/google/der-ascii
[dns]: https://docs.rs/openssl/latest/openssl/x509/extension/struct.SubjectAlternativeName.html#method.dns
[rust-openssl#1854]: https://github.com/sfackler/rust-openssl/pull/1854
[RUSTSEC-2023-0023]: https://rustsec.org/advisories/RUSTSEC-2023-0023.html
[David Benjamin]: https://davidben.net/
[Alex Gaynor]: https://alexgaynor.net/
[horror show]: https://github.com/sfackler/rust-openssl/pull/1854/commits/a7528056c5be6f3fbabc52c2fd02882b208d5939
[rustls]: https://github.com/rustls/rustls
[rcgen]: https://github.com/rustls/rcgen
[x509-cert]: https://docs.rs/x509-cert/latest/x509_cert/

[^1]: Check out [A Warm Welcome to ASN.1 and DER](https://letsencrypt.org/docs/a-warm-welcome-to-asn1-and-der/) and [RFC 5280](https://www.rfc-editor.org/rfc/rfc5280) if you're curious about understanding the full `der-ascii` output.
