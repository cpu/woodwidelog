---
title: "To Clear Skies"
summary: Nix Flakes, deploy-rs, Blightspell.
date: 2023-03-26T08:00:00-04:00
---

Since February I've been working on regaining my focus. It feels like something
that used to come naturally but now takes deliberate action. With focus, I'm
returning more to habits and systems of work I felt stronger about before
the influence of the broader tech industry led me down a road of making
concessions. I won't pretend I don't have to modulate self-doubt, but at least
there aren't any OKRs.

![Sky](./sky.png)

# Lately

## Nix Flakes

I started using Nix and [NixOS] in early 2020. This meant I was _just_ a little
bit early for the introduction of [Nix Flakes]. As a result my primary
configurations have always been using the classic "channels" approach. To
criminally under-summarize, Nix flakes introduce some standardized structure
that improves both the composability and reproducibility of the Nix ecosystem.


It didn't take long for the advantages of "the flakes way" to percolate into my
brain enough that I started using flakes in smaller one-off projects (like
[this blog] for example) but I was still carrying around legacy baggage for my
most important use-cases (laptop and server configurations). That's a shame,
because flakes (while still experimental) are an obvious improvement over the
status quo. Folks new to Nix are best served by skipping over the legacy world
and moving right to flakes.

With more free time I finally got around to switching all of my legacy
configurations to a flake based monorepo. In sum it was a super easy transition,
even with [Home Manager] and some custom pinning in the mix. If you're like me
and have been holding off on making the switch you should take the plunge! It
was less work than I expected and I'm really happy with the convenience of
managing a single `flake.lock` file for all of my laptop and server
configurations. I'd love to make my monorepo public but I still haven't found
a nice way to elide bits of configuration that aren't runtime secrets favourable
to [sops-nix], but also feel icky to hang out in the open. If we know each other
personally and you're looking for more Nix resources feel free to reach out and
I can add you as a collaborator.

[NixOS]: https://nixos.org/
[Nix Flakes]: https://www.tweag.io/blog/2020-05-25-flakes/
[this blog]: https://github.com/cpu/woodwidelog/blob/main/flake.nix
[Home Manager]: https://github.com/nix-community/home-manager
[sops-nix]: https://github.com/Mic92/sops-nix

## deploy-rs

Of course, no migration is ever _totally_ seamless.. While sketching out
a transition to using Nix flakes I realized that the scheme I used to manage
server configuration with NixOS needed to change too.

Historically I've used [NixOps] as a Nix-based approximation of other
server configuration tools like [Ansible]. Using NixOps I could describe
system/service configurations in Nix, build the closures locally, and ship the
required parts of the Nix cache to remote systems. While it worked well for
me initially it hasn't aged gracefully. Development has mostly stalled and often
the package is marked insecure, requiring [annoying workarounds][insecure] to
use. Ultimately the breaking point was the weak flake support and missing
documentation.

I've since switched to using [deploy-rs] and can't say enough nice things about
it. It was minimal work to adapt my existing configurations into a flake that
`deploy-rs` could use to shuffle specific `nixosConfigurations` off to remote
machines. Flake support is top notch, and the Rust based tooling has a much
smaller system footprint than the Python based NixOps environment. It also uses
a clever "dead-man's switch" system to achieve [magic rollback] to a previous
configuration generation if the new generation fails to activate cleanly.

[NixOps]: https://github.com/NixOS/nixops
[Ansible]: https://www.ansible.com/
[insecure]: https://nixos.org/manual/nixpkgs/stable/#sec-allow-insecure
[deploy-rs]: https://github.com/serokell/deploy-rs
[magic rollback]: https://github.com/serokell/deploy-rs#magic-rollback

## Blightspell

It wouldn't be a wood wide log update if I didn't find a way to shoehorn in some
MUD related content (see also [carcinisation], [slow-moving]). In February
I spent some time chasing the dream of a fancy spellchecking experience for
[Blightmud], my terminal [MUD] client of choice.

To achieve what I wanted I had to a handful of new Blightmud features including:

* callback support for when unsent data in the [prompt area changes].
* a new module for manipulating [a "mask"][masking] for decorating unsent prompt
  data.
* a new low-level [spellcheck] module that offers bindings on top of [hunspell].

With those features landing in [Blightmud v5.1.0] it was possible to write
[Blightspell], a Lua plugin for Blightmud that implements real-time spellcheck.
I'm really happy with the end result! If you're a Blightmud user be sure to give
it a try and let me know what you think :-)

[![asciicast](https://asciinema.org/a/uHAMcFnDaLxHbzqGxtJrwNCx0.svg)](https://asciinema.org/a/uHAMcFnDaLxHbzqGxtJrwNCx0)

[slow-moving]: https://log.woodweb.ca/2022/10/slow-moving/
[carcinisation]: https://log.woodweb.ca/2023/01/carcinisation/
[Blightmud]: https://github.com/blightmud/blightmud
[MUD]: https://en.wikipedia.org/wiki/MUD
[prompt area changes]: https://github.com/Blightmud/Blightmud/blob/6b4c5fefebddb31694140afa0e544bec4b276ab2/resources/help/prompt.md?plain=1#L39-L49
[masking]: https://github.com/Blightmud/Blightmud/blob/dev/resources/help/prompt_mask.md
[spellcheck]: https://github.com/Blightmud/Blightmud/blob/dev/resources/help/spellcheck.md
[hunspell]: https://hunspell.github.io/
[Blightmud v5.1.0]: https://github.com/Blightmud/Blightmud/releases/tag/v5.1.0
[Blightspell]: https://github.com/cpu/blightspell

# Thinking about

* [Miniflux] - Until Google Reader was shutdown (RIP) I was a heavy user of
  [RSS]. Since Twitter is being turned into dogshit by an egomaniac I've come
  back to RSS as a way to stay on top of cool writing. Miniflux is a great
  self-hosted experience and it gets extra points being written in Go.
* [Autosquash in Git] - I'm no stranger to `git rebase --interactive` but
  learning about autosquash from Bob Vanderlinden's blog has been
  a game-changer. Shout out to the developers that are meticulous about a clean
  and helpful `git log` - it's rarer than you would hope. 💔
* [Moving the Posts] - this post from Drew Schuster's blog lands squarely in the
  overlap of my continued interest in learning about the power grid and my
  experiences with system maintenance. You'll laugh, you'll cry, you'll
  bookmark.

[Miniflux]: https://github.com/miniflux/v2
[RSS]: https://en.wikipedia.org/wiki/RSS
[Autosquash in Git]: https://bobvanderlinden.me/autosquash-in-git/
[Moving the Posts]: https://drew.shoes/posts/moving-the-posts/

# Until next time

![Turkey Tracks](./tracks.png)

