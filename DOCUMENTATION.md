# Osiris Documentation

This document covers two layers of the project:

- **[Kernel](#kernel)** - the actual engine the OS runs on: boot sequence, processes, the
  scheduler, the virtual file system, scripts/environments, windows, and users. This is all
  Roblox-side code under `src/client/Kernel`.
- **[Runtime](#runtime)** - what a *program* (a `.luau` file running as a process) sees: the
  sandboxed globals, the standard libraries available via `require("@osiris/...")`, path
  resolution rules, and the userspace tools already built (the shell, `nano`, `load`, etc).

If you're trying to understand how the OS works internally, read Kernel.

If you're trying to write a program that runs on it, read Runtime.

---

## Kernel

### Boot sequence

Everything starts from [`Bootstrapper.client.luau`](src/client/Bootstrapper.client.luau), which
runs these steps in order:

1. `PrepareBootInterface` - mounts the boot status screen (`BootInterface`) so subsequent steps
   can push status lines to it.
2. `PrepareWindowInput` - wires `UserInputService` into the window system (see
   [Windows](#windows)).
3. `PrepareFileSystem` - creates the active `CFileSystem` and recursively copies everything under
   `Static/` (synced in via Rojo as `ModuleScript`s, see [Static build](#static-build)) into it.
4. `RunTests` - spawns the test suite (`/tests/vm/...`, `/tests/core/...`,
   `/tests/kernel/...`) as real processes and reads their stdout. If anything fails, boot stops
   here - the OS refuses to come up on a broken kernel.
5. `MakeUser` - creates a single elevated user named after the Roblox player's display name, with
   `/users/<name>/home` and `/users/<name>/bin` directories.
6. `PrepareMainInterface` - switches the active interface from the boot screen to the windowed
   desktop.
7. `PrepareInit` - spawns `/system/bin/main.luau` (PID assigned, elevated) as **init**, the first
   real process. Everything else - the shell, services - descends from it.

### Processes

A process is a [`CProcess`](src/client/Kernel/Process/Process.luau): a PID, an environment map, an
argument list, a `FileContext` (cwd/home), three `IOStream`s (`StdIn`/`StdOut`/`StdErr`), and a
table of process-scoped handles (see [Handles](#handles)).

[`ProcessFactory`](src/client/Kernel/Process/ProcessFactory.luau) is the only thing that may
construct or destroy a `CProcess` (enforced by an assertion in non-shipping builds).
`ProcessFactory.CreateProcess(ProgramPath, Environment, Arguments, FileContext)`:

1. Validates the environment table (string keys/values) and arguments (string array).
2. Resolves `ProgramPath` against the active file system using the given `FileContext` and
   confirms it's a file.
3. Allocates a PID, builds the `CProcess`, and compiles the file's contents into a
   [`CScript`](#scripts--environments).
4. Spawns the script's main thread on the [scheduler](#the-scheduler) and returns immediately -
   the caller gets back a `Result<CProcess>`, not something that blocks until the process exits.

`TerminateProcess(PID, ExitCode)` cascades to children first, detaches the process from its
parent, destroys its streams, and tells `ScriptFactory`, `ProcessScheduler` and `WindowFactory` to
clean up anything they're holding for that PID. Process trees are tracked purely by PID list
(`m_ChildPIDs`/`m_ParentPID`) - `SetParentProcess`/`DetachProcess` maintain that relationship and
are used by `process.Spawn`/`process.Detach` in userspace.

### The scheduler

[`ProcessScheduler`](src/client/Kernel/Process/ProcessScheduler.luau) is a cooperative, single
green-thread-at-a-time scheduler driven by `RunService.Heartbeat`. There is no OS thread per
process - every "thread" (a process's main script, or anything it `task.spawn`s) is a Luau
coroutine tracked in one flat table, keyed by an opaque thread ID.

Each tracked thread has a `State`:

- `Waiting` - eligible to run on the next `Tick`.
- `Running` - currently executing (only true mid-`Tick`).
- `Sleeping` - parked until `WakeAt` (backs `task.wait(seconds)`).
- `Blocked` - parked indefinitely until something calls `Unblock` (backs condition variables).
- `Suspended` - created but never resumed (backs `coroutine.create`, which shouldn't run until
  something calls `resume`).
- `Dead` - finished; swept and `coroutine.close`d on the next `Tick`.

`Tick()` snapshots the current thread IDs, then resumes every `Waiting` thread whose sleep has
elapsed. A thread can call `JumpExecution(ThreadId)` to yield itself back to `Waiting` and ask the
scheduler to run a specific other thread *immediately*, within the same `Tick` - this is how
`task.spawn` makes a freshly spawned thread appear to run synchronously up to its first yield, the
same way real Roblox `task.spawn` behaves.

`RunNonBlocking(fn)` runs `fn` with blocking disallowed for the duration of the call (tracked per
coroutine, re-entrant) - this is what guards window draw callbacks, which must never yield.
`IsBlockingAllowed()` is checked by `Sleep` and `ConditionVariable:Wait`, so calling `task.wait()`
or blocking on I/O from inside a draw callback raises immediately instead of hanging the renderer.

User-facing handles to threads (what `task.spawn` hands back, what `coroutine.create` hands back)
are opaque `newproxy(true)` values, not real Luau threads - scripts never get a raw `thread`
value they could use to escape the scheduler's bookkeeping. `Coroutine.luau` and `Task.luau`
under `Script/Environment/Interfaces` translate the real `coroutine`/`task` global APIs onto this
scheduler.

### File system

The virtual file system is a single in-memory tree, [`CFileSystem`](src/client/Kernel/File/FileSystem/init.luau),
managed by [`FileSystemManager`](src/client/Kernel/File/FileSystemManager.luau) (one active
instance at a time, set up by `PrepareFileSystem`). Nodes are either
[`CFile`](src/client/Kernel/File/FileSystem/Nodes/File.luau) (holds a raw `string` of contents) or
[`CDirectory`](src/client/Kernel/File/FileSystem/Nodes/Directory.luau) (holds child nodes), both
implementing the shared [`INode`](src/client/Kernel/File/FileSystemInterface.luau) interface
(name, parent, handle, metadata).

Every node gets a unique [`Handle`](#handles) when created; `CFileSystem.m_Handles` maps handle ->
node so that `ResolveHandle` is O(1) regardless of tree depth. `ResolvePath`/`CreateFile`/
`CreateDirectory` all walk the tree from `m_Root`, following [`CFilePath`](#path-resolution) parts
one segment at a time.

**Writing never truncates.** [`CFile:Write(Data, Offset)`](src/client/Kernel/File/FileSystem/Nodes/File.luau)
always *preserves* whatever was past `Offset + #Data` - it can overwrite in place or grow the
file, but it can never shrink it. To fully replace a file's contents (e.g. an editor's "save"),
you must delete and recreate it; there's no truncate primitive. `nano` (see
[Editor](#nano--editor)) does exactly this.

**Locking.** [`NodeLocks`](src/client/Kernel/File/FileSystem/NodeLocks.luau) tracks an exclusive
lock per (PID, handle) pair. `fs.Open(Path, Exclusive)` takes a lock if `Exclusive` is true;
`DeleteNode` and a second exclusive `Open` both fail while a node (or any of its descendants, for
a directory) is locked. Locks are released by `Close`, or en masse when a process terminates
(`ReleaseProgramLocks`).

#### Path resolution

[`CFilePath`](src/client/Kernel/File/FilePath.luau) parses a path string into a root type -
`Root` (`/...`), `Home` (`~/...`), or `Relative` (`./...`, `../...`, or a bare name with **no**
prefix at all, e.g. `foo/bar`) - plus a list of parts (`Enter "name"` or `Escape` for `..`).
`CFilePath:Resolve(Context)` turns any of these into an absolute, `Root`-rooted path:

- `Root` paths pass through unchanged.
- `Home` paths are combined with `Context.HomeDirectory`.
- `Relative` paths (including bare names) are combined with `Context.WorkingDirectory`.

**Important inconsistency to know about:** this `WorkingDirectory`-based resolution is what the
`fs` library uses for every operation (so `cd`-style working directories behave exactly as you'd
expect from a shell). But relative `require()` calls and `process.Spawn`'s `ProgramPath` resolve
against the *calling/spawning script's own directory* instead (see
[`Require.luau`](src/client/Kernel/Script/Environment/Interfaces/Require.luau) and
[`LibProcess.luau`](src/client/Kernel/Script/Environment/Libraries/LibProcess.luau)) - the same
convention Node's `require()` uses for relative imports. This is intentional (a program spawning
a sibling helper script next to itself shouldn't have to care what the caller's cwd happens to
be), but it means **a bare filename means two different things** depending on whether you pass it
to `fs.*` or to `require`/`process.Spawn`. When in doubt, build an absolute path yourself (see
`$PWD`, below) rather than relying on either implicit resolution.

### Scripts & environments

A [`CScript`](src/client/Kernel/Script/Script.luau) wraps one file's source, compiled bytecode,
and (once run) its return values. [`ScriptFactory`](src/client/Kernel/Script/ScriptFactory.luau)
caches scripts per `(PID, FileHandle)` pair so `require()`-ing the same file twice within one
process returns the cached module instead of re-running it (this is also what makes circular
`require()`s resolve instead of infinitely recursing).

`Compile()` runs the source through the vendored `LuauCeptionCompiler` to bytecode. `Run()` builds
a fresh sandboxed environment via [`EnvironmentFactory.CreateEnvironment`](src/client/Kernel/Script/Environment/EnvironmentFactory.luau)
(see [Runtime](#runtime) for what that environment contains) and loads the bytecode against it
through the vendored `Fiu` interpreter, with `errorHandling = false` (errors propagate as real
Luau errors, caught by the scheduler) and `allowProxyErrors = true`.

Each process's scripts share a `SharedTable` (the `_G`/`shared` global) keyed by PID, released
when the process terminates.

### Windows

[`CWindow`](src/client/Kernel/Window/Window.luau) is a logical window: focus/minimized/fullscreen
flags, a Z-index, an owner PID, a draw callback, and an `InputContext` (signals + queries scoped
to that window). [`WindowFactory`](src/client/Kernel/Window/WindowFactory.luau) owns the set of
live windows and enforces **single focus**: `SetFocused(Handle, true)` automatically un-focuses
whatever window was previously focused (firing `WindowFocusReleased` on it and `WindowFocused` on
the new one) before focusing the requested one. `BringToTop` bumps a window's Z-index above every
window created so far, which is how a newly opened window visually covers others.

[`WindowInput.luau`](src/client/Kernel/Window/WindowInput.luau) is the only thing connected to the
real `UserInputService`; it forwards every input event to *every* window's `DigestInput`, and each
window only actually fires its own `InputContext` signals if it's currently focused. This is why a
background window's input hooks (e.g. the shell's history navigation) silently stop firing the
moment another window takes focus - the input still reaches `CWindow:DigestInput`, it just gets
swallowed by the `if not self.m_Focused then return end` guard.

Rendering is handled by the vendored immediate-mode UI library, JustDrawIt (`vendor/JustDrawIt`):
[`MainInterface`](src/client/Kernel/Interface/Interfaces/MainInterface/init.luau) draws one
[`Window` component](src/client/Kernel/Interface/Interfaces/MainInterface/Components/Window.luau)
per live `CWindow`, which calls the window's draw callback through
`ProcessScheduler.RunNonBlocking` (draw callbacks must not yield) and falls back to an in-place
error message if the callback throws or doesn't return a VNode.
[`InterfaceManager`](src/client/Kernel/Interface/InterfaceManager.luau) is what actually mounts
either `BootInterface` (during boot) or `MainInterface` (after boot) into a `ScreenGui`.

### Users

[`UserRegistry.MakeUser(Name, Elevated)`](src/client/Kernel/User/UserRegistry.luau) creates
`/users/<name>`, `/users/<name>/home` and `/users/<name>/bin`, and registers a `User` record (a
monotonic ID, a name, an elevated flag). Today exactly one user is created at boot, named after
the Roblox player. There's no login/permission-check layer beyond the elevated flag on processes
themselves (see `process.GetPermissions`).

### Services

Init (`/system/bin/main.luau`) reads every `*.service` file in `/system/services`, parses it as
TOML, and supervises it: spawns `Exec` with the given `Arguments`/`Environment` and `Elevated =
true`, and if `AutoRestart` is set, respawns it after `Delay` seconds whenever it exits - up to 5
restarts within a 10-second window, after which it gives up and logs that the service "keeps
crashing."

```toml
[Service]
Name = "Shell Service"

[Process]
Exec = "../bin/Shell/main.luau"
Arguments = ["A", "B"]
Delay = 0
AutoRestart = true

[Process.Environment]
A = "B"
```

`Exec` is resolved relative to `/system/services` unless it starts with `/`.

### Handles

[`Handle()`](src/client/Core/Handle.luau) generates a unique opaque string ID, used everywhere
something needs an identity that can be handed to userspace without exposing the real object: file
nodes, windows, and per-process *scoped* handles. A process never sees a raw file/window handle -
`CProcess:CreateScopedHandle(GlobalHandle)` mints a process-local handle and remembers the mapping,
so closing/destroying always goes through `GetGlobalHandle(ScopedHandle)` first. This is what
stops one process from guessing another process's handle and using it.

### Static build

Everything under `Static/` is synced into Roblox via Rojo as `ModuleScript`s (see
`scripts/build-static.luau`), each wrapped as `return { Name = "...", Contents = "..." }` so the
original filename/extension survives even though Rojo requires `.luau` for module scripts.
`PrepareFileSystem` walks that folder tree and recreates it 1:1 inside the virtual file system -
so editing a file under `Static/bin/foo.luau` and rebuilding is how you ship a new program at
`/bin/foo.luau` in the booted OS.

---

## Runtime

This section is for writing programs that run *on* Osiris (anything under `Static/`, which ends up
at the matching absolute path once booted).

### The sandboxed environment

Every running script gets a fresh table built by
[`EnvironmentFactory.CreateEnvironment`](src/client/Kernel/Script/Environment/EnvironmentFactory.luau).
It is **not** the real Luau global environment - it's an explicit allowlist:

| Global | Notes |
| --- | --- |
| `print(...)` | Writes the concatenated arguments **plus a trailing `\n`** to the process's stdout, then calls the real `print` (visible in the Studio console). |
| `warn(...)` | Same as `print`, but to stdout via the real `warn` (see the [`stdio`](#stdio) caveat below - `warn` historically writes to *stdout*, not stderr). |
| `error(Message, Level?)` | Writes `tostring(Message) .. "\n"` to **stderr**, then raises normally. |
| `exit(ExitCode)` | Terminates the calling process with the given exit code. There is no implicit exit code on falling off the end of a script - if your program needs to keep its window alive, it must loop (`while true do task.wait() end`) or it terminates (and any windows it owns are destroyed) as soon as the script returns. |
| `type` / `typeof` | Same as built-in, except they report `"thread"` for the scheduler's opaque thread handles. |
| `require(Target)` | See [require() rules](#require-rules) below. |
| `task.wait/spawn/defer/delay/cancel`, bare `wait`/`spawn` | Backed by the [scheduler](#the-scheduler), not the real `task` library. |
| `coroutine.create/resume/status/wrap/close/running` | Backed by the scheduler; `yield`/`isyieldable` are the real builtins (the scheduler doesn't need to intercept those). |
| `_G` / `shared` | A table private to the *process* (shared across every script that process runs, via `require`), not global to the whole OS. |
| `_VERSION` | The literal string `"Osiris"`. |
| `getfenv`, `setfenv`, `loadstring` | Present but always `error(...)` - explicitly disabled. |

Everything else you'd expect from stock Luau is passed through unmodified: `string`, `table`,
`math`, `bit32`, `utf8`, `os`, `debug`, `buffer`, `vector`, `assert`, `pcall`/`xpcall`, `pairs`/
`ipairs`, etc. - plus the Roblox datatypes needed for the `window` library's draw callbacks
(`Vector2`/`Vector3`, `CFrame`, `UDim`/`UDim2`, `Color3`, `Enum`, `Font`, `ColorSequence`, and so
on).

There is **no** `game`, no `workspace`, no `Instance.new`, no direct Roblox service access at all.
Anything that needs to reach the engine goes through one of the libraries below.

### require() rules

- `require("@osiris/<name>")` loads a kernel-exposed library (see [Libraries](#libraries)). Each
  process gets its own cached instance per library name, created on first use.
- `require("/absolute/path.luau")` or `require("~/home/path.luau")` loads a file by absolute or
  home-relative path.
- `require("./sibling.luau")` or `require("bare-name.luau")` loads a file relative to **the
  requiring script's own directory** - not the process's working directory (see the
  [path resolution callout](#path-resolution) above). **The extension is mandatory** for relative
  requires - `require("./Parser")` fails; it must be `require("./Parser.luau")`.

A required module must `return` exactly one value; anything else is a hard error.

### Libraries

All of these are loaded via `require("@osiris/<name>")`. Every fallible call follows the same
convention: it returns `(Result?, ErrorString)` - check the first value, the second is only
meaningful when the first is falsy.

#### `fs`

File system access, rooted at the same virtual tree the shell sees. Paths resolve against the
process's `WorkingDirectory`/`HomeDirectory` (see [path resolution](#path-resolution)).

| Function | Signature |
| --- | --- |
| `CreateFile` | `(Path: string) -> (boolean?, string)` |
| `CreateDirectory` | `(Path: string) -> (boolean?, string)` (creates missing intermediate directories) |
| `Delete` | `(Path: string) -> (boolean?, string)` (recursive; fails if anything under it is locked) |
| `List` | `(Path: string) -> ({ {Name: string, IsDirectory: boolean} }?, string)` |
| `Open` | `(Path: string, Exclusive: boolean?) -> (ScopedHandle: string?, string)` |
| `Close` | `(ScopedHandle: string) -> (boolean?, string)` |
| `Read` | `(ScopedHandle: string) -> (string?, string)` |
| `Write` | `(ScopedHandle: string, Data: string, Offset: number) -> (boolean?, string)` - **never truncates**, see the file-system section above |
| `GetMetadata` | `(ScopedHandle: string) -> ({CreatedAt: number, UpdatedAt: number}?, string)` |
| `GetName` / `Rename` / `Move` | as named |

#### `process`

| Function | Signature |
| --- | --- |
| `GetPID` | `() -> number` |
| `GetArguments` | `() -> {string}?, string` |
| `GetEnvironment` | `() -> {[string]: string?}?, string` |
| `GetPermissions` | `() -> {Elevated: boolean}?, string` |
| `GetParentPID` / `GetChildPIDs` | as named |
| `Spawn` | `(ProgramPath: string, Environment, Arguments, Options: {FileContext?, ForwardStdIO?: boolean, Elevated?: boolean}) -> ({PID, StdIn, StdOut, StdErr, Status: () -> number}?, string)` |
| `Terminate` | `(PID: number, ExitCode: number) -> (boolean?, string)` - only on yourself or a direct child |
| `Detach` | `(PID: number) -> (boolean?, string)` - unlinks a child without killing it |

`Spawn`'s `ProgramPath` resolves relative to **your own script's directory**, not your working
directory - see the [path resolution callout](#path-resolution). `ForwardStdIO = true` pipes the
child's stdout/stderr straight into your own (this is how `run`'s output reaches the shell without
manually relaying it).

#### `window`

Opens an actual window on the desktop with a draw callback (using the vendored JustDrawIt
immediate-mode UI library, exposed as `window.Graphics.Create`) and a scoped `InputContext`.

| Function | Notes |
| --- | --- |
| `Create()` / `Destroy(Handle)` | |
| `SetDrawCallback(Handle, fn)` | `fn` returns a VNode (`window.Graphics.Create("ClassName")({ ...properties... })`) and **must not yield**. |
| `SetFocused` / `IsFocused` | Focusing steals focus from whatever else was focused (see [Windows](#windows)). |
| `SetMinimized` / `IsMinimized`, `SetFullscreen` / `IsFullscreen` | |
| `GetSize` / `GetPosition` / `BringToTop` | |
| `GetInputContext(Handle)` | Returns signals (`InputBegan`/`InputChanged`/`InputEnded`, `LastInputTypeChanged`, `WindowFocused`/`WindowFocusReleased`) and queries (`IsKeyDown`, `GetMouseLocation`, `GetKeysPressed`, etc.), all scoped to *this* window's focus state. |

Two real engine gaps to know about if you're building UI: this build has no
`Enum.AutomaticCanvasSize` (the property exists on `ScrollingFrame`, but its *value* type is
`Enum.AutomaticSize`, not a separate enum - that's the whole fix, not a missing feature), and
`Enum.AutomaticSize` itself works fine on ordinary `GuiObject`s.

#### `stdio`

Raw output, without the auto-appended newline that `print`/`warn` add (see the table above). Use
this when you need exact control over what hits the stream - building a line across several
calls, a progress indicator, etc.

| Function | Signature |
| --- | --- |
| `StdOut` | `(...: any) -> (boolean?, string)` - writes the concatenated arguments verbatim, also calls the real `print` |
| `StdError` | `(...: any) -> (boolean?, string)` - writes verbatim to stderr, also calls the real `warn` |

#### `network`

Thin wrapper over `HttpService` (requests are actually proxied through a server `RemoteFunction`,
since the sandbox has no direct service access).

| Function | Signature |
| --- | --- |
| `RequestAsync` | `(Options: {Url, Method?, Headers?, Body?, Compress?, Timeout?}) -> {Success, StatusCode, StatusMessage, Headers, Body}` |
| `JSONEncode` / `JSONDecode` | as named |
| `UrlEncode` | `(Data: string) -> string` |
| `GenerateGUID` | `(WrapInCurlyBraces: boolean) -> string` |

#### `encoding`

Buffer/compression/hashing primitives, plus a tar archive reader.

| Function | Signature |
| --- | --- |
| `Base64Encode` / `Base64Decode` | `(buffer) -> buffer` |
| `CompressBuffer` | `(Input: buffer, Algorithm: Enum.CompressionAlgorithm, Level: number?) -> buffer` |
| `DecompressBuffer` | `(Input: buffer, Algorithm: Enum.CompressionAlgorithm) -> buffer` |
| `GetDecompressedBufferSize` | `(Input: buffer, Algorithm) -> number?` |
| `ComputeBufferHash` / `ComputeStringHash` | `(Input, Algorithm: Enum.HashAlgorithm) -> buffer/string` |
| `OpenTar` | `(Input: buffer) -> TarNode` - parses a raw tar archive into a tree of `{type: "file", name, path, size, data, ...}` / `{type: "directory", name, path, children}` nodes |

#### `toml`

| Function | Signature |
| --- | --- |
| `Parse` | `(Source: string) -> ({[string]: any}?, string)` |

#### First-party userspace libraries (`/system/lib`)

Not kernel libraries - just plain modules under `/system/lib`, required by absolute path
(`require("/system/lib/Ansi.luau")`). Anyone can add more the same way.

- **`Ansi.luau`** - ANSI SGR escape helpers (`Ansi.Style(text, "Red", "Bold")`, `Ansi.Rgb(r,g,b)`)
  and `Ansi.ToRichText(text)`, which converts a string containing ANSI escapes into Roblox
  RichText markup. The shell calls this once per frame on its scrollback buffer so colored
  command output (`ls`, `colors`, etc.) renders correctly. Literal text is always HTML-escaped, so
  output that knows nothing about formatting still displays safely.
- **`Args.luau`** - a small getopt-style parser. `Args.Parse(process.GetArguments(), Spec)` where
  `Spec` is a list of `{Name, Short?, Long?, TakesValue?, Default?, Required?}`, returning
  `{Options, Positionals}`. Supports `-f`, clustered `-abc`, `-o value`/`-ovalue`, `--flag`,
  `--key value`/`--key=value`, and `--` to stop flag parsing.

### Programs

Programs live at `/bin/*.luau` (and `/users/<name>/bin`, once that's wired into `$PATH`-style
resolution - today the shell only searches `/bin`). The shell resolves a bare command name by
checking `/bin/<name>` and `/bin/<name>.luau`, in addition to absolute/relative paths typed
directly. Heavier programs follow the convention established by the shell and `nano`: keep a thin
entry script in `/bin`, and put the real implementation in `/system/bin/<Program>/`, required by
absolute path.

**`$PWD`**: the shell sets a `PWD` environment variable to its current working directory on every
program it spawns, specifically so a program can build absolute paths itself rather than relying
on either of the two different "relative" conventions described in
[path resolution](#path-resolution). `run` and `nano` both do this:

```lua
local PWD = (process.GetEnvironment() or {}).PWD or "/"
local Absolute = if Raw:sub(1, 1) == "/" then Raw elseif PWD == "/" then `/{Raw}` else `{PWD}/{Raw}`
```

Built-in programs so far:

- **`ls`, `cat`, `echo`, `mkdir`, `touch`, `rm`** - the obvious things, colorized via `Ansi` where
  it helps (directories in `ls`, errors in red).
- **`run [-a] file.luau [file2.luau ...]`** - runs one or more files. Sequentially by default
  (waits for each to exit before starting the next); pass `-a` to spawn them all concurrently and
  await them together. Exits non-zero if anything failed.
- **`nano <file>`** ([`Editor.luau`](#nano--editor)) - a full-screen text editor.
- **`load`** - loads `.tar.zst` archives onto the file system; see the dedicated section below.

#### `nano` / Editor

`/bin/nano.luau` is a thin entry point - it validates the file argument, resolves it against
`$PWD`, and calls `Editor.Open(Path)` from `/system/bin/Nano/Editor.luau`, which is the real
implementation. Opening it creates a new fullscreen window, steals focus, and brings itself to the
top of the Z-order (see [Windows](#windows)).

- The editing surface is a `MultiLine` `TextBox` inside a `ScrollingFrame`, so Roblox handles
  caret movement and line wrapping, and the frame handles scrolling for documents taller than the
  window.
- **Ctrl+S** saves; **Ctrl+X** exits. Since `fs.Write` never truncates, saving deletes and
  recreates the file before writing the new contents, rather than overwriting in place - the only
  way to correctly handle the buffer shrinking.
- The whole UI is inset 58px from the top of the window to clear Roblox's own top bar.
- `Editor.Open` blocks (`while not Closed do task.wait() end`) until Ctrl+X, exactly like the
  shell's main loop - letting the script return early would terminate the process (and destroy
  its own window) immediately.

### Using `load` to install `.tar.zst` archives

`load` decompresses a Zstandard-compressed tar archive and writes its contents onto the file
system. The data itself is passed in as a base64 string - either inline, or fetched from a URL.

| Flag | Meaning |
| --- | --- |
| `-a <type>` | Archive type. Only `tar` is supported. |
| `-c <type>` | Compression type. Only `zstd` is supported. |
| `-d <data>` | The base64-encoded archive data, or (with `-n`) a URL to fetch it from. |
| `-o <path>` | Where to extract to. Defaults to the working directory. |
| `-n` | When present, `-d` is treated as a URL instead of inline data - `load` fetches it via `network.RequestAsync` first. |

Inline data:

```sh
load -a tar -c zstd -d "<base64 .tar.zst contents>"
```

From a URL (note `-n` is a bare flag, no value):

```sh
load -a tar -c zstd -n -d "https://example.com/path/to/archive.tar.zst"
```

Extract into a specific directory instead of the cwd:

```sh
load -a tar -c zstd -o /home/projects -d "<base64 .tar.zst contents>"
```

Internally: the base64 string is decoded to a `buffer`, decompressed with
`encoding.DecompressBuffer` (capped at 1GB decompressed - `load` refuses anything larger), then
parsed with `encoding.OpenTar` into a tree of directory/file nodes. `load` walks that tree,
creating every directory first and then every file (each file write reports its size), prefixing
`-o` onto every path if it was given.

To compress a directory into the needed type you must do the following steps:

- Archive with tar (7Zip or other)
- Compress with zstd (CLI or other)
- Convert to base64

**Do not convert to base64 in an online tool, opening the file in a notepad or other will likely destroy the file bytes, making it unable to load. This is achievable via powershell with the following command**

`[Convert]::ToBase64String([IO.File]::ReadAllBytes("C:\Absolute\Path\To\File.tar.zst")) | Set-Content -NoNewline b64compressed.txt`

Example workflow

- Archive -> 7Zip, Archive type set to .tar GNU
- Compress -> CLI, `zstd -T0 -19 "archive.tar"`
- Base64 -> Powershell, `[Convert]::ToBase64String([IO.File]::ReadAllBytes("W:\archive.tar.zst")) | Set-Content -NoNewline b64compressed.txt`
