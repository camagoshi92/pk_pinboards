Config = {}

Config.Locale = 'it' -- 'it' or 'en'; texts are in locales.lua
Config.OpenControl = 0x760A9C6F -- G
Config.InteractDistance = 2.25
Config.RenderDistance = 120.0
Config.TextDistance = 8.0
Config.Show3DText = true
Config.ShowAuthor = false
Config.SaveIntervalMinutes = 10

Config.Defaults = {
    model = 'mp005_p_mp_bountyboard02x',
    spawnObject = true,
    -- false keeps the configured Z exactly (recommended for wall-mounted boards).
    -- Set true on a single board only if the prop must rest on the ground.
    placeOnGround = false,
    maxPosts = 10,
    maxPostsPerPlayer = 2,
    postDurationHours = 168, -- 7 days
}

Config.Validation = {
    titleMax = 64,
    bodyMax = 500,
    urlMax = 500,
    textSizes = { small = true, normal = true, large = true },
    requireHttps = true,
    allowedExtensions = { '.jpg', '.jpeg', '.png', '.webp', '.gif' },
    -- Server-side text check. Add unwanted domains or fragments.
    blacklistedUrlParts = {
        'porn', 'xxx', 'hentai', 'rule34', 'xvideos', 'xnxx', 'redgifs',
    },
}

Config.Permissions = {
    ace = 'pk_pinboards.moderate',
    frameworkGroups = { 'admin', 'superadmin', 'mod' },
    -- Jobs allowed to remove any post. Value = minimum grade.
    jobs = {
        sheriff = 0,
        police = 0,
    },
    discord = {
        enabled = false,
        resource = 'Badger_Discord_API',
        export = 'GetDiscordRoles',
        roleIds = { -- ['123456789012345678'] = true
        },
    },
}

Config.Discord = {
    enabled = true,
    username = 'Pinboard Logs',
    avatarUrl = '',
    defaultWebhook = '',
    globalWebhook = '',
    deleteWebhook = '',
}

-- Add as many boards as you like.
-- coords accepts vector4(x, y, z, heading) or a list of vector4 sharing the same board/posts.
-- jobs = nil makes the board public; jobs = { sheriff = 0, police = 1 }
-- postGroups = nil lets everyone post; postGroups = { 'admin' } only restricts posting.
-- placeOnGround = false uses the exact coordinates; true snaps the Z to the ground.
-- webhook = 'https://discord.com/api/webhooks/...' (optional) sends new posts of that board
-- to its own channel; the globalWebhook still receives every board.
Config.Boards = {
    {
        id = 'admin_announcements',
        label = 'Bacheca Amministrazione',
        coords = vector4(338.760009765625, -679.280029296875, 41.81000137329101, 58.99999618530273),
        jobs = nil,
        postGroups = { 'admin' },
        spawnObject = true,
        model = 'mp005_p_mp_bountyboard02x',
        maxPosts = 10,
        maxPostsPerPlayer = 2,
        postDurationHours = 168,
        show3DText = true,
    },
    {
        id = 'valentine_public',
        label = 'Bacheca di Valentine',
        coords = {
            vector4(-272.35, 805.23, 118.31, 9.31),
        },
        jobs = nil,
        spawnObject = true,
        model = 'mp005_p_mp_bountyboard02x',
        maxPosts = 10,
        maxPostsPerPlayer = 2,
        postDurationHours = 168,
        show3DText = true,
    },
    -- {
    --     id = 'tumbleweed_public',
    --     label = 'Bacheca di Tumbleweed',
    --     coords = vector4(-5529.49, -2932.68, -1.97, 207.95),
    --     jobs = nil,
    -- },
    -- {
    --     id = 'armadillo_public',
    --     label = 'Bacheca di Armadillo',
    --     coords = vector4(-3625.96, -2611.13, -13.76, 0.0),
    --     jobs = nil,
    -- },
    -- {
    --     id = 'blackwater_public',
    --     label = 'Bacheca di Blackwater',
    --     coords = vector4(-792.95, -1247.91, 43.40, 0.0),
    --     jobs = nil,
    -- },
    {
        id = 'strawberry_public',
        label = 'Bacheca di Strawberry',
        coords = vector4(-1803.26, -358.16, 162.88, 135),
        jobs = nil,
        spawnObject = true,
        model = 'mp005_p_mp_bountyboard02x',
        maxPosts = 10,
        maxPostsPerPlayer = 2,
        postDurationHours = 168,
        show3DText = true,
    },
    {
        id = 'rhodes_public',
        label = 'Bacheca di Rhodes',
        coords = vector4(1356.15, -1308.61, 76.01, -18),
        jobs = nil,
        spawnObject = true,
        model = 'mp005_p_mp_bountyboard02x',
        maxPosts = 10,
        maxPostsPerPlayer = 2,
        postDurationHours = 168,
        show3DText = true,
    },
    {
        id = 'ranch_valentine',
        label = 'Bacheca del ranch',
        coords = vector4(-85.59, -11.12, 94.50, 128.99),
        jobs = nil,
    },
    --[[
    {
        id = 'sheriff_only',
        label = 'Ricercati dello Sceriffo',
        coords = vector4(-278.0, 807.0, 119.4, 180.0),
        jobs = { sheriff = 0 },
        spawnObject = true,
    },
    ]]
}
