-- methods that mineunit has not yet implemented or will never implement but
-- are needed by the unit tests.

-- not needed with core 5.5.0 (possibly earlier)
function vector.copy(v) return { x = v.x or 0, y = v.y or 0, z = v.z or 0 } end

-- not needed with core 5.5.0 (possibly earlier)
function vector.zero() return { x = 0, y = 0, z = 0 } end

function Player:hud_get_flags()
	return self._hud_flags or { hotbar = true, healthbar = true, crosshair = true,
		wielditem = true, breathbar = true, minimap = false, minimap_radar = false }
end
function Player:hud_set_flags(new_flags)
	if not self._hud_flags then self._hud_flags = self:hud_get_flags() end
	for flag, value in pairs(new_flags) do if nil ~= self._hud_flags[flag] then self._hud_flags[flag] = not not value end end
end

function ObjectRef:get_nametag_attributes()
	if not self._nametag_attributes then self._nametag_attributes = {
		text = self._nametag_text or '',
		color = self._nametag_color or { a = 255, r = 255, g = 255, b = 255 },
		bgcolor = self._nametag_bgcolor or { a = 0, r = 0, g = 0, b = 0 },
	}
	end
	return self._nametag_attributes
end

function Player:set_eye_offset(firstperson, thirdperson)
	self._eye_offset_first =
		firstperson and vector.copy(firstperson) or vector.zero()

	thirdperson = thirdperson and vector.copy(thirdperson) or vector.zero()
	thirdperson.x = math.max(-10, math.min(10, thirdperson.x))
	thirdperson.y = math.max(-10, math.min(15, thirdperson.y))
	thirdperson.z = math.max(-5, math.min(5, thirdperson.z))
	self._eye_offset_third = thirdperson
end

function Player:get_breath() return self._breath or 10 end
function Player:set_breath(value) self._breath = tonumber(value) or self._breath end

function ObjectRef:set_nametag_attributes(new_attributes)
	if not self._nametag_attributes then self:get_nametag_attributes() end
	for key, value in pairs(new_attributes) do
		if nil ~= self._nametag_attributes[key] then
			if 'name' == key then
				self._nametag_attributes.name = tostring(value)
			else
				for subkey, subvalue in pairs(new_attributes[key]) do
					if nil ~= self._nametag_attributes[key][subkey] then
						self._nametag_attributes[key][subkey] = tonumber(subvalue)
					end
				end
			end
		end
	end
end

function ObjectRef:set_pos(value)
	self._pos = vector.copy(value)
	for _, child in ipairs(self:get_children()) do
		child:set_pos(vector.add(self._pos, child._attach.position))
	end
end
function ObjectRef:set_attach(parent, bone, position, rotation, forced_visible)
	if not parent then return end
	if self._attach and self._attach.parent == parent then
		mineunit:info('Attempt to attach to parent that object is already attached to.')
		return
	end
	-- detach if attached
	self:set_detach()
	local obj = parent
	while true do
		if not obj._attach then break end
		if obj._attach.parent == self then
			mineunit:warning('Mod bug: Attempted to attach object to an object that '
				.. 'is directly or indirectly attached to the first object. -> '
				.. 'circular attachment chain.')
			return
		end
		obj = obj._attach.parent
	end
	if 'table' ~= type(parent._children) then parent._children = {} end
	table.insert(parent._children, self)
	self._attach = {
		parent = parent,
		bone = bone or '',
		position = position or vector.zero(),
		rotation = rotation or vector.zero(),
		forced_visible = not not forced_visible,
	}
	self._pitch = self._attach.position.x
	self._roll = self._attach.position.z
	self._yaw = self._attach.position.y
	self:set_pos(vector.add(parent:get_pos(), self._attach.position))
	-- TODO: bones depending on object type
end
function ObjectRef:get_attach()
	return self._attach
end
function ObjectRef:get_children()
	return self._children or {}
end
function ObjectRef:set_detach()
	if not self._attach then return end
	local new_children = {}
	for _, child in ipairs(self._attach.parent._children) do
		if child ~= self then table.insert(new_children, child) end
	end
	self._attach.parent._children = new_children
	self._attach = nil
end

