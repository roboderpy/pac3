pac.next_frame_funcs = {}

function pac.RunNextFrame(id, func)
	pac.next_frame_funcs[id] = func
end

do --dev util
	function pac.RemoveAllPACEntities()
		for key, ent in pairs(ents.GetAll()) do
			if ent.pac_parts then
				pac.UnhookEntityRender(ent)
				--ent:Remove()
			end
			
			if ent.IsPACEntity then
				ent:Remove()
			end
		end
	end

	function pac.Panic()
		pac.RemoveAllParts()
		pac.RemoveAllPACEntities()
		pac.Parts = {}
	end


	function pac.Restart()
		if pac then pac.Panic() end
		
		local was_open
		
		if pace then 
			was_open = pace.Editor:IsValid() 
			pace.Panic() 
		end

		pac = {}
		pace = {}
		
		include("autorun/pac_init.lua")
		include("autorun/pac_editor_init.lua")
		
		for _, ent in pairs(ents.GetAll()) do
			for k, v in pairs(ent:GetTable()) do
				if k:sub(0, 4) == "pac_" then
					ent[k] = nil
				end
			end
		end

		if was_open then 
			pace.OpenEditor() 
		end
	end

	concommand.Add("pac_restart", pac.Restart)
	
	function pac.dprint(fmt, ...)
		if pac.debug then
			MsgN("\n")	
			MsgN(">>>PAC3>>>")
			MsgN(fmt:format(...))
			if pac.debug_trace then
				MsgN("==TRACE==")
				debug.Trace()
				MsgN("==TRACE==")
			end
			MsgN("<<<PAC3<<<")
			MsgN("\n")
		end
	end
end
		
do
	local hue =
	{
		"red",
		"orange",
		"yellow",
		"green",
		"turquoise",
		"blue",
		"purple",
		"magenta",	
	}

	local sat =
	{
		"pale",
		"",
		"strong",
	}

	local val =
	{
		"dark",
		"",
		"bright"
	}

	function pac.HSVToNames(h,s,v)
		return 
			hue[math.Round((1+(h/360)*#hue))] or hue[1],
			sat[math.ceil(s*#sat)] or sat[1],
			val[math.ceil(v*#val)] or val[1]
	end

	function pac.ColorToNames(c)
		if c.r == 255 and c.g == 255 and c.b == 255 then return "white", "", "bright" end
		if c.r == 0 and c.g == 0 and c.b == 0 then return "black", "", "bright" end
		return pac.HSVToNames(ColorToHSV(Color(c.r, c.g, c.b)))
	end
		
		
	function pac.PrettifyName(str)
		if not str then return end
		str = str:lower()
		str = str:gsub("_", " ")
		return str
	end

end

function pac.CalcEntityCRC(ent)
	local pos = ent:GetPos()
	local ang = ent:GetAngles()
	local mdl = ent:GetModel():lower():gsub("\\", "/")
	local x,y,z = math.Round(pos.x/10)*10, math.Round(pos.y/10)*10, math.Round(pos.z/10)*10
	local p,_y,r = math.Round(ang.p/10)*10, math.Round(ang.y/10)*10, math.Round(ang.r/10)*10

	local crc = x .. y .. z .. p .. _y .. r .. mdl

	return util.CRC(crc)
end

function pac.MakeNull(tbl)
	if tbl then
		for k,v in pairs(tbl) do tbl[k] = nil end
		setmetatable(tbl, pac.NULLMeta)
	end
end

pac.EntityType = 2

function pac.CreateEntity(model, type)
	type = type or pac.EntityType or 1

	local ent = NULL

	if type == 1 then

		ent = ClientsideModel(model)

	elseif type == 2 then

		ent = ents.CreateClientProp()
		ent:SetModel(model)

	elseif type == 3 then

		effects.Register(
			{
				Init = function(self, p)
					self:SetModel(model)
					ent = self
				end,

				Think = function()
					return true
				end,

				Render = function(self)
					if self.Draw then self:Draw() else self:DrawModel() end
				end
			},

			"pac_model"
		)

		util.Effect("pac_model", EffectData())
	end

	return ent
end


do -- hook helpers
	local added_hooks = {}

	function pac.AddHook(str, func)
		func = func or pac[str]
		
		local id = "pac_" .. str
		
		hook.Add(str, id, func)
		
		added_hooks[str] = {func = func, event = str, id = id}
	end

	function pac.RemoveHook(str)
		local data = added_hooks[str]
		
		hook.Remove(data.event, data.id)
	end

	function pac.CallHook(str, ...)
		return hook.Call("pac_" .. str, GAMEMODE, ...)
	end
	
	pac.added_hooks = added_hooks
end

do -- get set and editor vars
	pac.VariableOrder = {}
	
	local function insert_key(key)
		for k,v in pairs(pac.VariableOrder) do
			if k == key then
				return
			end
		end
		
		table.insert(pac.VariableOrder, key)
	end
	
	local __store = false

	function pac.StartStorableVars()
		__store = true
	end

	function pac.EndStorableVars()
		__store = false
	end

	function pac.GetSet(tbl, key, ...)
		insert_key(key)
		
		pac.class.GetSet(tbl, key, ...)

		if __store then
			tbl.StorableVars = tbl.StorableVars or {}
			tbl.StorableVars[key] = key
		end
	end

	function pac.IsSet(tbl, key, ...)
		insert_key(key)
		pac.class.IsSet(tbl, key, ...)

		if __store then
			tbl.StorableVars = tbl.StorableVars or {}
			tbl.StorableVars[key] = key
		end
	end
	
	function pac.SetupPartName(PART, key)		
		PART.PartNameResolvers = PART.PartNameResolvers or {}
				
		local part_key = key
		local part_set_key = "Set" .. part_key
		
		local uid_key = part_key .. "UID"
		local name_key = key.."Name"
		local name_set_key = "Set" .. name_key
		
		local last_name_key = "last_" .. name_key:lower()
		local last_uid_key = "last_" .. uid_key:lower()
		local try_key = "try_" .. name_key:lower()
		
		local name_find_count_key = name_key:lower() .. "_try_count"
		
		-- these keys are ignored when table is set. it's kind of a hack..
		PART.IngoreSetKeys = PART.IgnoreSetKeys or {}
		PART.IngoreSetKeys[name_key] = true
		
		pac.EndStorableVars()
			pac.GetSet(PART, part_key, pac.NULL)
		pac.StartStorableVars()
		
		pac.GetSet(PART, name_key, "")
		pac.GetSet(PART, uid_key, "")
					
		PART.ResolvePartNames = PART.ResolvePartNames or function(self, force)
			for key, func in pairs(self.PartNameResolvers) do
				func(self, force)
			end
		end		
				
		PART["Resolve" .. name_key] = function(self, force)
			PART.PartNameResolvers[part_key](self, force)
		end
		
		PART.PartNameResolvers[part_key] = function(self, force)
	
			if self[uid_key] == "" and self[name_key] == "" then return end 
	
			if force or self[try_key] or self[uid_key] ~= "" and not self[part_key]:IsValid() then
				
				-- match by name instead
				if self[try_key] and not self.supress_part_name_find then
					for key, part in pairs(pac.GetParts()) do
						if 
							part ~= self and 
							self[part_key] ~= part and 
							part:GetPlayerOwner() == self:GetPlayerOwner() and 
							part.Name == self[name_key] 
						then
							self[name_set_key](self, part)
							break
						end
						
						self[last_uid_key] = self[uid_key] 
					end
					self[try_key] = false
				else
					local part = pac.GetPartFromUniqueID(self.owner_id, self[uid_key])
					
					if part:IsValid() and part ~= self and self[part_key] ~= part then 
						self[name_set_key](self, part)
					end
					
					self[last_uid_key] = self[uid_key] 
				end
			end
		end
		
		PART[name_set_key] = function(self, var)
			self[name_find_count_key] = 0
			
			if type(var) == "string" then
				
				self[name_key] = var

				if var == "" then
					self[uid_key] = ""
					self[part_key] = pac.NULL
					return
				else
					self[try_key] = true
				end
			
				PART.PartNameResolvers[part_key](self)
			else
				self[name_key] = var.Name
				self[uid_key] = var.UniqueID
				self[part_set_key](self, var)
			end
		end			
	end
end

function pac.Material(str, part)
	if str ~= "" then
		for key, part in pairs(pac.GetParts()) do
			if part.GetRawMaterial and str == part.Name then
				return part:GetRawMaterial()
			end
		end
	end
	
	return Material(str)
end

function pac.Handleurltex(part, url, callback)
	if url and pac.urltex and url:find("http") then	
		local skip_cache = url:sub(1,1) == "_"
		url = url:gsub("https://", "http://")
		url = url:match("http[s]-://.+/.-%.%a+")
		if url then
			pac.urltex.GetMaterialFromURL(
				url, 
				function(mat, tex)
					if part:IsValid() then
						if callback then
							callback(mat, tex)
						else
							part.Materialm = mat
							part:CallEvent("material_changed")
						end
						pac.dprint("set custom material texture %q to %s", url, part:GetName())
					end
				end,
				skip_cache
			)
			return true
		end
	end	
end

local mat
local Matrix = Matrix

function pac.SetModelScale(ent, scale, size)
	if not ent:IsValid() then return end
	if ent.pac_bone_scaling then return end

	if scale then
		mat = Matrix()
		mat:Scale(scale)
		
		if VERSION >= 140328 then
			ent.pac_matrixhack = mat
			
			if not ent.pac_follow_bones_function then
				ent.pac_follow_bones_function = pac.build_bone_callback
				ent:AddCallback("BuildBonePositions", function(ent) pac.build_bone_callback(ent) end)
			end
		else
			ent:EnableMatrix("RenderMultiply", mat)
		end
	end
	
	if size then
		if ent.pac_enable_ik then
			ent:SetIK(true)
			ent:SetModelScale(1, 0)
		else
			ent:SetIK(false)
			ent:SetModelScale(size == 1 and 1.000001 or size, 0)
		end
	end
	
	if not scale and not size then
		ent:DisableMatrix("RenderMultiply")
	end
	
	if scale and size then
		ent.pac_model_scale = scale * size
	end
	
	if scale and not size then
		ent.pac_model_scale = scale
	end
	
	if not scale and size then
		ent.pac_model_scale = Vector(size, size, size)
	end
end

-- no need to rematch the same pattern
local pattern_cache = {{}}

function pac.StringFind(a, b, simple, case_sensitive)
	if not a or not b then return end
	
	if simple and not case_sensitive then
		a = a:lower()
		b = b:lower()
	end
		
	pattern_cache[a] = pattern_cache[a] or {}
		
	if pattern_cache[a][b] ~= nil then
		return pattern_cache[a][b]
	end
		
	if simple and a:find(b, nil, true) or not simple and a:find(b) then
		pattern_cache[a][b] = true
		return true
	else
		pattern_cache[a][b] = false
		return false
	end
end

function pac.HideWeapon(wep, hide)
	if wep.pac_hide_weapon == true then
		wep:SetNoDraw(true)
		wep.pac_wep_hiding = true
		return
	end
	if hide then
		wep:SetNoDraw(true)
		wep.pac_wep_hiding = true
	else
		if wep.pac_wep_hiding then
			wep:SetNoDraw(false)
			wep.pac_wep_hiding = false
		end
	end
end

-- this function adds the unique id of the owner to the part name to resolve name conflicts
-- hack??

function pac.HandlePartName(ply, name)
	if ply:IsValid() then
		if ply:IsPlayer() and ply ~= pac.LocalPlayer then
			return ply:UniqueID() .. " " .. name
		end
		
		if not ply:IsPlayer() then	
			return pac.CallHook("HandlePartName", ply, name) or (ply:EntIndex() .. " " .. name)
		end
	end
	
	return name
end
