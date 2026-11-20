--!strict
-- Ticket 21.4-chat (spec 21.4): "disable global text chat during matches; team chat only".
--
-- Roblox's own chat (TextChatService, channel RBXGeneral) asks the server, for every message and every recipient, whether to
-- deliver it. Outside a match everyone talks to everyone (the lobby). In a match a message reaches only the sender's own team, and
-- a spectator's message never reaches a player who is still playing (a spectator who relayed what they see would be a leak;
-- eliminated players have their own channel, SpectateService). System messages (no sender) always go through.
--
-- Solos teams are one player, so in a Solos match nobody hears anyone. The deliver rule runs on the server and sees no client
-- claim. Voice chat is not touched (spec: team-only if possible, otherwise off in a match; Roblox voice cannot be scoped from a
-- script, so it is a setting for the place, not code).
--
-- If the place still uses the legacy chat (ChatVersion is not TextChatService) nothing here applies; the log says so once.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TextChatService = game:GetService("TextChatService")

local GameConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("GameConfig"))
local MatchService = require(script.Parent.MatchService)
local SpectateService = require(script.Parent.SpectateService)
local TeamService = require(script.Parent.TeamService)

local ChatService = {}

-- May this message reach this recipient? Pure of side effects; a nil player (left the game) is refused.
local function mayHear(senderId: number?, recipientId: number): boolean
	if not MatchService.isInMatch() then
		return true
	end
	if senderId == nil then
		return true -- a system message
	end
	local sender = Players:GetPlayerByUserId(senderId)
	local recipient = Players:GetPlayerByUserId(recipientId)
	if not sender or not recipient then
		return false
	end
	if sender == recipient then
		return true
	end
	if SpectateService.isSpectating(sender) and not SpectateService.isSpectating(recipient) then
		return false
	end
	return TeamService.areTeammates(sender, recipient)
end

function ChatService.Init() end

function ChatService.Start()
	task.spawn(function()
		if TextChatService.ChatVersion ~= Enum.ChatVersion.TextChatService then
			warn("[ChatService] the place uses legacy chat; match chat is not restricted to teams")
			return
		end
		local channels = TextChatService:WaitForChild("TextChannels", GameConfig.Chat.ChannelWaitSeconds)
		local general = channels and channels:WaitForChild("RBXGeneral", GameConfig.Chat.ChannelWaitSeconds)
		if not general or not general:IsA("TextChannel") then
			warn("[ChatService] no RBXGeneral channel; match chat is not restricted to teams")
			return
		end
		general.ShouldDeliverCallback = function(message: TextChatMessage, recipient: TextSource): boolean
			local source = message.TextSource
			local ok, result = pcall(mayHear, if source then source.UserId else nil, recipient.UserId)
			return ok and result == true
		end
	end)
end

return ChatService
