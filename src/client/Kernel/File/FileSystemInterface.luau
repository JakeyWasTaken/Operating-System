--[[
	The schema for a virtual file system.

	This exists to hopefully in the future facilitate user space virtual file systems

]]

const Result = require("@core/Result")
const Signal = require("@core/Signal")
const FileContext = require("@kernel/File/FileContext")
const CFilePath = require("@kernel/File/FilePath")

type Result<T> = Result.Result<T>
type Signal<T...> = Signal.Signal<T...>
type FileContext = FileContext.FileContext
type CFilePath = CFilePath.CFilePath
type FileHandle = string
type PID = number

export type NodeMetadata = {
	CreatedAt: number, -- This should be a UNIX time stamp
}

export type INode = {
	GetHandle: (self: INode) -> string,

	--- Metadata about this node.
	GetMetadata: (self: INode) -> NodeMetadata,

	GetName: (self: INode) -> string,
	GetPath: (self: INode) -> CFilePath,
	GetParent: (self: INode) -> IDirectory?,

	SetName: (self: INode, Name: string) -> (),

	IsDirectory: (self: INode) -> boolean,
	IsFile: (self: INode) -> boolean,
	IsRoot: (self: INode) -> boolean,

	--- No-op on the root node, which cannot be re-parented.
	SetParent: (self: INode, Parent: IDirectory?) -> (),

	--- Whether this node is currently locked by a running process.
	IsLocked: (self: INode) -> boolean,

	--- Detaches this node from its parent.
	---
	--- Returns false (and does nothing) on the root node, or on a node that is currently locked.
	Delete: (self: INode) -> boolean,
}

export type IFile = {
	Read: (self: IFile) -> string,
	Write: (self: IFile, Data: string, Offset: number?) -> (),

	--- Returns file size in bytes.
	GetSize: (self: IFile) -> number,

	--- Metadata about this file.
	GetMetadata: (self: INode) -> NodeMetadata & { UpdatedAt: number --[[ This should be a UNIX time stamp ]] },
} & INode

export type IDirectory = {
	GetChildren: (self: IDirectory) -> { INode },
} & INode

export type IFileSystem = {
	--- Fired with a node's handle once it has been created.
	OnNodeCreated: Signal<FileHandle>,
	--- Fired with a node's handle once it's been deleted.
	OnNodeDeleted: Signal<FileHandle>,

	ResolvePath: (self: IFileSystem, Path: CFilePath, Context: FileContext) -> INode?,
	ResolveHandle: (self: IFileSystem, Handle: FileHandle) -> INode?,

	--- Creates a file at the given path.
	---
	--- Fails in these cases:
	--- - File already exists
	--- - Directory to file doesn't exist
	CreateFile: (self: IFileSystem, Path: CFilePath, Context: FileContext) -> Result<IFile>,

	--- Creates a directory at the given path.
	---
	--- Creates any missing intermediate directories.
	---
	--- Fails in these cases:
	--- - Provided path points to a file
	CreateDirectory: (self: IFileSystem, Path: CFilePath, Context: FileContext) -> Result<IDirectory>,

	--- Deletes the node at the given handle, along with any descendants.
	---
	--- Fails if the node, or any descendant, is locked.
	DeleteNode: (self: IFileSystem, NodeHandle: FileHandle) -> boolean,

	LockNode: (self: IFileSystem, NodeHandle: FileHandle, PID: PID) -> (),
	UnlockNode: (self: IFileSystem, NodeHandle: FileHandle, PID: PID) -> (),

	--- Releases every lock held by the given PID.
	ReleaseProgramLocks: (self: IFileSystem, PID: PID) -> (),
}

return true
