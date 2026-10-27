local Core = exports.vorp_core:GetCore()
local Boards = {}

for _, board in ipairs(Config.Boards) do
    assert(type(board.id) == 'string' and board.id ~= '', '[pk_pinboards] Ogni bacheca richiede un id univoco')
    assert(not Boards[board.id], ('[pk_pinboards] ID duplicato: %s'):format(board.id))
    Boards[board.id] = board
end

local function setting(board, key)
    if board[key] ~= nil then return board[key] end
    return Config.Defaults[key]
end

local function boardLocations(board)
    if not board.coords then return {} end
    if board.coords.x then return { board.coords } end
    return board.coords
end

local function getCharacter(source)
    local user = Core.getUser(source)
    if not user then return nil end
    local character = user.getUsedCharacter
    if type(character) == 'function' then character = character() end
    return character
end

local function charValue(character, key, fallback)
    if not character then return fallback end
    local value = character[key]
    if type(value) == 'function' then
        local ok, result = pcall(value, character)
        return ok and result or fallback
    end
    return value ~= nil and value or fallback
end

local function identity(source)
    local char = getCharacter(source)
    if not char then return nil end
    local charId = charValue(char, 'charIdentifier', charValue(char, 'charidentifier', nil))
    if not charId then return nil end
    local first = tostring(charValue(char, 'firstname', T('unknown')))
    local last = tostring(charValue(char, 'lastname', ''))
    local steamIdentifier = T('notAvailable')
    for _, identifier in ipairs(GetPlayerIdentifiers(source)) do
        if identifier:sub(1, 6) == 'steam:' then
            steamIdentifier = identifier
            break
        end
    end
    return {
        id = tostring(charId),
        name = (first .. ' ' .. last):gsub('%s+$', ''),
        steamName = GetPlayerName(source) or T('unknown'),
        steamIdentifier = steamIdentifier,
        job = tostring(charValue(char, 'job', 'unemployed')),
        jobGrade = tonumber(charValue(char, 'jobGrade', charValue(char, 'jobgrade', 0))) or 0,
        group = tostring(charValue(char, 'group', 'user')),
    }
end

local function nearBoard(source, board)
    local ped = GetPlayerPed(source)
    if not ped or ped == 0 then return false end
    local pos = GetEntityCoords(ped)
    local maxDistance = (Config.InteractDistance + 3.0) ^ 2
    for _, c in ipairs(boardLocations(board)) do
        local dx, dy, dz = pos.x - c.x, pos.y - c.y, pos.z - c.z
        if (dx * dx + dy * dy + dz * dz) <= maxDistance then return true end
    end
    return false
end

local function hasJob(player, board)
    if not board.jobs then return true end
    local grade = board.jobs[player.job]
    return grade ~= nil and player.jobGrade >= (tonumber(grade) or 0)
end

local function listContains(list, value)
    for _, entry in ipairs(list or {}) do
        if tostring(entry) == tostring(value) then return true end
    end
    return false
end

local function canPost(player, board)
    if not board.postGroups then return true end
    return listContains(board.postGroups, player.group)
end

local function discordModerator(source)
    local discord = Config.Permissions.discord
    if not discord or not discord.enabled or GetResourceState(discord.resource) ~= 'started' then return false end
    local ok, roles = pcall(function()
        return exports[discord.resource][discord.export](source)
    end)
    if not ok or type(roles) ~= 'table' then return false end
    for _, role in pairs(roles) do
        if discord.roleIds[tostring(role)] or listContains(discord.roleIds, role) then return true end
    end
    return false
end

local function isModerator(source, player)
    if Config.Permissions.ace ~= '' and IsPlayerAceAllowed(source, Config.Permissions.ace) then return true end
    if listContains(Config.Permissions.frameworkGroups, player.group) then return true end
    if Config.Permissions.jobs and Config.Permissions.jobs[player.job] ~= nil then
        return player.jobGrade >= (tonumber(Config.Permissions.jobs[player.job]) or 0)
    end
    return discordModerator(source)
end

local function cleanText(value, maxLength)
    value = tostring(value or ''):gsub('[%z\1-\8\11\12\14-\31]', '')
    value = value:gsub('^%s+', ''):gsub('%s+$', '')
    if #value > maxLength then value = value:sub(1, maxLength) end
    return value
end

local function validImageUrl(url)
    url = cleanText(url, Config.Validation.urlMax)
    if url == '' then return true, '' end
    local lower = url:lower()
    local scheme = Config.Validation.requireHttps and '^https://' or '^https?://'
    if not lower:match(scheme) or lower:find('[%s<>"]') then return false end
    for _, blocked in ipairs(Config.Validation.blacklistedUrlParts or {}) do
        if lower:find(tostring(blocked):lower(), 1, true) then return false end
    end
    local path = lower:match('^[^?#]+') or lower
    local allowed = false
    for _, extension in ipairs(Config.Validation.allowedExtensions or {}) do
        if path:sub(-#extension) == extension then allowed = true break end
    end
    return allowed, url
end

local function webhook(url, title, description, color, imageUrl, fields)
    if not Config.Discord.enabled or not url or url == '' then return end
    local embed = {
        title = title,
        description = description,
        color = color,
        fields = fields,
        footer = { text = os.date('!%Y-%m-%d %H:%M UTC') },
    }
    if imageUrl and imageUrl ~= '' then embed.image = { url = imageUrl } end
    PerformHttpRequest(url, function() end, 'POST', json.encode({
        username = Config.Discord.username,
        avatar_url = Config.Discord.avatarUrl,
        allowed_mentions = { parse = {} },
        embeds = { embed },
    }), { ['Content-Type'] = 'application/json' })
end

local function fetchPosts(boardId, viewerId, moderator)
    local now = os.time()
    local rows = MySQL.query.await([[
        SELECT id, board_id, owner_charid, owner_name, title, body, text_size, image_url, created_at, expires_at
        FROM pk_pinboard_posts
        WHERE board_id = ? AND expires_at > ?
        ORDER BY created_at DESC
    ]], { boardId, now }) or {}
    for _, row in ipairs(rows) do
        row.canDelete = moderator or tostring(row.owner_charid) == tostring(viewerId)
        row.owner_charid = nil
        if not Config.ShowAuthor then row.owner_name = nil end
    end
    return rows
end

local function sendBoard(source, board, player, moderator)
    local posts = fetchPosts(board.id, player.id, moderator)
    local mine = MySQL.scalar.await([[
        SELECT COUNT(*) FROM pk_pinboard_posts
        WHERE board_id = ? AND owner_charid = ? AND expires_at > ?
    ]], { board.id, player.id, os.time() }) or 0
    TriggerClientEvent('pk_pinboards:client:open', source, {
        board = { id = board.id, label = board.label or board.id },
        posts = posts,
        canModerate = moderator,
        canPost = canPost(player, board),
        limits = {
            boardCount = #posts,
            boardMax = tonumber(setting(board, 'maxPosts')) or 10,
            mine = tonumber(mine) or 0,
            mineMax = tonumber(setting(board, 'maxPostsPerPlayer')) or 2,
        },
    })
end

local function sendUpdate(source, board, player, moderator)
    local posts = fetchPosts(board.id, player.id, moderator)
    local mine = MySQL.scalar.await('SELECT COUNT(*) FROM pk_pinboard_posts WHERE board_id = ? AND owner_charid = ? AND expires_at > ?',
        { board.id, player.id, os.time() }) or 0
    TriggerClientEvent('pk_pinboards:client:update', source, {
        posts = posts,
        canPost = canPost(player, board),
        limits = { boardCount = #posts, boardMax = setting(board, 'maxPosts'), mine = mine, mineMax = setting(board, 'maxPostsPerPlayer') },
    })
end

local function reject(source, message)
    TriggerClientEvent('pk_pinboards:client:error', source, message)
end

RegisterNetEvent('pk_pinboards:server:open', function(boardId)
    local source = source
    local board = Boards[tostring(boardId)]
    local player = identity(source)
    if not board or not player then return end
    if not nearBoard(source, board) then return reject(source, T('tooFar')) end
    if not hasJob(player, board) then return reject(source, T('noAccess')) end
    sendBoard(source, board, player, isModerator(source, player))
end)

RegisterNetEvent('pk_pinboards:server:create', function(boardId, data)
    local source = source
    local board = Boards[tostring(boardId)]
    local player = identity(source)
    if not board or not player or type(data) ~= 'table' then return end
    if not nearBoard(source, board) then return reject(source, T('tooFar')) end
    if not hasJob(player, board) then return reject(source, T('noAccess')) end
    if not canPost(player, board) then return reject(source, T('postDenied')) end

    local title = cleanText(data.title, Config.Validation.titleMax)
    local body = cleanText(data.body, Config.Validation.bodyMax)
    local textSize = tostring(data.textSize or 'normal'):lower()
    if not Config.Validation.textSizes[textSize] then textSize = 'normal' end
    local urlOk, imageUrl = validImageUrl(data.imageUrl)
    if title == '' or body == '' then return reject(source, T('invalidPost')) end
    if not urlOk then return reject(source, T('invalidUrl')) end

    local now = os.time()
    local boardCount = tonumber(MySQL.scalar.await('SELECT COUNT(*) FROM pk_pinboard_posts WHERE board_id = ? AND expires_at > ?', { board.id, now })) or 0
    if boardCount >= (tonumber(setting(board, 'maxPosts')) or 10) then return reject(source, T('boardFull')) end
    local playerCount = tonumber(MySQL.scalar.await('SELECT COUNT(*) FROM pk_pinboard_posts WHERE board_id = ? AND owner_charid = ? AND expires_at > ?', { board.id, player.id, now })) or 0
    if playerCount >= (tonumber(setting(board, 'maxPostsPerPlayer')) or 2) then return reject(source, T('playerLimit')) end

    local expires = now + math.floor((tonumber(setting(board, 'postDurationHours')) or 168) * 3600)
    MySQL.insert.await([[
        INSERT INTO pk_pinboard_posts (board_id, owner_charid, owner_name, title, body, text_size, image_url, created_at, expires_at)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
    ]], { board.id, player.id, player.name, title, body, textSize, imageUrl, now, expires })

    local locationWebhook = board.webhook
    if not locationWebhook or locationWebhook == '' then locationWebhook = Config.Discord.defaultWebhook end
    local staffUrl = Config.Discord.globalWebhook or Config.Discord.staffWebhook
    if not staffUrl or staffUrl == '' then staffUrl = Config.Discord.defaultWebhook end
    local log = T('log')
    if locationWebhook and locationWebhook ~= '' and locationWebhook ~= staffUrl then
        webhook(locationWebhook, log.newPost, ('**%s**\n%s'):format(title, body), 11176232, imageUrl, {
            { name = log.board, value = board.label or board.id, inline = true },
        })
    end
    webhook(staffUrl, log.newPostStaff, ('**%s**\n%s'):format(title, body), 11176232, imageUrl, {
        { name = log.board, value = board.label or board.id, inline = true },
        { name = log.character, value = player.name, inline = true },
        { name = log.steamName, value = player.steamName, inline = true },
        { name = log.steamId, value = player.steamIdentifier, inline = false },
        { name = log.charId, value = player.id, inline = true },
    })
    TriggerClientEvent('pk_pinboards:client:notice', source, T('created'))
    sendUpdate(source, board, player, isModerator(source, player))
end)

RegisterNetEvent('pk_pinboards:server:delete', function(boardId, postId)
    local source = source
    local board = Boards[tostring(boardId)]
    local player = identity(source)
    postId = tonumber(postId)
    if not board or not player or not postId then return end
    if not nearBoard(source, board) then return reject(source, T('tooFar')) end
    if not hasJob(player, board) then return reject(source, T('noAccess')) end

    local post = MySQL.single.await('SELECT * FROM pk_pinboard_posts WHERE id = ? AND board_id = ?', { postId, board.id })
    local moderator = isModerator(source, player)
    if not post or (tostring(post.owner_charid) ~= player.id and not moderator) then return reject(source, T('denied')) end
    MySQL.update.await('DELETE FROM pk_pinboard_posts WHERE id = ? AND board_id = ?', { postId, board.id })
    local deleteWebhook = Config.Discord.deleteWebhook
    if not deleteWebhook or deleteWebhook == '' then deleteWebhook = Config.Discord.globalWebhook or Config.Discord.staffWebhook end
    if not deleteWebhook or deleteWebhook == '' then deleteWebhook = Config.Discord.defaultWebhook end
    local log = T('log')
    webhook(deleteWebhook,
        log.removedStaff, ('**%s**'):format(post.title), 12386304, post.image_url, {
            { name = log.board, value = board.label or board.id, inline = true },
            { name = log.author, value = post.owner_name, inline = true },
            { name = log.removedBy, value = player.name, inline = true },
            { name = log.steamName, value = player.steamName, inline = true },
            { name = log.steamId, value = player.steamIdentifier, inline = false },
        })
    TriggerClientEvent('pk_pinboards:client:notice', source, T('deleted'))
    sendUpdate(source, board, player, moderator)
end)

MySQL.ready(function()
    MySQL.query.await([[
        CREATE TABLE IF NOT EXISTS `pk_pinboard_posts` (
            `id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
            `board_id` VARCHAR(64) NOT NULL,
            `owner_charid` VARCHAR(64) NOT NULL,
            `owner_name` VARCHAR(100) NOT NULL,
            `title` VARCHAR(64) NOT NULL,
            `body` VARCHAR(500) NOT NULL,
            `text_size` VARCHAR(10) NOT NULL DEFAULT 'normal',
            `image_url` VARCHAR(500) NOT NULL DEFAULT '',
            `created_at` BIGINT UNSIGNED NOT NULL,
            `expires_at` BIGINT UNSIGNED NOT NULL,
            PRIMARY KEY (`id`),
            KEY `idx_board_expiry` (`board_id`, `expires_at`),
            KEY `idx_owner_board` (`owner_charid`, `board_id`, `expires_at`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
    ]])
    local textSizeColumn = MySQL.single.await("SHOW COLUMNS FROM `pk_pinboard_posts` LIKE 'text_size'")
    if not textSizeColumn then
        MySQL.query.await("ALTER TABLE `pk_pinboard_posts` ADD COLUMN `text_size` VARCHAR(10) NOT NULL DEFAULT 'normal' AFTER `body`")
    end
    MySQL.update.await('DELETE FROM pk_pinboard_posts WHERE expires_at <= ?', { os.time() })
    print(('[pk_pinboards] Pronte %d bacheche.'):format(#Config.Boards))
end)

CreateThread(function()
    local interval = math.max(1, tonumber(Config.SaveIntervalMinutes) or 10) * 60000
    while true do
        Wait(interval)
        MySQL.update.await('DELETE FROM pk_pinboard_posts WHERE expires_at <= ?', { os.time() })
    end
end)
