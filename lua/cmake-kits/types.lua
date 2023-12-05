--- @alias cmake-kits.Generator "Ninja" | "Ninja Multi-Config" | "Unix Makefiles"
--- @alias cmake-kits.BuildVariant "Debug" | "Release" | "MinSizeRel" | "RelWithDebInfo"
--- @alias cmake-kits.TargetType "EXECUTABLE" | "STATIC_LIBRARY"

--- @class cmake-kits.CmakeConfig
--- @field command string Path of the cmake executable.
--- @field generator cmake-kits.Generator Generator to use to build the project.
--- @field build_directory string Path where cmake will build the project.
--- @field compile_commands_path string? Path where compile_commands.json will be copied to.
--- @field configure_args string[] Arguments that will be passed when configuring the project.
--- @field build_args string[] Arguments that will be passed when building the specified target.

--- @class cmake-kits.CmakeConfigLocal : cmake-kits.CmakeConfig
--- @field source_directory string?

--- @class cmake-kits.Kit
--- @field name string
--- @field compilers cmake-kits.Compilers
--- @field isTrusted boolean

--- @class cmake-kits.UnspecifiedKit
--- @field name "Unspecified"
--- @field compilers nil
--- @field isTrusted nil

--- @class cmake-kits.KitsState
--- @field kits cmake-kits.Kit[]

--- @class cmake-kits.Configure
--- @field fresh boolean?
--- @field on_exit fun()?

--- @class cmake-kits.Build
--- @field on_exit fun()?

--- @class cmake-kits.Run
--- @field on_exit fun()?

--- @class cmake-kits.Test
--- @field on_exit fun()?

--- @class cmake-kits.Job
--- @field on_exit fun()?
--- @field target cmake-kits.Target?

--- @class cmake-kits.WindowStyle
--- @field row fun(): integer
--- @field col fun(): integer
--- @field width fun(): integer
--- @field height fun(): integer
--- @field border string[]

--- @class cmake-kits.WindowSettings
--- @field toggle string?
--- @field pos "bottom"|"center"
--- @field styles cmake-kits.WindowStyle
--- @field background string?
--- @field foreground string?

--- @class cmake-kits.SetupConfig : cmake-kits.CmakeConfig
--- @field configure_on_open boolean Automatic configuration of project. auto_root is required for this to work properly.
--- @field configure_on_save boolean Automatic configuration of project on CMakeLists.txt file save
--- @field terminal cmake-kits.WindowSettings?
