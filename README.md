# mlq
Module Loader-Quick (for lmod)

# What it's for

Under certain circumstances, loading of certain modules or module combinations within the [lmod](https://lmod.readthedocs.io/en/latest/) system can become tedious and slow. ``mlq`` can accelerate the loading of such environments from 20 or more seconds down to two or three seconds. ``mlq`` works as a layer on top of the `lmod` system and works seamlessly together with it.

# Installation and Use

There are three main ways to use `mlq`:
1. <b>EasyBuild</b> : If EasyBuild is available on your system, build with `eb <mlq-x.x.eb>`; `mlq` is then available with`ml mlq`.
2. <b>Free-standing function</b> : You may also source `mlq.sh`, which defines the `mlq` function but without additional module functionality.
3. <b>Simple version:</b> Use `source mlq_simple.sh` to enable the `mlsq` function with 10x fewer lines of code, but 90% functionality.

After installation, type `mlq` or `mlsq` for preliminary help and you are on your way!

<b>Module consistency checker</b> : Loading `mlq` also loads a function called `mlq_check` which checks for version consistency among a given set of modules and their dependencies. To use it, do:
```
# No arguments: checks the loaded module environment
mlq_check

# Specified set of modules (be sure to specify precise versions):
mlq_check <mod1/v1> <mod2/v2> ...
  ```

<b>Sharing shortcuts</b> : Shortcuts may be saved for global sharing with other users through a directory called `mlq_prebuilds` located in the same place as `mlq.sh`, i.e.:
```
# Easybuild
mkdir -p $EBROOTMLQ/mlq_prebuilds
cp -R -L ~/.mlq/mlq/<shortcut_dir> $EBROOTMLQ/mlq_prebuilds

# mlq function
mkdir -p <path-to-mlq.sh>/mlq_prebuilds
cp -R -L ~/.mlq/mlq/<shortcut_dir> <path-to-mlq.sh>/mlq_prebuilds

# mlsq function
mkdir -p <path-to-mlq_simple.sh>/mlq_simple
cp -R -L ~/.mlq/mlq_simple/<shortcut.lua> <path-to-mlq_simple.sh>/mlq_simple
```
Shortcuts in these locations will be linked to the user cache automatically the first time a user loads the `mlq` function, or may be added thereafter with the `--prebuild` option. For `mlsq`, the global shared shortcuts are always visible.

# How it works

`mlq` works with lmod module system so you can create and use custom-built
   `shortcut` modules to accelerate the loading of large and complex
   module environments,

  Shortcut (`mlq`) modules are intended to be used by themselves, without
   other modules. When you load a shortcut with `mlq`, a `module reset` is
   automatically performed before loading the shortcut, removing any previously
   loaded modules. Likewise, if you use `mlq` to load an ordinary module on top
   of a shortcut, the shortcut is automatically deactivated,

  Any command that works with `ml` should also work with `mlq`
   (any call not to do with `mlq` shortcuts gets passed straight through to `ml`),

  A shortcut module works by doing dependency checking only once, during
   shortcut building. It then caches the original lua code for one or more modules
   and all the modules they depend on, minus the `depends_on()`
   statements, and faithfully executes this code in same order that lmod would.
   Rapid dependency checking is then done during shortcut loading as follows:
   `mlq` detects if any of the involved module files changes, or even if a single modification
   date changes. If so, then `mlq` uses lmod to automatically rebuild the shortcut
   (the user is prompted to rebuild the shortcut in the interactive case);
   failing that, the shortcut falls back to ordinary module loading.

  `mlq` is designed to work with 'well-behaved' modules;
   that is, where there are no version conflicts between the modules
   that a shortcut depends on. Strict checking of the modulefile tree 
   is done to enforce this***.
   In some cases a conflict may be detected that can be safely ignored. 
   If you are able to confidently establish that reported conflicts can
   be ignored, `--unsafe_build`     can be used, which bypasses these safety checks.

*** Checking is done by screening `depends_on()` statements in the
     modulefile lua codes.

