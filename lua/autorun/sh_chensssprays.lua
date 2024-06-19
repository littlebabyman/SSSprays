AddCSLuaFile()
local sdist = CreateConVar("ssspray_range", 128, FCVAR_ARCHIVE+FCVAR_REPLICATED, "Spray distance.", 0, 1024)
local delay = GetConVar("decalfrequency")
if SERVER then
	util.AddNetworkString("sssprays")
	hook.Add("PlayerSpray", "SSSprays", function(ply)
		if game.SinglePlayer() or !ply:KeyDown(IN_WALK) then return true end
	end)
	hook.Add("FinishMove", "SSSprays", function(ply, mv)
		if ply:GetInternalVariable("m_flNextDecalTime") > 0 then return end
		if mv:GetImpulseCommand() != 201 then return end
		local trab = {}
		local pos, ang = ply:EyePos(), ply:EyeAngles()
		trab.start = pos
		trab.endpos = trab.start + ang:Forward() * sdist:GetInt()
		trab.filter = ply
		local tr = util.TraceLine(trab)
		if !tr.Hit then return end
		if ply:KeyDown(IN_WALK) then ply:SprayDecal(pos, trab.endpos) return end
		sound.Play("SprayCan.Paint", trab.start + ang:Forward() * 16)
		ply:SetSaveValue("m_flNextDecalTime", delay:GetFloat())
		ply:AddEFlags(EFL_FORCE_CHECK_TRANSMIT)
		tr.Entity:AddEFlags(EFL_FORCE_CHECK_TRANSMIT)
		net.Start("sssprays", true)
		net.WriteEntity(ply)
		net.WriteNormal(ply:GetAimVector())
		net.WriteEntity(tr.Entity)
		net.Broadcast()
	end)
end

if CLIENT then
	local decalt = {}
	file.CreateDir("sssprays")
	local function CreateSSSpray(len, ply)
		print(len)
		
		-- local uid = net.ReadUInt(8)
		-- ply = Player(uid)
		ply = net.ReadEntity()
		local norm = net.ReadNormal()
		local ent = net.ReadEntity()
		-- local norm = net.ReadNormal()
		if !IsValid(ply) then return end
		print(ply, ent:GetPos())
		local uid = ply:UserID()
		local pos = ply:EyePos()
		local ang = norm:Angle()
		local dir = ang:Right()
		print(dir)
		if !decalt[uid] then
			local temp = ply:GetPlayerInfo().customfiles[1]
			local cfile = "user_custom/" .. string.Left(temp, 2) .. "/" .. temp .. ".dat"
			if game.SinglePlayer() then
				temp = string.Replace(GetConVar("cl_logofile"):GetString(), "materials/", "")
				cfile = string.Replace(temp, ".vtf", "")
				temp = cfile
			else
				if !file.Exists("sssprays/"..temp..".vtf", "DATA") then
				local tex = file.Read(cfile, "DOWNLOAD")
				file.Write("sssprays/"..temp..".vtf", tex)
				end
				cfile = "../../data/sssprays/"..temp
			end
			local spraymdl = CreateMaterial("ssspray/"..temp.."mdl", "VertexLitGeneric", {
				["$basetexture"] = cfile,
				["$decal"] = 1,
				["$decalscale"] = 1,
				["$vertexalpha"] = 1,
				["$decalsecondpass"] = 1,
			})
			local spray = CreateMaterial("ssspray/"..temp, "LightmappedGeneric", {
				["$basetexture"] = cfile,
				["$decal"] = 1,
				["$decalscale"] = 1,
				["$modelmaterial"] = "!ssspray/"..temp.."mdl",
				["$vertexalpha"] = 1,
				["$decalsecondpass"] = 1,
			})
			spraymdl:SetFloat("$decalscale", 64 / spraymdl:Width())
			spray:SetFloat("$decalscale", 64 / spray:Width())
			decalt[uid] = spray
		end
		local qt = util.QuickTrace(pos, ang:Forward() * sdist:GetInt(), ply)
		if !qt.Hit then return end
		if qt.HitTexture ==  "**studio**" then dir = qt.HitNormal-qt.Normal end
		util.DecalEx(decalt[uid], qt.Entity, qt.HitPos+qt.HitNormal, dir, color_white, 1, 1)
	end
	net.Receive("sssprays", CreateSSSpray)
end
