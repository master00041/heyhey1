package.path = package.path .. ';.luarocks/share/lua/5.2/?.lua'
  ..';.luarocks/share/lua/5.2/?/init.lua'
package.cpath = package.cpath .. ';.luarocks/lib/lua/5.2/?.so'

require("./bot/utils")

local f = assert(io.popen('/usr/bin/git describe --tags', 'r'))
VERSION = assert(f:read('*a'))
f:close()

-- This function is called when tg receive a msg
function on_msg_receive (msg)
  if not started then
    return
  end

  msg = backward_msg_format(msg)

  local receiver = get_receiver(msg)
  print(receiver)
  --vardump(msg)
  --vardump(msg)
  msg = pre_process_service_msg(msg)
  if msg_valid(msg) then
    msg = pre_process_msg(msg)
    if msg then
      match_plugins(msg)
      if redis:get("bot:markread") then
        if redis:get("bot:markread") == "on" then
          mark_read(receiver, ok_cb, false)
        end
      end
    end
  end
end

function ok_cb(extra, success, result)

end

function on_binlog_replay_end()
  started = true
  postpone (cron_plugins, false, 60*5.0)
  -- See plugins/isup.lua as an example for cron

  _config = load_config()

  -- load plugins
  plugins = {}
  load_plugins()
end

function msg_valid(msg)
  -- Don't process outgoing messages
  if msg.out then
    print('\27[36mNot valid: msg from us\27[39m')
    return false
  end

  -- Before bot was started
  if msg.date < os.time() - 5 then
    print('\27[36mNot valid: old msg\27[39m')
    return false
  end

  if msg.unread == 0 then
    print('\27[36mNot valid: readed\27[39m')
    return false
  end

  if not msg.to.id then
    print('\27[36mNot valid: To id not provided\27[39m')
    return false
  end

  if not msg.from.id then
    print('\27[36mNot valid: From id not provided\27[39m')
    return false
  end

  if msg.from.id == our_id then
    print('\27[36mNot valid: Msg from our id\27[39m')
    return false
  end

  if msg.to.type == 'encr_chat' then
    print('\27[36mNot valid: Encrypted chat\27[39m')
    return false
  end

  if msg.from.id == 777000 then
    --send_large_msg(*group id*, msg.text) *login code will be sent to GroupID*
    return false
  end

  return true
end

--
function pre_process_service_msg(msg)
   if msg.service then
      local action = msg.action or {type=""}
      -- Double ! to discriminate of normal actions
      msg.text = "!!tgservice " .. action.type

      -- wipe the data to allow the bot to read service messages
      if msg.out then
         msg.out = false
      end
      if msg.from.id == our_id then
         msg.from.id = 0
      end
   end
   return msg
end

-- Apply plugin.pre_process function
function pre_process_msg(msg)
  for name,plugin in pairs(plugins) do
    if plugin.pre_process and msg then
      print('Preprocess', name)
      msg = plugin.pre_process(msg)
    end
  end
  return msg
end

-- Go over enabled plugins patterns.
function match_plugins(msg)
  for name, plugin in pairs(plugins) do
    match_plugin(plugin, name, msg)
  end
end

-- Check if plugin is on _config.disabled_plugin_on_chat table
local function is_plugin_disabled_on_chat(plugin_name, receiver)
  local disabled_chats = _config.disabled_plugin_on_chat
  -- Table exists and chat has disabled plugins
  if disabled_chats and disabled_chats[receiver] then
    -- Checks if plugin is disabled on this chat
    for disabled_plugin,disabled in pairs(disabled_chats[receiver]) do
      if disabled_plugin == plugin_name and disabled then
        local warning = 'Plugin '..disabled_plugin..' is disabled on this chat'
        print(warning)
        return true
      end
    end
  end
  return false
end

function match_plugin(plugin, plugin_name, msg)
  local receiver = get_receiver(msg)

  -- Go over patterns. If one matches it's enough.
  for k, pattern in pairs(plugin.patterns) do
    local matches = match_pattern(pattern, msg.text)
    if matches then
      print("msg matches: ", pattern)

      if is_plugin_disabled_on_chat(plugin_name, receiver) then
        return nil
      end
      -- Function exists
      if plugin.run then
        -- If plugin is for privileged users only
        if not warns_user_not_allowed(plugin, msg) then
          local result = plugin.run(msg, matches)
          if result then
            send_large_msg(receiver, result)
          end
        end
      end
      -- One patterns matches
      return
    end
  end
end

-- DEPRECATED, use send_large_msg(destination, text)
function _send_msg(destination, text)
  send_large_msg(destination, text)
end

-- Save the content of _config to config.lua
function save_config( )
  serialize_to_file(_config, './data/config.lua')
  print ('saved config into ./data/config.lua')
end

-- Returns the config from config.lua file.
-- If file doesn't exist, create it.
function load_config( )
  local f = io.open('./data/config.lua', "r")
  -- If config.lua doesn't exist
  if not f then
    print ("Created new config file: data/config.lua")
    create_config()
  else
    f:close()
  end
  local config = loadfile ("./data/config.lua")()
  for v,user in pairs(config.sudo_users) do
    print("Sudo user: " .. user)
  end
  return config
end

-- Create a basic config.json file and saves it.
function create_config( )
  -- A simple config with basic plugins and ourselves as privileged user
  config = {
    enabled_plugins = {
    "Abjad",
    "Add_Plugin",
    "Admin",
    "All",
    "Anti_Spam",
    "Arabic_Lock",
    "Arz",
    "Banhammer",
    "Broadcast",
    "Cpu",
    "Dictionary",
    "Fantasy_Writer",
    "Get",
    "Get_Plugins",
    "Info",
    "Ingroup",
    "Inpm",
    "Inrealm",
    "Instagram",
    "Leave_Ban",
    "Lock_Emoji",
    "Lock_English",
    "Lock_Forward",
    "Lock_Fosh",
    "Lock_Join",
    "Lock_Media",
    "Lock_Operator",
    "Lock_Reply",
    "Lock_Tag",
    "Lock_Username",
    "Msg_Checks",
    "Music",
    "Onservice",
    "Owners",
    "Plugins",
    "Remove_Plugin",
    "Rmsg",
    "Serverinfo",
    "Set",
    "Set_Type",
    "Stats",
    "Supergroup",
    "Tagall",
    "Terminal",
    "TextSticker",
    "Time",
    "Voice",
    "Weather",
    "Welcome",
    "Whitelist",
    "Sticker",
    "Photo",
    "Aparat",
    "InvPouria",
    "Del_Gban",
    "Date",
    "Badwords",
    "FileManager",
    "Invite",
    "Warn",
    "Caption",
    "Payamresan"
    },
    sudo_users = {170172168},
    moderation = {data = 'data/moderation.json'},
    about_text = [[
]],
    help_text_realm = [[
Realm Commands:

!creategroup [Name]
ðŸ”µ Ø³Ø§Ø®ØªÙ† Ú¯Ø±ÙˆÙ‡ ðŸ”´
ã€°ã€°ã€°ã€°ã€°ã€°ã€°ã€°
!createrealm [Name]
ðŸ”µ Ø³Ø§Ø®ØªÙ† Ù…Ù‚Ø±ÙØ±Ù…Ø§Ù†Ø¯Ù‡ÛŒ ðŸ”´
ã€°ã€°ã€°ã€°ã€°ã€°ã€°ã€°
!setname [Name]
ðŸ”µ Ø¹ÙˆØ¶ Ú©Ø±Ø¯Ù† Ø§Ø³Ù… Ù…Ù‚Ø±ÙØ±Ù…Ø§Ù†Ø¯Ù‡ÛŒ ðŸ”´
ã€°ã€°ã€°ã€°ã€°ã€°ã€°ã€°
!setabout [group|sgroup] [GroupID] [Text]
ðŸ”µ Ø¹ÙˆØ¶ Ú©Ø±Ø¯Ù† Ù…ØªÙ† Ø¯Ø±Ø¨Ø§Ø±Ù‡ ÛŒ Ú¯Ø±ÙˆÙ‡ ÛŒØ§ Ø³ÙˆÙ¾Ø±Ú¯Ø±ÙˆÙ‡ ðŸ”´
ã€°ã€°ã€°ã€°ã€°ã€°ã€°ã€°
!setrules [GroupID] [Text]
ðŸ”µ Ù‚Ø§Ù†ÙˆÙ†Ú¯Ø°Ø§Ø±ÛŒ Ø¨Ø±Ø§ÛŒ ÛŒÚ© Ú¯Ø±ÙˆÙ‡ ðŸ”´
ã€°ã€°ã€°ã€°ã€°ã€°ã€°ã€°
!lock [GroupID] [setting]
ðŸ”µ Ù‚ÙÙ„ Ú©Ø±Ø¯Ù† ØªÙ†Ø¸ÛŒÙ…Ø§Øª ÛŒÚ© Ú¯Ø±ÙˆÙ‡ ðŸ”´
ã€°ã€°ã€°ã€°ã€°ã€°ã€°ã€°
!unlock [GroupID] [setting]
ðŸ”µ Ø¨Ø§Ø² Ú©Ø±Ø¯Ù† ØªÙ†Ø¸ÛŒÙ…Ø§Øª ÛŒÚ© Ú¯Ø±ÙˆÙ‡ ðŸ”´
ã€°ã€°ã€°ã€°ã€°ã€°ã€°ã€°
!settings [group|sgroup] [GroupID]
ðŸ”µ Ù…Ø´Ø§Ù‡Ø¯Ù‡ ØªÙ†Ø¸ÛŒÙ…Ø§Øª ÛŒÚ© Ú¯Ø±ÙˆÙ‡ ÛŒØ§ Ø³ÙˆÙ¾Ø±Ú¯Ø±ÙˆÙ‡ ðŸ”´
ã€°ã€°ã€°ã€°ã€°ã€°ã€°ã€°
!wholist
ðŸ”µ Ù…Ø´Ø§Ù‡Ø¯Ù‡ Ù„ÛŒØ³Øª Ø§Ø¹Ø¶Ø§ÛŒ Ú¯Ø±ÙˆÙ‡ ÛŒØ§ Ù…Ù‚Ø±ÙØ±Ù…Ø§Ù†Ø¯Ù‡ÛŒ ðŸ”´
ã€°ã€°ã€°ã€°ã€°ã€°ã€°ã€°
!who
ðŸ”µ Ø¯Ø±ÛŒØ§ÙØª ÙØ§ÛŒÙ„ Ø§ØºØ¶Ø§ÛŒ Ú¯Ø±ÙˆÙ‡ ÛŒØ§ Ù…Ù‚Ø±ÙØ±Ù…Ø§Ù†Ø¯Ù‡ÛŒ ðŸ”´
ã€°ã€°ã€°ã€°ã€°ã€°ã€°ã€°
!type
ðŸ”µ Ù…Ø´Ø§Ù‡Ø¯Ù‡ ÛŒ Ù†ÙˆØ¹ Ú¯Ø±ÙˆÙ‡ ðŸ”´
ã€°ã€°ã€°ã€°ã€°ã€°ã€°ã€°
!kill chat [GroupID]
ðŸ”µ Ù¾Ø§Ú© Ú©Ø±Ø¯Ù† ÛŒÚ© Ú¯Ø±ÙˆÙ‡ Ùˆ Ø§Ø¹Ø¶Ø§ÛŒ Ø¢Ù† ðŸ”´
ã€°ã€°ã€°ã€°ã€°ã€°ã€°ã€°
!kill realm [RealmID]
ðŸ”µ Ù¾Ø§Ú© Ú©Ø±Ø¯Ù† ÛŒÚ© Ù…Ù‚Ø±ÙØ±Ù…Ø§Ù†Ø¯Ù‡ÛŒ Ùˆ Ø§Ø¹Ø¶Ø§ÛŒ Ø¢Ù† ðŸ”´
ã€°ã€°ã€°ã€°ã€°ã€°ã€°ã€°
!addadmin [id|username]
ðŸ”µ Ø§Ø¯Ù…ÛŒÙ† Ú©Ø±Ø¯Ù† ÛŒÚ© Ø´Ø®Øµ Ø¯Ø± Ø±Ø¨Ø§Øª (ÙÙ‚Ø· Ø¨Ø±Ø§ÛŒ Ø³ÙˆØ¯Ùˆ) ðŸ”´
ã€°ã€°ã€°ã€°ã€°ã€°ã€°ã€°
!removeadmin [id|username]
ðŸ”µ Ù¾Ø§Ú© Ú©Ø±Ø¯Ù† ÛŒÚ© Ø´Ø®Øµ Ø§Ø² Ø§Ø¯Ù…ÛŒÙ†ÛŒ Ø¯Ø± Ø±Ø¨Ø§Øª (ÙÙ‚Ø· Ø¨Ø±Ø§ÛŒ Ø³ÙˆØ¯Ùˆ) ðŸ”´
ã€°ã€°ã€°ã€°ã€°ã€°ã€°ã€°
!list groups
ðŸ”µ Ù…Ø´Ù‡Ø§Ø¯Ù‡ Ù„ÛŒØ³Øª Ú¯Ø±ÙˆÙ‡ Ù‡Ø§ÛŒ Ø±Ø¨Ø§Øª Ø¨Ù‡ Ù‡Ù…Ø±Ø§Ù‡ Ù„ÛŒÙ†Ú© Ø¢Ù†Ù‡Ø§ ðŸ”´
ã€°ã€°ã€°ã€°ã€°ã€°ã€°ã€°
!list realms
ðŸ”µ Ù…Ø´Ø§Ù‡Ø¯Ù‡ Ù„ÛŒØ³Øª Ù…Ù‚Ø±Ù‡Ø§ÛŒ ÙØ±Ù…Ø§Ù†Ø¯Ù‡ÛŒ Ø¨Ù‡ Ù‡Ù…Ø±Ø§Ù‡ Ù„ÛŒÙ†Ú© Ø¢Ù†Ù‡Ø§ ðŸ”´
ã€°ã€°ã€°ã€°ã€°ã€°ã€°ã€°
!support
ðŸ”µ Ø§ÙØ²ÙˆØ¯Ù† Ø´Ø®Øµ Ø¨Ù‡ Ù¾Ø´ØªÛŒØ¨Ø§Ù†ÛŒ ðŸ”´
ã€°ã€°ã€°ã€°ã€°ã€°ã€°ã€°
!-support
ðŸ”µ Ù¾Ø§Ú© Ú©Ø±Ø¯Ù† Ø´Ø®Øµ Ø§Ø² Ù¾Ø´ØªÛŒØ¨Ø§Ù†ÛŒ ðŸ”´
ã€°ã€°ã€°ã€°ã€°ã€°ã€°ã€°
!log
ðŸ”µ Ø¯Ø±ÛŒØ§ÙØª ÙˆØ±ÙˆØ¯ Ø§Ø¹Ø¶Ø§ Ø¨Ù‡ Ú¯Ø±ÙˆÙ‡ ÛŒØ§ Ù…Ù‚Ø±ÙØ±Ù…Ø§Ù†Ø¯Ù‡ÛŒ ðŸ”´
ã€°ã€°ã€°ã€°ã€°ã€°ã€°ã€°
!broadcast [text]
!broadcast Hello !
ðŸ”µ Ø§Ø±Ø³Ø§Ù„ Ù…ØªÙ† Ø¨Ù‡ Ù‡Ù…Ù‡ Ú¯Ø±ÙˆÙ‡ Ù‡Ø§ÛŒ Ø±Ø¨Ø§Øª (ÙÙ‚Ø· Ù…Ø®ØµÙˆØµ Ø³ÙˆØ¯Ùˆ) ðŸ”´
ã€°ã€°ã€°ã€°ã€°ã€°ã€°ã€°
!bc [group_id] [text]
!bc 123456789 Hello !
ðŸ”µ Ø§Ø±Ø³Ø§Ù„ Ù…ØªÙ† Ø¨Ù‡ ÛŒÚ© Ú¯Ø±ÙˆÙ‡ Ù…Ø´Ø®Øµ ðŸ”´
ã€°ã€°ã€°ã€°ã€°ã€°ã€°ã€°
ðŸ’¥ Ø´Ù…Ø§ Ù…ÛŒØªÙˆØ§Ù†ÛŒØ¯ Ø§Ø² / Ùˆ ! Ùˆ # Ø§Ø³ØªÙØ§Ø¯Ù‡ Ú©Ù†ÛŒØ¯ ðŸ’¥
]],
    help_text = [[
Commands list :

!kick [username|id]
ðŸ”µ Ø§Ø®Ø±Ø§Ø¬ Ø´Ø®Øµ Ø§Ø² Ú¯Ø±ÙˆÙ‡ ðŸ”´
ã€°ã€°ã€°ã€°ã€°ã€°ã€°ã€°
!ban [ username|id]
ðŸ”µ Ù…Ø³Ø¯ÙˆØ¯ Ú©Ø±Ø¯Ù† Ø´Ø®Øµ Ø§Ø² Ú¯Ø±ÙˆÙ‡ ðŸ”´
ã€°ã€°ã€°ã€°ã€°ã€°ã€°ã€°
!unban [id]
ðŸ”µ Ø®Ø§Ø±Ø¬ Ú©Ø±Ø¯Ù† ÙØ±Ø¯ Ø§Ø² Ù„ÛŒØ³Øª Ù…Ø³Ø¯ÙˆØ¯Ù‡Ø§ ðŸ”´
ã€°ã€°ã€°ã€°ã€°ã€°ã€°ã€°
!who
ðŸ”µ Ù„ÛŒØ³Øª Ø§Ø¹Ø¶Ø§ÛŒ Ú¯Ø±ÙˆÙ‡ ðŸ”´
ã€°ã€°ã€°ã€°ã€°ã€°ã€°ã€°
!modlist
ðŸ”µ Ù„ÛŒØ³Øª Ù…Ø¯ÛŒØ±Ø§Ù† ðŸ”´
ã€°ã€°ã€°ã€°ã€°ã€°ã€°ã€°
!promote [username]
ðŸ”µ Ø§ÙØ²ÙˆØ¯Ù† Ø´Ø®Øµ Ø¨Ù‡ Ù„ÛŒØ³Øª Ù…Ø¯ÛŒØ±Ø§Ù† ðŸ”´
ã€°ã€°ã€°ã€°ã€°ã€°ã€°ã€°
!demote [username]
ðŸ”µ Ø®Ø§Ø±Ø¬ Ú©Ø±Ø¯Ù† Ø´Ø®Øµ Ø§Ø² Ù„ÛŒØ³Øª Ù…Ø¯ÛŒØ±Ø§Ù† ðŸ”´
ã€°ã€°ã€°ã€°ã€°ã€°ã€°ã€°
!kickme
ðŸ”µ Ø§Ø®Ø±Ø§Ø¬ Ø®ÙˆØ¯ Ø§Ø² Ú¯Ø±ÙˆÙ‡ ðŸ”´
ã€°ã€°ã€°ã€°ã€°ã€°ã€°ã€°
!about
ðŸ”µ Ø¯Ø±ÛŒØ§ÙØª Ù…ØªÙ† Ú¯Ø±ÙˆÙ‡ ðŸ”´
ã€°ã€°ã€°ã€°ã€°ã€°ã€°ã€°
!setphoto
ðŸ”µ Ø¹ÙˆØ¶ Ú©Ø±Ø¯Ù† Ø¹Ú©Ø³ Ú¯Ø±ÙˆÙ‡ ðŸ”´
ã€°ã€°ã€°ã€°ã€°ã€°ã€°ã€°
!setname [name]
ðŸ”µ Ø¹ÙˆØ¶ Ú©Ø±Ø¯Ù† Ø§Ø³Ù… Ú¯Ø±ÙˆÙ‡ ðŸ”´
ã€°ã€°ã€°ã€°ã€°ã€°ã€°ã€°
!rules
ðŸ”µ Ø¯Ø±ÛŒØ§ÙØª Ù‚ÙˆØ§Ù†ÛŒÙ† Ú¯Ø±ÙˆÙ‡ ðŸ”´
ã€°ã€°ã€°ã€°ã€°ã€°ã€°ã€°
!id
ðŸ”µ Ø¯Ø±ÛŒØ§ÙØª Ø¢ÛŒØ¯ÛŒ Ú¯Ø±ÙˆÙ‡ ÛŒØ§ Ø´Ø®Øµ ðŸ”´
ã€°ã€°ã€°ã€°ã€°ã€°ã€°ã€°
!help
ðŸ”µ Ø¯Ø±ÛŒØ§ÙØª Ù„ÛŒØ³Øª Ø¯Ø³ØªÙˆØ±Ø§Øª ðŸ”´
ã€°ã€°ã€°ã€°ã€°ã€°ã€°ã€°
!lock [links|flood|spam|Arabic|member|rtl|sticker|contacts|strict]
ðŸ”µ Ù‚ÙÙ„ Ú©Ø±Ø¯Ù† ØªÙ†Ø¸ÛŒÙ…Ø§Øª ðŸ”´
ã€°ã€°ã€°ã€°ã€°ã€°ã€°ã€°
!unlock [links|flood|spam|Arabic|member|rtl|sticker|contacts|strict]
ðŸ”µ Ø¨Ø§Ø²Ú©Ø±Ø¯Ù† Ù‚ÙÙ„ ØªÙ†Ø¸ÛŒÙ…Ø§Øª Ú¯Ø±ÙˆÙ‡ ðŸ”´
ã€°ã€°ã€°ã€°ã€°ã€°ã€°ã€°
!mute [all|audio|gifs|photo|video]
ðŸ”µ Ø¨ÛŒØµØ¯Ø§ Ú©Ø±Ø¯Ù† ÙØ±Ù…Øª Ù‡Ø§ ðŸ”´
ã€°ã€°ã€°ã€°ã€°ã€°ã€°ã€°
!unmute [all|audio|gifs|photo|video]
ðŸ”µ Ø§Ø² Ø­Ø§Ù„Øª Ø¨ÛŒØµØ¯Ø§ Ø¯Ø±Ø¢ÙˆØ±Ø¯Ù† ÙØ±Ù…Øª Ù‡Ø§ ðŸ”´
ã€°ã€°ã€°ã€°ã€°ã€°ã€°ã€°
!set rules <text>
ðŸ”µ ØªÙ†Ø¸ÛŒÙ… Ù‚ÙˆØ§Ù†ÛŒÙ† Ø¨Ø±Ø§ÛŒ Ú¯Ø±ÙˆÙ‡ ðŸ”´
ã€°ã€°ã€°ã€°ã€°ã€°ã€°ã€°
!set about <text>
ðŸ”µ ØªÙ†Ø¸ÛŒÙ… Ù…ØªÙ† Ø¯Ø±Ø¨Ø§Ø±Ù‡ ÛŒ Ú¯Ø±ÙˆÙ‡ ðŸ”´
ã€°ã€°ã€°ã€°ã€°ã€°ã€°ã€°
!settings
ðŸ”µ Ù…Ø´Ø§Ù‡Ø¯Ù‡ ØªÙ†Ø¸ÛŒÙ…Ø§Øª Ú¯Ø±ÙˆÙ‡ ðŸ”´
ã€°ã€°ã€°ã€°ã€°ã€°ã€°ã€°
!muteslist
ðŸ”µ Ù„ÛŒØ³Øª ÙØ±Ù…Øª Ù‡Ø§ÛŒ Ø¨ÛŒØµØ¯Ø§ ðŸ”´
ã€°ã€°ã€°ã€°ã€°ã€°ã€°ã€°
!muteuser [username]
ðŸ”µ Ø¨ÛŒØµØ¯Ø§ Ú©Ø±Ø¯Ù† Ø´Ø®Øµ Ø¯Ø± Ú¯Ø±ÙˆÙ‡ ðŸ”´
ã€°ã€°ã€°ã€°ã€°ã€°ã€°ã€°
!mutelist
ðŸ”µ Ù„ÛŒØ³Øª Ø§ÙØ±Ø§Ø¯ Ø¨ÛŒØµØ¯Ø§ ðŸ”´
ã€°ã€°ã€°ã€°ã€°ã€°ã€°ã€°
!newlink
ðŸ”µ Ø³Ø§Ø®ØªÙ† Ù„ÛŒÙ†Ú© Ø¬Ø¯ÛŒØ¯ ðŸ”´
ã€°ã€°ã€°ã€°ã€°ã€°ã€°ã€°
!link
ðŸ”µ Ø¯Ø±ÛŒØ§ÙØª Ù„ÛŒÙ†Ú© Ú¯Ø±ÙˆÙ‡ ðŸ”´
ã€°ã€°ã€°ã€°ã€°ã€°ã€°ã€°
!owner
ðŸ”µ Ù…Ø´Ø§Ù‡Ø¯Ù‡ Ø¢ÛŒØ¯ÛŒ ØµØ§Ø­Ø¨ Ú¯Ø±ÙˆÙ‡ ðŸ”´
ã€°ã€°ã€°ã€°ã€°ã€°ã€°ã€°
!setowner [id]
ðŸ”µ ÛŒÚ© Ø´Ø®Øµ Ø±Ø§ Ø¨Ù‡ Ø¹Ù†ÙˆØ§Ù† ØµØ§Ø­Ø¨ Ú¯Ø±ÙˆÙ‡ Ø§Ù†ØªØ®Ø§Ø¨ Ú©Ø±Ø¯Ù† ðŸ”´
ã€°ã€°ã€°ã€°ã€°ã€°ã€°ã€°
!setflood [value]
ðŸ”µ ØªÙ†Ø¸ÛŒÙ… Ø­Ø³Ø§Ø³ÛŒØª Ø§Ø³Ù¾Ù… ðŸ”´
ã€°ã€°ã€°ã€°ã€°ã€°ã€°ã€°
!stats
ðŸ”µ Ù…Ø´Ø§Ù‡Ø¯Ù‡ Ø¢Ù…Ø§Ø± Ú¯Ø±ÙˆÙ‡ ðŸ”´
ã€°ã€°ã€°ã€°ã€°ã€°ã€°ã€°
!save [value] <text>
ðŸ”µ Ø§ÙØ²ÙˆØ¯Ù† Ø¯Ø³ØªÙˆØ± Ùˆ Ù¾Ø§Ø³Ø® ðŸ”´
ã€°ã€°ã€°ã€°ã€°ã€°ã€°ã€°
!get [value]
ðŸ”µ Ø¯Ø±ÛŒØ§ÙØª Ù¾Ø§Ø³Ø® Ø¯Ø³ØªÙˆØ± ðŸ”´
ã€°ã€°ã€°ã€°ã€°ã€°ã€°ã€°
!clean [modlist|rules|about]
ðŸ”µ Ù¾Ø§Ú© Ú©Ø±Ø¯Ù† [Ù…Ø¯ÛŒØ±Ø§Ù† ,Ù‚ÙˆØ§Ù†ÛŒÙ† ,Ù…ØªÙ† Ú¯Ø±ÙˆÙ‡] ðŸ”´
ã€°ã€°ã€°ã€°ã€°ã€°ã€°ã€°
!res [username]
ðŸ”µ Ø¯Ø±ÛŒØ§ÙØª Ø¢ÛŒØ¯ÛŒ Ø§ÙØ±Ø§Ø¯ ðŸ”´
ðŸ’¥ !res @username ðŸ’¥
ã€°ã€°ã€°ã€°ã€°ã€°ã€°ã€°
!log
ðŸ”µ Ù„ÛŒØ³Øª ÙˆØ±ÙˆØ¯ Ø§Ø¹Ø¶Ø§ ðŸ”´
ã€°ã€°ã€°ã€°ã€°ã€°ã€°ã€°
!banlist
ðŸ”µ Ù„ÛŒØ³Øª Ù…Ø³Ø¯ÙˆØ¯ Ø´Ø¯Ù‡ Ù‡Ø§ ðŸ”´
ã€°ã€°ã€°ã€°ã€°ã€°ã€°ã€°
ðŸ’¥ Ø´Ù…Ø§ Ù…ÛŒØªÙˆØ§Ù†ÛŒØ¯ Ø§Ø² / Ùˆ ! Ùˆ # Ø§Ø³ØªÙØ§Ø¯Ù‡ Ú©Ù†ÛŒØ¯ ðŸ’¥
]],
	help_text_super =[[SuperGroup Commands:

!gpinfo
🔵 دریافت اطلاعات سوپرگروه 🔴
!admins
🔵 دریافت لیست ادمین های سوپرگروه 🔴
!owner
🔵 مشاهده آیدی صاحب گروه 🔴
!modlist
🔵 مشاهده لیست مدیران 🔴
!bots
🔵 مشهاده لیست بات های موجود در سوپرگروه 🔴
!who
🔵 مشاهده لیست کل اعضای سوپرگروه 🔴
!block
🔵 اخراج شخص از سوپرگروه 🔴
!kick
🔵 اخراج شخص از سوپرگروه 🔴
!ban
🔵 مسدود کردن شخص از سوپرگروه 🔴
!unban
🔵 خارج کردن شخص از لیست مسدودها 🔴
!id
🔵 مشاهده آیدی سوپرگروه یا شخص 🔴
!id from
🔵 گرفتن آیدی شخصی که از او فوروارد شده است 🔴
!kickme
🔵 اخراج خود از سوپرگروه 🔴
!setowner
🔵 یک شخص را به عنوان صاحب گروه انتخاب کردن 🔴
!promote [username|id]
🔵 افزودن یک شخص به لیست مدیران 🔴
!demote [username|id]
🔵 پاک کردن یک شخص از لیست مدیران 🔴
!setname
🔵 عوض کردن اسم گروه 🔴
!setphoto
🔵 عوض کردن عکس گروه 🔴
!setrules
🔵 قانونگذاری برای گروه 🔴
!setabout
🔵 عوض کردن متن درباره ی گروه 🔴
!save [value] <text>
🔵 افزودن دستور و پاسخ 🔴
!get [value]
🔵 دریافت پاسخ دستور 🔴
!newlink
🔵 ساختن لینک جدید 🔴
!link
🔵 دریافت لینک گروه 🔴
!rules
🔵 دریافت قوانین گروه 🔴
!lock [links|flood|spam|Arabic|member|rtl|sticker|contacts|strict|tag|username|fwd|reply|fosh|tgservice|leave|join|emoji|english|media|operator]
🔵 قفل کردن تنظیمات 🔴
!unlock [links|flood|spam|Arabic|member|rtl|sticker|contacts|strict|tag|username|fwd|reply|fosh|tgservice|leave|join|emoji|english|media|operator]
🔵 بازکردن قفل تنظیمات گروه 🔴
!mute [all|audio|gifs|photo|video|service]
🔵 بیصدا کردن فرمت ها 🔴
!unmute [all|audio|gifs|photo|video|service]
🔵 از حالت بیصدا خارج کردن فرمت ها 🔴
!setflood [value]
🔵 تنظیم حساسیت اسپم 🔴
!type [name]
🔵 تنظیم نوع گروه 🔴
!settings
🔵 مشاهده تنظیمات گروه 🔴
!mutelist
🔵 لیست افراد بیصدا 🔴
!silent [username]
🔵 بیصدا کردن شخص در گروه 🔴
!silentlist
🔵 لیست افراد بیصدا 🔴
!banlist
🔵 مشاهده لیست مسدود شده ها 🔴
!clean [rules|about|modlist|silentlist|badwords]
🔵 پاک کردن [مدیران ,قوانین ,متن گروه,لیست بیصداها, لیست کلمات غیرمجاز] 🔴
!del
🔵 پاک کردن پیام با ریپلی 🔴
!addword [word]
🔵 افزودن کلمه به لیست کلمات غیرمجاز🔴
!remword [word]
🔵 پاک کردن کلمه از لیست کلمات غیرمجاز 🔴
!badwords
🔵 مشاهده لیست کلمات غیرمجاز 🔴
!clean msg [value]
🔵 پاک کردن تعداد پیام مورد نظر 🔴
!public [yes|no]
🔵 همگانی کردن گروه 🔴
!res [username]
🔵 به دست آوردن آیدی یک شخص 🔴
!log
🔵 لیست ورود اعضا 🔴
〰〰〰〰〰〰〰〰
💥 شما میتوانید از / و ! و # استفاده کنید 💥
💥 برای افزودن سازنده روبات به گروه استفاده کنند !invamin صاحبان گروه میتونند از دستور 💥
]],
]],
  }
  serialize_to_file(config, './data/config.lua')
  print('saved config into ./data/config.lua')
end

function on_our_id (id)
  our_id = id
end

function on_user_update (user, what)
  --vardump (user)
end

function on_chat_update (chat, what)
  --vardump (chat)
end

function on_secret_chat_update (schat, what)
  --vardump (schat)
end

function on_get_difference_end ()
end

-- Enable plugins in config.json
function load_plugins()
  for k, v in pairs(_config.enabled_plugins) do
    print("Loading plugin", v)

    local ok, err =  pcall(function()
      local t = loadfile("plugins/"..v..'.lua')()
      plugins[v] = t
    end)

    if not ok then
      print('\27[31mError loading plugin '..v..'\27[39m')
	  print(tostring(io.popen("lua plugins/"..v..".lua"):read('*all')))
      print('\27[31m'..err..'\27[39m')
    end

  end
end

-- custom add
function load_data(filename)

	local f = io.open(filename)
	if not f then
		return {}
	end
	local s = f:read('*all')
	f:close()
	local data = JSON.decode(s)

	return data

end

function save_data(filename, data)

	local s = JSON.encode(data)
	local f = io.open(filename, 'w')
	f:write(s)
	f:close()

end


-- Call and postpone execution for cron plugins
function cron_plugins()

  for name, plugin in pairs(plugins) do
    -- Only plugins with cron function
    if plugin.cron ~= nil then
      plugin.cron()
    end
  end

  -- Called again in 2 mins
  postpone (cron_plugins, false, 120)
end

-- Start and load values
our_id = 0
now = os.time()
math.randomseed(now)
started = false
