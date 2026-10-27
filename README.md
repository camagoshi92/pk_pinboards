# pk_pinboards

Persistent notice boards for RedM / VORP. Players pin notes with a title, a message and an optional image on bounty-board props placed around the map, with a responsive western-style interface, per-board limits, job restrictions, moderation and Discord logs.

## Features

- Notice boards on the `mp005_p_mp_bountyboard02x` prop (or any prop already on the map).
- Notes with title, message, text size (small / normal / large) and an optional image from a direct HTTPS link.
- Full-size image viewer and day/night look that follows the in-game clock.
- Per-board limits: maximum posts, posts per player and post duration (default 7 days).
- Boards restricted by job and grade, or posting limited to specific groups.
- Moderation through ACE, VORP groups, jobs or Discord roles.
- Discord logs: one staff webhook for every board, plus an optional webhook per board.
- Italian and English included, more languages can be added in `locales.lua`.
- Server-side validation of distance, permissions, text and image URLs.

## Requirements

- `vorp_core`
- `oxmysql`

## Installation

1. Put the `pk_pinboards` folder in your resources.
2. The database table is created automatically through `oxmysql`.
3. Set coordinates, jobs, limits and webhooks in `config.lua`.
4. Add `ensure pk_pinboards` to your `server.cfg`, after `oxmysql` and `vorp_core`.
5. To give moderator rights with ACE: `add_ace group.admin pk_pinboards.moderate allow`.

## Language

```lua
Config.Locale = 'en' -- 'it' or 'en'
```

Every text (in-game messages, board interface and Discord logs) lives in `locales.lua`. To add a language, copy a block, change its key and translate the values.

## Boards

Each entry in `Config.Boards` is a board:

```lua
{
    id = 'valentine_public',          -- unique id
    label = 'Valentine notice board',
    coords = vector4(-272.35, 805.23, 118.31, 9.31), -- or a list of vector4
    jobs = nil,                       -- nil = public; { sheriff = 0 } = job and minimum grade
    postGroups = nil,                 -- nil = everyone can post; { 'admin' } = only these groups
    spawnObject = true,               -- false = use a prop already on the map
    maxPosts = 10,
    maxPostsPerPlayer = 2,
    postDurationHours = 168,
    webhook = '',                     -- optional Discord webhook for this board
}
```

Coordinates use `vector4(x, y, z, heading)` and are applied without automatic offsets, so wall-mounted boards keep exactly the configured position. Set `placeOnGround = true` on a board only when the prop should snap to the ground. Posts are written to the database immediately; a timer removes expired posts periodically.

## Discord logs

In `Config.Discord`:

- `globalWebhook`: staff log, receives every new post and every removal, with character, Steam name and Steam ID.
- `defaultWebhook`: used by boards without their own `webhook`.
- `deleteWebhook`: removals only; empty = `globalWebhook`.

## Discord roles

Enable `Config.Permissions.discord`, set the resource/export of your Discord bridge and add the role IDs in `roleIds`. The recommended form is `['ROLE_ID'] = true`.

## Image URLs

For safety only direct HTTPS links ending in `.jpg`, `.jpeg`, `.png`, `.webp` or `.gif` are accepted. Extend the blacklist and the extensions in `Config.Validation`.
