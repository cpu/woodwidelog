---
title: "Rock Replace"
summary: Mudlet, NixPkgs Lua Overrides, Bowling.
date: 2022-11-09T08:00:00-04:00
---

I hear federation is cool now. If you're reading this, start a blog. It's the
hip old new way to have decentralized shitposts.

![Lake view](./lakeview.jpg)

# Lately

I'm doubling down on writing the world's most niche technology blog and
bringing you another adventure from the intersection of [MUD Clients] and
[NixPkgs]. Thrills abound, what can I say.

[MUD clients]: https://mud.fandom.com/wiki/MUD_client
[NixPkgs]: https://github.com/NixOS/nixpkgs

## Mudlet

This time around I was looking into the [Mudlet] derivation, which seemed to be
stalled at [4.15.1] in the unstable NixPkgs channel, while the latest release was
[4.16.0]. What was the hold-up? Well, SQLite3 support was broken:

```bash
[ ERROR ] - Cannot find Lua module sqlite3.
Lua error: error loading module 'luasql.sqlite3' from file.
'/nix/store/ng8m8g0sddihql99nds5z8amd30qiaig-lua-5.1.5-env/lib/lua/5.1/luasql/sqlite3.so':
/nix/store/ng8m8g0sddihql99nds5z8amd30qiaig-lua-5.1.5-env/lib/lua/5.1/luasql/sqlite3.so: 
  undefined symbol: lua_isinteger
Database support will not be available.
```

After some digging I had a strong theory for the root cause. For Reasons:tm:
Mudlet only supports Lua 5.1 and the careful observer will note that the missing
symbol from the error message, `lua_isinteger`, only appears in the [Lua 5.3
API Docs]. The `LuaSQL-SQLite3` [LuaRocks page][luasql-sqlite3] lists
compatibility with Lua >= 5.1 but a [commit from last year][regression] relies
on a Lua 5.3+ C API feature! How hasn't this broken anyone else you might ask?
Simple: the regression hasn't been bundled into a release yet. It's just us
folks on the bleeding edge that are getting cut and NixPkgs at the time of
writing has the library [pinned at a rev] that includes the regression. :knife:

An [upstream issue] was dutifully filed but I wanted to unbreak Mudlet
today. First I considered overriding the LuaRocks rev for the problematic lib
back to before the regression. There's even a [handy
`overrides.nix`][lua-modules-overrides] for Lua modules that could have been
used for that. I discarded this approach because it would be changing the
version for all of Nixpkgs and the blast radius seemed too high; maybe there are
Lua 5.3 users happy with the more up-to-date package.

To localize the fix to just Mudlet I [took a different approach][fix commit],
using a package override for the Lua derivation used to build the Lua
environment with the dependencies Mudlet requires:
```nix
  ...
  overrideLua =
    let
      packageOverrides = self: super: {
        # luasql-sqlite3 master branch broke compatibility with lua 5.1. Pin to
        # an earlier commit.
        # https://github.com/lunarmodules/luasql/issues/147
        luasql-sqlite3 = super.luaLib.overrideLuarocks super.luasql-sqlite3
          (drv: {
            version = "2.6.0-1-custom";
            src = fetchFromGitHub {
              owner = "lunarmodules";
              repo = "luasql";
              rev = "8c58fd6ee32faf750daf6e99af015a31402578d1";
              hash = "sha256-XlTB5O81yWCrx56m0cXQp7EFzeOyfNeqGbuiYqMrTUk=";
            };
          });
      };
    in
    lua.override { inherit packageOverrides; };

  luaEnv = overrideLua.withPackages (ps: with ps; [
    luasql-sqlite3
    ...
  ]);
  ...
```

It worked perfectly. :tada: No more undefined symbol trouble and Mudlet 4.16.0 is
[now available][nixpkgs-search] in the NixPkgs unstable channel.

**Bonus**: I also fixed the optional integration to let Mudlet set your [activity
status] in Discord based on the MUD you're playing. Getting that working was just
a matter of wiring a dependency on `discord-rpc` through to the QT wrapper
`LD_LIBRARY_PATH`.

[Mudlet]: https://mudlet.org/
[4.16.0]: https://github.com/Mudlet/Mudlet/releases/tag/Mudlet-4.16.0
[4.15.1]: https://github.com/Mudlet/Mudlet/releases/tag/Mudlet-4.15.1
[Lua 5.3 API Docs]: https://www.lua.org/manual/5.3/manual.html#lua_isinteger
[luasql-sqlite3]: https://luarocks.org/modules/tomasguisasola/luasql-sqlite3
[regression]: https://github.com/lunarmodules/luasql/commit/ad59e6bf09b1eab5df02a7bc2bca056222a26030
[pinned at a rev]: https://github.com/NixOS/nixpkgs/blob/c588a77cd54fbdbe874ddd1e63656d5fd69c6ae6/pkgs/development/lua-modules/generated-packages.nix#L2164-L2185
[upstream issue]: https://github.com/lunarmodules/luasql/issues/147
[lua-modules-overrides]: https://github.com/NixOS/nixpkgs/blob/fbec74286dd682720703fc455ec650c0a8552dbf/pkgs/development/lua-modules/overrides.nix#L352-L356
[fix commit]: https://github.com/NixOS/nixpkgs/pull/199944/commits/ae5ed8ce226db3913adf7b1107487f53bd8c69da
[nixpkgs-search]: https://search.nixos.org/packages?channel=unstable&show=mudlet&from=0&size=50&sort=relevance&type=packages&query=mudlet
[activity status]: https://support.discord.com/hc/en-us/articles/7931156448919-Activity-Status-Rich-Presence-Settings

# Thinking about

![Candlepin Bowling](./candlepin.png)

* [Candlepin Bowling] - how can you not love a weird bowling variant [nearly
  exclusive] to the Maritimes. :bowling: 
* [Stupid tricks with ioring]: come for the clickbait title, stay for the
  interesting (ab)use of ioring.
* [FULCI]: _"The death metal band named after the Godfather of gore"_, exactly as
  described on the tin, 8/10.

[Candlepin Bowling]: https://en.wikipedia.org/wiki/Candlepin_bowling
[nearly exclusive]: https://en.wikipedia.org/wiki/Candlepin_bowling#/media/File:20190514_Candlepin_states_and_provinces.png
[Stupid tricks with ioring]: https://wjwh.eu/posts/2021-10-01-no-syscall-server-iouring.html
[FULCI]: https://fulcicult.bandcamp.com/album/exhumed-information


# Until next time

![Sunset view](./sunset.jpg)
