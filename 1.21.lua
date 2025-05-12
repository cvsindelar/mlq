help([==[

Description
===========
Module Loader-Quick (for lmod)

More information
================
 - Homepage: https://github.com/cvsindelar/mlq
]==])

whatis([==[Description: Module Loader-Quick (for lmod)]==])
whatis([==[Homepage: https://github.com/cvsindelar/mlq]==])
whatis([==[URL: https://github.com/cvsindelar/mlq]==])

local root = "/vast/palmer/apps/avx2/software/mlq/1.21"

conflict("mlq")

local script = pathJoin(root, "mlq.sh")
execute {cmd="source " .. script .. " --mlq_load " .. myModuleFullName() .. " " .. myFileName(), modeA={"load"}}
execute {cmd="source " .. script .. " --mlq_unload", modeA={"unload"}}

