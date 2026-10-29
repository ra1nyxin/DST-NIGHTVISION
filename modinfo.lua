name ="NightVision"
description = [[
NightVision
]]
author = "null"
version = "1.0"
api_version = 10
all_clients_require_mod = false
client_only_mod = true
dst_compatible = true
local KEY_A = 65
local keyslist = {}
local string = "" 
for i = 1, 26 do
	local ch = string.char(KEY_A + i - 1)
	keyslist[i] = {description = ch, data = ch}
end
configuration_options =
{
	{
		name = "FREENIGHTVISION_TOGGLEKEY",
		label = "Toggle Nightvision button",
		hover = "Toggle Nightvision button",
		options = keyslist,
		default = "N",
	},
	{
		name = "FREENIGHTVISION_GRUEALERT",
		label = "Darkness Alert",
		hover = "Darkness Alert",
		options = {
		        {description = "Off", data = false},
		        {description = "On", data = true},
		        },
		default =true,
	},

}
