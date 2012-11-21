local pac_allow_server_size

if SERVER then 
	pac_allow_server_size = CreateConVar("pac_allow_server_size", 0, bit.bor(FCVAR_REPLICATED, FCVAR_ARCHIVE))
end

include("size.lua")

function pac.HandleServerModifiers(data, remove)
	if remove then
		pac.SetPlayerSize(data, 1)
		return
	end

	local ply = data.owner or NULL
	
	if not ply:IsPlayer() then return end
	
	if SERVER and pac_allow_server_size:GetBool() or CLIENT then
		local offset = 1

		if ply.GetInfoNum then
			offset = ply:GetInfoNum("pac_server_player_size", 0)
		end
		
		if offset > 1 then
			offset = offset - 1
			pac.SetPlayerSize(data.owner, offset)
		elseif offset == 1 then
		
			for key, part in pairs(data.part.children) do
				if 
					part.self.ClassName == "entity" and
					part.self.Size and part.self.Size ~= 1
				then
					pac.SetPlayerSize(data.owner, part.self.Size)
					return
				end
			end
			
			pac.SetPlayerSize(data.owner, 1)
		end
	end
end