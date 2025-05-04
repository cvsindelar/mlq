help([==[

Description
===========
Defines the mlq Bash function by sourcing a script.


More information
================
 - Homepage: https://github.com/cvsindelar/mlq
]==])

whatis([==[Description: Module Loader-Quick (for lmod)]==])
whatis([==[Homepage: https://github.com/cvsindelar/mlq]==])
whatis([==[URL: https://github.com/cvsindelar/mlq]==])

local root = "/vast/palmer/apps/avx2/software/mlq/1.21"

conflict("mlq")

prepend_path("CMAKE_PREFIX_PATH", root)
setenv("EBROOTMLQ", root)
setenv("EBVERSIONMLQ", "1.1")
setenv("EBDEVELMLQ", pathJoin(root, "easybuild/mlq-1.21-easybuild-devel"))

-- Built with EasyBuild version 4.9.4

local script = pathJoin(root, "mlq.sh")
execute {cmd="source " .. script .. " --mlq_load " .. myModuleFullName() .. " " .. myFileName(), modeA={"load"}}
execute {cmd="source " .. script .. " --mlq_unload", modeA={"unload"}}

