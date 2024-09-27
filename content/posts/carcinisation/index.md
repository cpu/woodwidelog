---
title: "Carcinisation"
summary: Snowshoeing, NAWS, Trust-DNS.
date: 2023-01-15T08:00:00-04:00
type: log
---

Winter has blessed my area with ample snow. January is a classic prompt for 
evaluating one's shit and I can get a lot of thinking done in the pockets of
silence a snowy forest provides. Lately I'm thinking a lot about trusting
myself. I'm ready to take some bigger swings even if a few might miss.

![Snowshoeing](./snowshoe.jpg)

# Lately

I've dabbled with the Rust programming language a few times over the past few
years but haven't hit the tipping point where it feels _comfortable_. The past
month or so I've been trying to find excuses to address that by getting my hands
dirty where I can.

## Blightmud NAWS Support

Readers of this log (_uncountably numerous, I'm sure_) will remember [Blightmud]
coming up [in a previous post][slow-moving] where I discussed some challenges
I encountered writing a Nixpkgs derivation to package it. **TLDR:** Blightmud is
a souped up Telnet client for [MUDs] written in Rust, with scripting provided by
Lua.

Over the holidays I was working on some fancy server-side text rendering code
for displaying MUD data in a table format. Making layout decisions about column
widths and the number of rows to display requires having some sense of how big
the client's terminal window is. Fortunately, way back in 1988 the IETF network
working group proposed a standard ([RFC 1073]) that describes a way for a telnet
server and client to "Negotiate About Window Size" (NAWS). This happens
out-of-band from the output presented to the user and is automatically updated
if the client window is resized. Perfect!

_Only one catch..._ While other clients like [Tintin++] and [Mudlet]
already supported NAWS, Blightmud did not. :frowning_face:

In some ways this was actually fortunate! It gave me a chance to dig into the
codebase and [implement it] myself. Because the Telnet negotiation logic was
already exposed to Lua it didn't even require very much Rust to accomplish. The
only significant Rust change was implementing a new event handler
([`blight.on_dimensions_change`][on_dimensions_change]) exposed to the Lua code
so that we could perform NAWS updates whenever the terminal window changed
dimensions. From there all the interesting bits happen in [pure Lua].

While I was kicking around I also fixed a flaky [`ndk-sys` checksum
err][ndk-sys], and a small [GMCP interop. gotcha][gmcp-compat]. Both trivial
changes.

[Blightmud]: https://github.com/blightmud/blightmud
[slow-moving]: https://log.woodweb.ca/2022/10/slow-moving/
[MUDs]: https://en.wikipedia.org/wiki/MUD
[RFC 1073]: https://www.rfc-editor.org/rfc/rfc1073
[Tintin++]: https://tintin.mudhalla.net/
[Mudlet]: https://mudlet.org/
[implement it]: https://github.com/Blightmud/Blightmud/commit/35bd9bebe682a85cb46f5b7ef9af0b18a54772e5
[on_dimensions_change]: https://github.com/Blightmud/Blightmud/blob/35bd9bebe682a85cb46f5b7ef9af0b18a54772e5/resources/help/lua_blight.md?plain=1#L35-L44
[pure Lua]: https://github.com/Blightmud/Blightmud/blob/35bd9bebe682a85cb46f5b7ef9af0b18a54772e5/resources/lua/naws.lua
[ndk-sys]: https://github.com/Blightmud/Blightmud/commit/761823ea34d7a01e665d2608fd2c1a0933d02ec2
[gmcp-compat]: https://github.com/Blightmud/Blightmud/commit/08815e8a403507040bbeee2005b37224af18495c

## Trust-DNS

For a long time I've hosted my own authoritative DNS zones, first with [BIND] and
then later with [Knot]. While it's certainly easier to use a hosted DNS service
from your registrar or hosting provider it's definitely a lot more educational
to do it yourself. I'm generally happy with Knot, but sure would love to have an
alternative that was written in a memory safe language. DNS is at that perfectly
terrifying intersection of performance critical code and having to parse complex
and untrusted data from a network socket. For that reason I was stoked when
[ISRG's Prossimo project][prossimo] announced support for a DNS initiative
[supporting Trust-DNS], a suite of DNS software written in Rust.

After whipping up a quick Nix derivation (_I haven't cleaned this up for
Nixpkgs yet, stay tuned_) I decided to try and take [Trust-DNS] for a spin with
my zone data. I hit a couple snags right away which made for a great chance to
roll my sleeves up.

The first snag was simple: I was spinning my wheels looking for a `named` binary
that was referenced in the README instructions but that wasn't being produced by
my derivation, or a vanilla `cargo` build. It turned out this was just bad
timing, the project only [recently switched] to preferring a `trust-dns` binary
name. I was able to [clean up the remaining references][clean-up] with some
`grep`/`sed` magic.

The second snag was more interesting: the zone data files I had been carrying
around for ~10 years were failing to parse with an error like:

> Error { kind: Message("record class not specified") }'

Much like the error claims, none of my records specified a record class. It
seems this never came up for me before now because both Knot and BIND would
parse these zones by implicitly assuming they were class IN (for "INternet").
(_99.9999% of the time this is the only choice that makes sense in 2023_).

Deciding who's at fault here, my zone files or trust-dns, required digging in to
[RFC 1035], and specifically, §5 [MASTER FILES]. On the topic of class fields that
section says:

> The RR begins with optional TTL and class fields, followed by a type and RDATA
> field appropriate to the type and class. Class and type use the standard
> mnemonics, TTL is a decimal integer. Omitted class and TTL values are default
> to the last explicitly stated values. 

In classic RFC fashion this isn't very helpful if you're considering a case
where there _isn't any_ explicitly stated value. The class and TTL are both
optional, so what do you do when zero records specify a class? In this case,
like most areas where the RFCs are vague, most folks just Do What BIND
Does:tm:. For this situation that means "assume the class is IN".

I whipped up [a small PR] to adopt this behaviour and `trust-dns` was able to
parse my zones without any other changes. :tada: Folks seem in agreement that
supporting this type of zone file is sensible so we're just waiting on some
other review details to be sorted out. Along the way I also [fixed] a small
`cargo audit` CI failure with a trivial dep. bump.

Trust-DNS isn't quite ready to replace Knot for my use-cases but I'm excited to
try and help it get it there.

[BIND]: https://www.isc.org/bind/
[Knot]: https://www.knot-dns.cz/
[prossimo]: https://www.memorysafety.org/
[supporting Trust-DNS]: https://www.memorysafety.org/initiative/dns/
[Trust-DNS]: https://github.com/hickory-dns/hickory-dns
[recently switched]: https://github.com/hickory-dns/hickory-dns/pull/1859
[clean-up]: https://github.com/hickory-dns/hickory-dns/pull/1873
[RFC 1035]: https://datatracker.ietf.org/doc/html/rfc1035
[MASTER FILES]: https://datatracker.ietf.org/doc/html/rfc1035#autoid-48
[a small PR]: https://github.com/hickory-dns/hickory-dns/pull/1874
[fixed]: https://github.com/hickory-dns/hickory-dns/pull/1877

# Thinking about

![Happy rock](./happyrock.jpg)

* [Happy Rock] - a glorious roadside attraction _slash_ information centre for
  Gladstone Manitoba. What a dapper looking rock.
* [Veggie Dog] - my (_much smarter and much more talented_) love has a blog of
  her own. You should read it. The writing is fantastic and a lot less fractured
  than my own.
* [Bowling Servers] - hat tip to [Cathode Ray Dude] for surfacing this niche.
  It's amazing what you can do with a few pixels of grayscale input.

[Happy Rock]: https://en.wikipedia.org/wiki/Happy_Rock
[Veggie Dog]: https://veggie.dog/
[Bowling Servers]: https://cohost.org/cathoderaydude/post/796581-bowling-servers
[Cathode Ray Dude]: https://cohost.org/cathoderaydude

# Until next time

![Glitter](./glitter.jpg)

