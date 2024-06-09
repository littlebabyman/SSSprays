AddCSLuaFile()

if SERVER then
	util.AddNetworkString("turbosprays")
	hook.Add("PlayerSpray", "TurboSprays", function(ply)
		if !game.SinglePlayer() and ply:GetPlayerInfo().customfiles[1] == "00000000" then return end
		net.Start("turbosprays")
		net.WriteUInt(ply:UserID(),16)
		net.Broadcast()
		return true
	end)
end

if CLIENT then
	local decalt = {}
	file.CreateDir("turbospray")
	local function CreateTurboSpray(len, ply)
		local uid = net.ReadUInt(16)
		ply = Player(uid)
		if !IsValid(ply) then return end
		if !decalt[uid] then
			local temp = ply:GetPlayerInfo().customfiles[1]
			local cfile = "user_custom/" .. string.Left(temp, 2) .. "/" .. temp .. ".dat"
			if game.SinglePlayer() then
				temp = string.Replace(GetConVar("cl_logofile"):GetString(), "materials/", "")
				cfile = string.Replace(temp, ".vtf", "")
				temp = cfile
			elseif !file.Exists("turbospray/"..temp..".vtf", "DATA") then
				local tex = file.Read(cfile, "DOWNLOAD")
				-- if !IsValid(tex) then return end
				file.Write("turbospray/"..temp..".vtf", tex)
				-- print(temp, file.Exists("turbospray/"..temp..".vtf", "DATA"))
				cfile = "../data/turbospray/"..temp
				-- file.AsyncRead(cfile, "DOWNLOAD", function(name,path,status,data)
				-- 	print(name,path,status,data)
				-- 	if status == FSASYNC_OK then
				-- 		file.Write("turbospray/"..temp..".vtf", data)
				-- 		print(temp, file.Exists("turbospray/"..temp..".vtf", "DATA"))
				-- 		cfile = "../data/turbospray/"..temp
				-- 		return
				-- 	else print(status) end
				-- end)
			else
				cfile = "../../data/turbospray/"..temp
			end
			print(cfile, "hi")
			local spraymdl = CreateMaterial("ts/"..temp.."mdl", "VertexLitGeneric", {
				["$basetexture"] = cfile,
				["$decal"] = 1,
				["$decalscale"] = 1,
				-- ["$translucent"] = 1,
				["$vertexalpha"] = 1,
				-- ["$vertexcolor"] = 1,
				-- ["$decalsecondpass"] = 1
			})
			local spray = CreateMaterial("ts/"..temp, "LightmappedGeneric", {
				["$basetexture"] = cfile,
				-- ["$detail"] = cfile,
				-- ["$detailscale"] = 2,
				-- ["$detailblendmode"] = 4,
				["$decal"] = 1,
				["$decalscale"] = 1,
				["$modelmaterial"] = "!ts/"..temp.."mdl",
				-- ["$translucent"] = 1,
				["$vertexalpha"] = 1,
				-- ["$vertexcolor"] = 1,
				-- ["$decalsecondpass"] = 1
			})
			spraymdl:SetFloat("$decalscale", 32 / spraymdl:Width())
			spray:SetFloat("$decalscale", 32 / spraymdl:Width())
			decalt[uid] = spray
			print(spraymdl:GetString("$decalscale"), spray:GetTexture("$basetexture"):Height())
		end
		local qt = util.QuickTrace(ply:EyePos(), ply:GetAimVector() * 256, ply)
		if !qt.Hit then return end
		util.DecalEx(decalt[uid], qt.Entity, qt.HitPos, qt.HitNormal, color_white, 2, 2)
	end
	net.Receive("turbosprays", CreateTurboSpray)
end
