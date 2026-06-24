--[[

The schema for a valid file system, this exists to allow VFS' in the future

https://docs.kernel.org/filesystems/vfs.html

]]

type FileHandle = string

export type FileSystemSchema = {

	Open: (self: FileSystemSchema, Path: string, AccessorId: number) -> FileHandle,
	Close: (self: FileSystemSchema, FileHandle: FileHandle) -> (),
}
