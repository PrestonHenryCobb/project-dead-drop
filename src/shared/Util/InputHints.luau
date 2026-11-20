--!strict
-- Owner request 2026-11-20: a control hint names the control of the device the player is using now, never both a keyboard key and a
-- gamepad button. The device is whatever sent the last input (UserInputService.LastInputType): a gamepad, or otherwise keyboard
-- and mouse. A hint for an action that has no binding on the current device is left out rather than naming a key that does
-- nothing there.
--
--   InputHints.isGamepad() -> boolean
--   InputHints.onChange(callback) -> RBXScriptConnection   callback(isGamepad) when the device flips between pad and keyboard
--   InputHints.name(code) -> string                         a short readable name for a key, mouse button or pad button
--   InputHints.pick(key, pad) -> string?                    the name to show now, or nil when this device has no binding
--   InputHints.bracket(key, pad, label) -> string           "[ E ] LABEL" for the current device; just "LABEL" if unbound there
--   InputHints.line(entries) -> string                      bracketed hints joined by " · ", unbound ones left out
--   InputHints.text(keyboard, gamepad) -> string            plain text chosen by device, for hints that are prose

local UserInputService = game:GetService("UserInputService")

local InputHints = {}

export type Code = Enum.KeyCode | Enum.UserInputType
-- Two keys or two buttons shown together (a floor up and floor down pair): Second is the other one.
export type Entry = { Label: string, Key: Code?, Second: Code?, Pad: Enum.KeyCode?, PadSecond: Enum.KeyCode? }

local padNames: { [string]: string } = {
	ButtonA = "A",
	ButtonB = "B",
	ButtonX = "X",
	ButtonY = "Y",
	ButtonL1 = "LB",
	ButtonR1 = "RB",
	ButtonL2 = "LT",
	ButtonR2 = "RT",
	ButtonL3 = "L3",
	ButtonR3 = "R3",
	ButtonSelect = "VIEW",
	ButtonStart = "MENU",
	DPadUp = "D-PAD UP",
	DPadDown = "D-PAD DOWN",
	DPadLeft = "D-PAD LEFT",
	DPadRight = "D-PAD RIGHT",
}

local keyNames: { [string]: string } = {
	LeftShift = "SHIFT",
	RightShift = "SHIFT",
	LeftControl = "CTRL",
	RightControl = "CTRL",
	LeftAlt = "ALT",
	RightAlt = "ALT",
	Return = "ENTER",
	Backspace = "BACKSPACE",
	Space = "SPACE",
	One = "1",
	Two = "2",
	Three = "3",
	Four = "4",
	Five = "5",
	MouseButton1 = "LMB",
	MouseButton2 = "RMB",
	MouseButton3 = "MMB",
}

function InputHints.isGamepad(): boolean
	return string.find(UserInputService:GetLastInputType().Name, "Gamepad", 1, true) ~= nil
end

function InputHints.onChange(callback: (boolean) -> ()): RBXScriptConnection
	local last = InputHints.isGamepad()
	return UserInputService.LastInputTypeChanged:Connect(function()
		local now = InputHints.isGamepad()
		if now ~= last then
			last = now
			callback(now)
		end
	end)
end

function InputHints.name(code: Code): string
	return padNames[code.Name] or keyNames[code.Name] or string.upper(code.Name)
end

local function joined(first: Code?, second: Code?): string?
	if not first then
		return nil
	end
	if second then
		return `{InputHints.name(first)} / {InputHints.name(second)}`
	end
	return InputHints.name(first)
end

function InputHints.pick(key: Code?, pad: Enum.KeyCode?): string?
	if InputHints.isGamepad() then
		return if pad then InputHints.name(pad) else nil
	end
	return if key then InputHints.name(key) else nil
end

function InputHints.bracket(key: Code?, pad: Enum.KeyCode?, label: string): string
	local shown = InputHints.pick(key, pad)
	return if shown then `[ {shown} ] {label}` else label
end

function InputHints.line(entries: { Entry }): string
	local pad = InputHints.isGamepad()
	local parts: { string } = {}
	for _, entry in entries do
		local shown = if pad then joined(entry.Pad, entry.PadSecond) else joined(entry.Key, entry.Second)
		if shown then
			table.insert(parts, `[ {shown} ] {entry.Label}`)
		end
	end
	return table.concat(parts, " · ")
end

function InputHints.text(keyboard: string, gamepad: string): string
	return if InputHints.isGamepad() then gamepad else keyboard
end

return InputHints
