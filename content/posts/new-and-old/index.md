---
title: "New and Old"
summary: Rustls, 30 year old LPC.
date: 2023-05-07T08:00:00-04:00
type: log
---

Spring has sprung and it's a potent reminder of how much I value contrast.
Moaning about the winter is a well established Canadian past-time but I've
realized I need four distinct seasons to feel right. For me it's easier to
appreciate the small details that the change in seasons provides when the
differences are so stark.

![Waves](./waves.png)

# Lately

Recently I've been having fun contrasting professional work at the edge
of some important new trends with recreational work on code living on a very
different timescale.

## Rustls

On the side of modernity, for the past ~two months I've been working on-contract
for the [ISRG]'s [Prossimo] project on their memory-safety for TLS initiative.
It's been a fun challenge to onboard both to professional Rust development and
to the [Rustls] ecosystem of projects at the same time. I believe strongly in
the need for a memory safe alternative to OpenSSL and Rustls has so many unique
advantages above-and-beyond being written in Rust. I'm extremely grateful to
have the opportunity to learn from the heavy-hitters that have made the project
so strong.

### The new guy

Being new has meant finding creative ways to help out while still learning the
ropes. So far I've been able to pitch in with misc. tasks to help get [Rustls
0.21.0] out the door, helped clear up some issue/pull request backlog, fixed
some old bugs, and adopted some in-progress work that needed more attention to
get across the goal line. While not a massive technical achievement I'm
particularly happy to have landed a small [webpki] crate [feature] for
collecting certificate DNS subjects that has been carried along by ~3 other sets
of people all the way back to 2017. A real team effort!

One day I'd like to try and write down some of my strategies and thoughts about
joining an open source project like Rustls but for now I'm trying to get back on
the blog train with some quick updates. Stay tuned. :-)

### Blightmud

Readers of my dev log know I can't resist talking about [Blightmud] and of
course I quickly found a way to combine my new energy for Rustls with my
existing love of that project. Outside of work hours I [replaced] Blightmud's
code for connecting to MUDs over TLS from using OpenSSL to Rustls. Besides being
a spiritual win it ended up fixing a mysterious crash on MacOS that nobody had
been able to diagnose. Replacing a separate libcurl based feature to use a pure
Rust alternative also [fixed] some long-standing flaky unit tests so it's no
fluke! I can't overstate how pleasant I've been finding Rust and its surrounding
ecosystem.

[ISRG]: https://www.abetterinternet.org/
[Prossimo]: https://www.memorysafety.org/
[Rustls]: https://github.com/rustls/rustls
[Rustls 0.21.0]: https://www.memorysafety.org/blog/rustls-new-features/
[webpki]: https://github.com/rustls/webpki
[feature]: https://github.com/rustls/webpki/pull/42
[Blightmud]: https://github.com/blightmud/blightmud
[replaced]: https://github.com/Blightmud/Blightmud/pull/775
[fixed]: https://github.com/Blightmud/Blightmud/pull/782#issuecomment-1501197372

## LDMud Upgrades

At the complete other end of the spectrum I've been working on upgrading
[a codebase] that started in 1993 to a modern [LDMud] release.

[a codebase]: https://dunemud.net/doku.php/start
[LDMud]: http://www.ldmud.eu/

## Background

I've talked a little bit about LDMud in [a previous entry]. To keep things short
and sweet you can think of it as a cross between a game engine like Unity or
Unreal Engine, and a scripting language with a bytecode based VM like Python.
Much of its existence can be understood through the lens of the early 1990s and
the need to be able to support two important use-cases:

1. Live reloading game content without recompilation or process restart.
2. Supporting development of game content by amateur developers.

The first requirement comes from frustration working with traditional C based
MUD codebases that were popular at the time. Adding new game content written in
C required rebuilding the game (slow!) and restarting the process to pick up the
changes (there go all your players, and anything in the game world that isn't
persisted!).

The second requirement was similarly (at least in my mind) driven by
frustrations with C. A monolithic C-based system left no room for programmer
error. Simple mistakes inevitably lead to difficult to diagnose memory
corruption bugs. Similarly most of the game designers and content contributors
were learning to code for the first time. The combination of a **very** text
heavy use case, C's poor support for string manipulation, and a bunch of novice
programmers is a sure recipe for disaster.

[a previous entry]: /2022/10/wwl/

## Old LPC Code

The solution echoes trends in the rest of the industry. Use C for the heavy
lifting, network programming, and interfacing with the operating system and
embed a scripting language for the game content. The LP flavour of MUD arose
around the development of [LPC] as this scripting language and LD implements it by
compiling LPC to a bytecode it runs in a bespoke virtual machine (much like Java
bytecode and the JVM).

In the case of [the MUD I have a personal attachment to][Dune] there's been
a steady development of game content in LPC spanning 30 years of work by
multiple independent sets of people. I fell into this scene in ~2001 as a goofy
teenager and by then there had been at least two whole separate sets of
developers that came before me. As you can expect, the code quality is
incredibly varied and mysterious spooky action at a distance abounds. More than
anything there's just _a lot of code_. While only a portion of it actually gets
used in game there's on the order of 60,000 individual `.c` (LPC) files kicking
around.

[Dune]: https://dunemud.net

## Fighting Entropy

With this kind of codebase every game engine update brings a flood of
compilation errors and bugs to chase down. In ~2021 I fought my way through two
big LDMud updates. The first, updating from LDMud 3.2.17 (released ~2010) to
3.3.720 (released ~2011). For the second, I managed to switch the game from
32bit `i686` to 64 bit `x86_64` (no small feat for code this old!) and updated
to LDMud 3.5.4 (released ~2021). That's around when my energy fell off. The next
big update to the 3.6.x release stream brought a move to UTF-8 similar to the
Python2 -> Python3 migration and I had to table the project for a while.

Recently I found the motivation to get back to work (call it spring energy) and
move the game to LDMud 3.6.6 (the latest release at the time of writing). With
a few upgrades under my belt I have a pretty good system for how I approach the
problem but it's still a unique experience to find yourself fixing bugs in code
that was written when you were 6 years old. Sometimes I felt like I was
conversing with ghosts. Would the original authors of this code remember it?
Would they appreciate me keeping it running into 2030? Bumping into comments
from friends and mentors long lost can be bittersweet. This particular upgrade
effort has resulted in touching close to 1000 different files.

One day it might be interesting to talk about the categories of changes and bugs
I bumped into but for now I'll say the effort paid off and the production game
will soon be running on the latest and greatest LDMud. I think this might be the
first time in the game's 30 year history that we've been ahead of the upgrade
curve and it feels pretty good. I can't speak to how much fun the game is to play
but it's important for me to keep it around. One day I might be able to
articulate why.

[LPC]: https://handwiki.org/wiki/LPC_(programming_language)

# Thinking about

![Breakthrough](./breakthrough.png)

* [Coltsfoot]. Without fail these little guys are _always_ the first thing to
  poke up out of the frozen ground. They're not the prettiest but I sure admire
  their tenacity. Towards the end of winter I start to obsess with watching for
  the first appearance (_April 14th this year_).
* [The registers of Rust]. I found this blog post by [without.boats] to be
  a really interesting perspective on the "registers" (in the linguistics sense,
  not the CPU sense) of programming languages. This was a new lens for me and it
  resonated.
* [Driver adventures for a 1999 webcam][Driver adventures]. Just seeing one of
  these ancient "eyeball" webcams again brought back a lot of memories of time
  spent chatting on MSN Messenger. Besides being nostalgic the technical
  trickery required to get it working again with a modern machine made for a fun
  read.

[Coltsfoot]: https://en.wikipedia.org/wiki/Tussilago
[The registers of Rust]: https://without.boats/blog/the-registers-of-rust/
[without.boats]: https://without.boats/
[Driver adventures]: https://blog.benjojo.co.uk/post/quickcam-usb-userspace-driver

# Until next time

![Grack Pack](./grackpack.png)

