AddCSLuaFile()
local sdist = CreateConVar("ssspray_range", 128, FCVAR_ARCHIVE+FCVAR_REPLICATED, "Spray distance.", 0, 1024)
local delay = GetConVar("decalfrequency")
if SERVER then
	util.AddNetworkString("sssprays")
	-- gameevent.Listen("player_activate")
	-- hook.Add("player_activate", "SSSprays", function(data)
	-- 	Player(data.userid).SSSprayColors = false
	-- end)
	hook.Add("PlayerSpray", "SSSprays", function(ply)
		return !ply:KeyDown(IN_WALK)
	end)
	hook.Add("FinishMove", "SSSprays", function(ply, mv)
		if ply:GetInternalVariable("m_flNextDecalTime") > 0 then return end
		if mv:GetImpulseCommand() != 201 then return end
		if ply:KeyDown(IN_WALK) then return end
		local trab = {}
		local pos, ang = ply:EyePos(), ply:EyeAngles()
		trab.start = pos
		trab.endpos = trab.start + ang:Forward() * sdist:GetInt()
		trab.filter = ply
		local tr = util.TraceLine(trab)
		if tr.Hit then
			ply:SetSaveValue("m_flNextDecalTime", delay:GetFloat())
			if !ply.SSSprayColors then
				local uinfo, r, g, b = ply:GetInfoNum("ssspray_color", 0), ply:GetInfoNum("ssspray_color_r", 255)/255, ply:GetInfoNum("ssspray_color_g", 255)/255, ply:GetInfoNum("ssspray_color_b", 255)/255
				ply.SSSprayColors = uinfo != 0 and (uinfo == 2 and ply:GetPlayerColor() or uinfo == 1 and ply:GetWeaponColor() or Vector(r, g, b)) or Vector(1,1,1)
			end
			ply:AddEFlags(EFL_FORCE_CHECK_TRANSMIT)
			tr.Entity:AddEFlags(EFL_FORCE_CHECK_TRANSMIT)
			sound.Play("SprayCan.Paint", trab.start + ang:Forward() * 16)
			net.Start("sssprays", true)
			net.WriteEntity(ply)
			net.WriteNormal(ply:GetAimVector())
			net.WriteVector(ply.SSSprayColors)
			net.Broadcast()
		end
	end)
end

if CLIENT then
	local scolor = CreateConVar("ssspray_color", 0, FCVAR_ARCHIVE+FCVAR_USERINFO, "Use your player colors for sprays.", -1, 2)
	local scolorcustom = CreateConVar("ssspray_color_custom", "255 255 255", FCVAR_ARCHIVE+FCVAR_USERINFO, "Custom spray color values. Moreso for reference if anything.")
	local scolorr = CreateConVar("ssspray_color_r", 255, FCVAR_ARCHIVE+FCVAR_USERINFO, "Custom spray color red value.", 0, 255)
	local scolorg = CreateConVar("ssspray_color_g", 255, FCVAR_ARCHIVE+FCVAR_USERINFO, "Custom spray color green value.", 0, 255)
	local scolorb = CreateConVar("ssspray_color_b", 255, FCVAR_ARCHIVE+FCVAR_USERINFO, "Custom spray color blue value.", 0, 255)
	local animfixnotify = CreateConVar("ssspray_fixnotification", 1, FCVAR_ARCHIVE+FCVAR_USERINFO, "Show warning for animated sprays not working.", 0, 1)
	local animfix = CreateConVar("ssspray_fixanimations", 1, FCVAR_ARCHIVE+FCVAR_USERINFO, "Automatically apply animated spray fix on multicore.", 0, 1)
	local matsys, mcore = BRANCH == "x86-64" and "1" or "0", GetConVar("gmod_mcore_test") -- i don't believe mat_queue_mode's failing here...
	local decalt = {}
	local function iWishIDidntNeedTo()
		if mcore:GetBool() then
			if animfix:GetBool() then
				RunConsoleCommand("mat_queue_mode", matsys)
			end
			if animfixnotify:GetBool() then
				local text = (animfix:GetBool() and [["mat_queue_mode" has been set to ]] .. matsys .. [[ to fix sprays not animating on models.]] or [[Animated sprays may not work on models. Set "mat_queue_mode" to ]] .. matsys .. [[ to fix this.]]) .. [[ May affect performance.]]
				print("Super Spammable Sprays: "..text)
				notification.AddLegacy(text, NOTIFY_ERROR, 5)
			end
		end
	end

	hook.Add("InitPostEntity", "SSSprays", function()
		timer.Simple(5, iWishIDidntNeedTo)
	end)

	file.CreateDir("sssprays")
	local function CreateSSSpray()
		local ply = net.ReadEntity()
		local norm = net.ReadNormal()
		local ucol = net.ReadVector()
		-- local ent = net.ReadEntity()
		if !IsValid(ply) then return end
		local uid = ply:UserID()
		local pos = ply:EyePos()
		local ang = norm:Angle()
		local dir = ang:Right()
		local qt = util.QuickTrace(pos, ang:Forward() * sdist:GetInt(), ply)
		local col = tostring(ucol)
		if !decalt[uid] or !IsValid(decalt[uid][1]) then
			-- if ply == LocalPlayer() then iWishIDidntNeedTo() end
			
			local temp = ply:GetPlayerInfo().customfiles[1]
			local cfile = "user_custom/" .. string.Left(temp, 2) .. "/" .. temp .. ".dat"
			if game.SinglePlayer() then
				temp = string.Replace(GetConVar("cl_logofile"):GetString(), "materials/", "")
				cfile = string.Replace(temp, ".vtf", "")
				temp = cfile
			else
				local tex = file.Read(cfile, "DOWNLOAD")
				cfile = "../../data/sssprays/"..temp
				if !tex or tex:len() <= 0 then
					cfile = "null"
				elseif !file.Exists("sssprays/"..temp..".vtf", "DATA") or file.Read("sssprays/"..temp..".vtf", "DATA"):len() <= 0 then
					file.Write("sssprays/"..temp..".vtf", tex)
				end
			end
			local spraytable = {
				["$basetexture"] = cfile,
				["$decal"] = 1,
				["$decalscale"] = 1,
				["$nocull"] = 1,
				["$color"] = "[1 1 1]",
				["$color2"] = "["..col.."]",
				["$alphatest"] = 1,
				["$alphatestreference"] = 1,
				["$allowalphatocoverage"] = 1,
				["Proxies"] = {
					["AnimatedTexture"] = {
						animatedtexturevar = "$basetexture",
						animatedtextureframenumvar = "$frame",
						animatedtextureframerate = 5,
					},
				},
				["$modelmaterial"] = "!ssspray/"..temp.."mdl"
			}
			local spraymdl, spray = CreateMaterial("ssspray/"..temp.."mdl", "VertexLitGeneric", spraytable), CreateMaterial("ssspray/"..temp, "LightmappedGeneric", spraytable)
			-- local texture = spraymdl:GetTexture("$basetexture")
			-- texture:Download()
			local size = 32 / spraymdl:Width()
			spraymdl:SetFloat("$decalscale", size)
			spray:SetFloat("$decalscale", size)
			decalt[uid] = {spray = spray, spraymdl = spraymdl}
		end
		if !qt.Hit then return end
		if qt.HitTexture ==  "**studio**" then
			dir = (qt.HitNormal-qt.Normal*0.1):GetNormalized()
		end
		util.DecalEx(decalt[uid].spray, qt.Entity, qt.HitPos, dir, color_white, 2, 2)
	end
	net.Receive("sssprays", CreateSSSpray)
	hook.Add("PopulateToolMenu", "SSSprays", function()
		spawnmenu.AddToolMenuOption("Options", "Chen's Addons", "SSSprays", "SSSprays", "", "", function(pnl)
			local cl, sv = vgui.Create("DForm"), vgui.Create("DForm")
			cl:SetName("Client")
			sv:SetName("Server")
			local image = vgui.Create("DImage")
			image:SetImage(string.Replace(GetConVar("cl_logofile"):GetString(), "materials/", ""))
			image:SetKeepAspect(true)
			image:SetTall(192)
			image:SetImageColor(Color(scolorr:GetInt(),scolorg:GetInt(),scolorb:GetInt()))
			pnl:AddItem(cl)
			pnl:AddItem(sv)
			pnl:SetName("Super Spammable Sprays")
			local colsel = cl:ComboBox("Spray Tint", "ssspray_color")
			colsel:SetSortItems(false)
			colsel:AddChoice("Custom", -1)
			colsel:AddChoice("Unmodified", 0)
			colsel:AddChoice("Weapon Color", 1)
			colsel:AddChoice("Player Color", 2)
			local colorbox = vgui.Create("DColorCombo")
			cl:AddItem(colorbox)
			colorbox:SetColor(Color(scolorr:GetInt(),scolorg:GetInt(),scolorb:GetInt()))
			function colorbox:OnValueChanged(col)
				scolorcustom:SetString(col.r.." "..col.g.." "..col.b)
				scolorr:SetInt(col.r)
				scolorg:SetInt(col.g)
				scolorb:SetInt(col.b)
				image:SetImageColor(Color(col.r, col.g, col.b))
			end
			cl:Help([[Custom tint preview]])
			cl:AddItem(image)
			cl:Help([[The color for your spray will be locked in after the first spray until a map change.]])
			cl:ControlHelp([[Technical limitation that I haven't figured a workaround for, yet.]])
			cl:CheckBox("Animated spray fix", "ssspray_fixanimations")
			cl:ControlHelp([[Automatically sets "mat_queue_mode" to 1 if needed. May impact performance.]])
			cl:CheckBox("Show fix notification", "ssspray_fixnotification")
			cl:ControlHelp([[Acknowledgment for user consent.]])
			sv:NumSlider("Max spray distance", "ssspray_range", 32, 1024)
			sv:NumberWang("Spray delay", "decalfrequency", 0, 600)
		end)
	end)
end
