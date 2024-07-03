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
	local scolor = CreateConVar("ssspray_color", 0, FCVAR_ARCHIVE+FCVAR_USERINFO, "Use your player colors for sprays.", -1, 2)
	local scolorcustom = CreateConVar("ssspray_color_custom", "255 255 255", FCVAR_ARCHIVE+FCVAR_USERINFO, "Custom spray color values. Moreso for reference if anything.")
	local scolorr = CreateConVar("ssspray_color_r", 255, FCVAR_ARCHIVE+FCVAR_USERINFO, "Custom spray color red value.")
	local scolorg = CreateConVar("ssspray_color_g", 255, FCVAR_ARCHIVE+FCVAR_USERINFO, "Custom spray color green value.")
	local scolorb = CreateConVar("ssspray_color_b", 255, FCVAR_ARCHIVE+FCVAR_USERINFO, "Custom spray color blue value.")
	local decalt = {}
	file.CreateDir("sssprays")
	local function CreateSSSpray()
		ply = net.ReadEntity()
		local norm = net.ReadNormal()
		local ent = net.ReadEntity()
		if !IsValid(ply) then return end
		local uid = ply:UserID()
		local pos = ply:EyePos()
		local ang = norm:Angle()
		local dir = ang:Right()
		local uinfo = ply:GetInfoNum("ssspray_color", 0)
		local ucol = uinfo != 0 and (uinfo == 2 and ply:GetPlayerColor() or uinfo == 1 and ply:GetWeaponColor() or Vector(ply:GetInfoNum("ssspray_color_r", 255) / 255,ply:GetInfoNum("ssspray_color_g", 255) / 255,ply:GetInfoNum("ssspray_color_b", 255) / 255)) or Vector(1,1,1)
		if !decalt[uid] then
			local temp = ply:GetPlayerInfo().customfiles[1]
			local cfile = "user_custom/" .. string.Left(temp, 2) .. "/" .. temp .. ".dat"
			if game.SinglePlayer() then
				temp = string.Replace(GetConVar("cl_logofile"):GetString(), "materials/", "")
				cfile = string.Replace(temp, ".vtf", "")
				temp = cfile
			else
				local tex = file.Read(cfile, "DOWNLOAD")
				if !tex or tex:len() <= 0 then return end
				if !file.Exists("sssprays/"..temp..".vtf", "DATA") or file.Read("sssprays/"..temp..".vtf", "DATA"):len() <= 0 then
				file.Write("sssprays/"..temp..".vtf", tex)
				end
				cfile = "../../data/sssprays/"..temp
			end
			local spraymdl = CreateMaterial("ssspray/"..temp.."mdl", "VertexLitGeneric", {
				["$basetexture"] = cfile,
				["$model"] = 1,
				["$decal"] = 1,
				["$decalscale"] = 1,
				-- ["$alphatest"] = 1,
				-- ["$alphatestreference"] = 1,
				-- ["$allowalphatocoverage"] = 1,
				-- ["$vertexcolor"] = 1,
				["$translucent"] = 1,
				-- ["$vertexalpha"] = 1,
				["$color2"] = "["..tostring(ucol).."]",
				-- ["$blendtintcoloroverbase"] = 1,
				-- ["$decalsecondpass"] = 1,
				["Proxies"] = {
					["AnimatedOffsetTexture"] = {
						["animatedtexturevar"] = "$basetexture",
						["animatedtextureframenumvar"] = "$frame",
						["animatedtextureframerate"] = 5,
					}
				}
			})
			local spray = CreateMaterial("ssspray/"..temp, "LightmappedGeneric", {
				["$basetexture"] = cfile,
				["$decal"] = 1,
				["$decalscale"] = 1,
				["$modelmaterial"] = "!ssspray/"..temp.."mdl",
				-- ["$alphatest"] = 1,
				-- ["$alphatestreference"] = 1,
				-- ["$allowalphatocoverage"] = 1,
				["$color"] = "[1 1 1]",
				["$vertexalpha"] = 1,
				["$vertexcolor"] = 1,
				-- ["$decalsecondpass"] = 1,
				["Proxies"] = {
					["AnimatedOffsetTexture"] = {
						["animatedtexturevar"] = "$basetexture",
						["animatedtextureframenumvar"] = "$frame",
						["animatedtextureframerate"] = 5,
					}
				}
			})
			spraymdl:SetFloat("$decalscale", 32 / spraymdl:Width())
			spray:SetFloat("$decalscale", 32 / spray:Width())
			decalt[uid] = {spray, spraymdl}
		end
		local qt = util.QuickTrace(pos, ang:Forward() * sdist:GetInt(), ply)
		if !qt.Hit then return end
		local color = qt.HitTexture !=  "**studio**" and uinfo != 0 and ucol:ToColor() or color_white
		if qt.HitTexture ==  "**studio**" then
			dir = (qt.HitNormal-qt.Normal*0.1):GetNormalized()
		end
		util.DecalEx(decalt[uid][1], qt.Entity, qt.HitPos, dir, color, 2, 2)
	end
	net.Receive("sssprays", CreateSSSpray)
	hook.Add("PopulateToolMenu", "SSSprays", function()
		spawnmenu.AddToolMenuOption("Options", "Chen's Addons", "SSSprays", "SSSprays", "", "", function(pnl)
			local cl, sv = vgui.Create("DForm"), vgui.Create("DForm")
			pnl:AddItem(cl)
			pnl:AddItem(sv)
			pnl:SetName("Super Spammable Sprays")
			local colsel = cl:ComboBox("Spray Color", "ssspray_color")
			colsel:SetSortItems(false)
			colsel:AddChoice("Custom", -1)
			colsel:AddChoice("Unmodified", 0)
			colsel:AddChoice("Weapon Color", 1)
			colsel:AddChoice("Player Color", 2)
			local colorbox = vgui.Create("DColorCombo")
			cl:AddItem(colorbox)
			function colorbox:OnValueChanged(col)
				scolorcustom:SetString(col["r"].." "..col["g"].." "..col["b"])
				scolorr:SetInt(col["r"])
				scolorg:SetInt(col["g"])
				scolorb:SetInt(col["b"])
			end
			sv:NumSlider("Max spray distance", "ssspray_range", 32, 1024)
			sv:NumberWang("Spray delay", "decalfrequency", 0, 600)
		end)
	end)
end
