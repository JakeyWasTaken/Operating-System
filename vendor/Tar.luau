--!strict
--!native
--!optimize 2

-- Tar reader for Luau.
-- Parses a raw tar archive string into an in-memory tree of directory/file
-- nodes.

local readu8 = buffer.readu8
local readstring = buffer.readstring
local fromstring = buffer.fromstring
local buflen = buffer.len
local ceil = math.ceil
local find = string.find
local sub = string.sub
local gmatch = string.gmatch

local BLOCK = 512

export type FileNode = {
	type: "file",
	name: string, -- base name, e.g. "init.luau"
	path: string, -- full archive path, e.g. "src/init.luau"
	size: number,
	mode: number,
	mtime: number,
	data: string, -- raw contents, binary-safe
}

export type DirNode = {
	type: "directory",
	name: string,
	path: string,
	children: { [string]: Node },
}

export type Node = FileNode | DirNode

-- Cut a fixed-width field at its first NUL.
local function nulcut(s: string): string
	local nul = find(s, "\0", 1, true)
	return if nul then sub(s, 1, nul - 1) else s
end

-- Parse a NUL/space-padded octal field straight out of the buffer
-- (no intermediate string allocation).
local function octalAt(b: buffer, base: number, count: number): number
	local n = 0
	for i = 0, count - 1 do
		local c = readu8(b, base + i)
		if c >= 48 and c <= 55 then -- '0'..'7'
			n = n * 8 + (c - 48)
		elseif n ~= 0 then
			break -- digits done; hit trailing space/NUL
		end
		-- leading spaces/NULs ignored while n == 0
	end
	return n
end

-- Standard header checksum: all 512 bytes summed, with the 8-byte checksum
-- field (148..155) counted as spaces (8 * 32 = 256).
local function checksum(b: buffer, base: number): number
	local sum = 256
	for i = 0, 147 do
		sum += readu8(b, base + i)
	end
	for i = 156, 511 do
		sum += readu8(b, base + i)
	end
	return sum
end

local function split(path: string): { string }
	local parts: { string } = {}
	for seg in gmatch(path, "[^/]+") do
		table.insert(parts, seg)
	end
	return parts
end

local function readTar(b: buffer): (Node?, string?)
	local len = buflen(b)

	local root: DirNode = {
		type = "directory",
		name = "",
		path = "",
		children = {},
	}

	-- Resolve parts[1..count] as a directory chain, creating nodes as needed.
	local function getDir(parts: { string }, count: number): DirNode?
		local node = root
		for i = 1, count do
			local seg = parts[i]
			local child = node.children[seg]
			if child == nil then
				local dir: DirNode = {
					type = "directory",
					name = seg,
					path = if node.path == "" then seg else node.path .. "/" .. seg,
					children = {},
				}
				node.children[seg] = dir
				node = dir
			elseif child.type == "directory" then
				node = child
			else
				return nil -- a file already sits where a directory is needed
			end
		end
		return node
	end

	local longName: string? = nil
	local pos = 0

	while pos + BLOCK <= len do
		local base = pos
		local sum = checksum(b, base)

		-- All-zero block (sum == 256): end-of-archive padding. Skip it.
		if sum <= 256 then
			pos += BLOCK
			continue
		end

		if sum ~= octalAt(b, base + 148, 8) then
			return nil, `tar: bad header checksum at offset {base}`
		end

		local size = octalAt(b, base + 124, 12)
		local dataStart = base + BLOCK
		if dataStart + size > len then
			return nil, "tar: truncated archive (entry body past end of data)"
		end

		local body = readstring(b, dataStart, size)
		pos = dataStart + ceil(size / BLOCK) * BLOCK

		local flag = readstring(b, base + 156, 1)

		if flag == "L" then
			longName = nulcut(body) -- GNU long name for the next entry
			continue
		elseif flag == "K" then
			continue -- GNU long link name; irrelevant to the tree
		end

		-- Entry name: pending long name wins, else name (+ ustar prefix).
		local name: string
		if longName then
			name = longName
			longName = nil
		else
			name = nulcut(readstring(b, base, 100))
			local prefix = nulcut(readstring(b, base + 345, 155))
			if prefix ~= "" then
				name = prefix .. "/" .. name
			end
		end

		local parts = split(name)
		local n = #parts
		if n == 0 then
			continue -- "." / "/" style entry, nothing to place
		end

		if flag == "5" then
			getDir(parts, n) -- directory entry
		elseif flag == "0" or flag == "\0" or flag == "7" then -- file / contiguous
			local parent = getDir(parts, n - 1)
			if parent then
				local leaf = parts[n]
				local fileNode: FileNode = {
					type = "file",
					name = leaf,
					path = if parent.path == "" then leaf else parent.path .. "/" .. leaf,
					size = size,
					mode = octalAt(b, base + 100, 8),
					mtime = octalAt(b, base + 136, 12),
					data = body,
				}
				parent.children[leaf] = fileNode
			end
		end
		-- other typeflags (links, devices, pax headers) are ignored
	end

	return root, nil
end

return readTar
