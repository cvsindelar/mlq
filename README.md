# mlq
```
Module Loader-Quick (for lmod)               (__)
                                             (@@)
                                      /##--##-\#)
                                     / ###  #||  
                                    *  ||ww--||  
                                       ^^    ^^
```
# What it's for
Under certain circumstances, loading of certain modules or module combinations within the [lmod](https://lmod.readthedocs.io/en/latest/) system can become tedious and slow. `mlq` is a bash function that can accelerate the loading of such environments, especially when the original load times start to exceed 10 seconds; speed-up factors can reach 20-fold. ``mlq`` works as a layer on top of the `lmod` system and works seamlessly together with it.

Example use cases:
```
ml mlq                    # Loads the mlq module
ml -e                     # Lists existing shortcuts
ml -b R/4.4.1-foss-2022b  # Build a shortcut for R/4.4.1-foss-2022b
ml R/4.4.1-foss-2022b     # Loads the R shortcut
ml miniconda              # (if no 'miniconda' shortcut) uses lmod 'ml' to load the miniconda module
ml reset                  # Unloads all modules- including shortcuts- except for mlq, which stays loaded
module reset              # Unloads all modules as well as mlq
```

# Installation and Use

There are two ways to use `mlq`:
1. **As an lmod module**

    <u>*EasyBuild*</u> : If [EasyBuild](https://www.google.com/url?sa=t&source=web&rct=j&opi=89978449&url=https://easybuild.io/&ved=2ahUKEwj5_N-z5YyNAxWyF1kFHczsKHQQFnoECAkQAQ&usg=AOvVaw2ZN6GWMilgwKsFcoVp0KX2) is available on your system, you can just build the mlq module with `eb <mlq-x.x.eb>`

    *Manual installation* : Clone the `mlq` git project into a suitable directory `<path-to-mlq>`. Then install the included modulefile into lmod , i.e. `cd <path-to-lmod-base-dir>/modules; mkdir all/mlq tools/mlq; cp <path-to-mlq>/mlq/1.21.lua all/mlq; ln -s $PWD/all/mlq/* tools/mlq`. Finally, *edit the following line* in `<path-to-lmod-base-dir>/modules/all/mlq/1.21.lua` so that it points to the right place:

    ```
    # Unedited: 
    # local root = "/vast/palmer/apps/avx2/software/mlq/1.21"
    # Edited:
    local root = "***<path-to-mlq>***/mlq/1.21"
    ```
    `mlq` should then available with`ml mlq`, although you may need to [update your lmod spider cache](https://lmod.readthedocs.io/en/latest/130_spider_cache.html) first.

2. **Simple version:** Use `source mlq_simple.sh` to enable the `mlsq` function with 10x fewer lines of code, but 90% functionality; the main purpose of this script (and accompanying `mlq_simple_build.sh`) is to succinctly demonstrate the underlying method used by `mlq` with just a few dozen lines of bash script.

After installation, type `ml` (or `mlsq`) for preliminary help and you are on your way!

**Sharing shortcuts** : Shortcuts may be saved for global sharing with other users through a directory called `mlq_prebuilds` located in the same place as `mlq.sh`, i.e.:
```
# mlq module installed with EasyBuild
mkdir -p $EBROOTMLQ/mlq_prebuilds
cp -R -L ~/.mlq/<shortcut_dir> $EBROOTMLQ/mlq_prebuilds

# mlq module installed manually
mkdir -p <path-to-mlq.sh>/mlq_prebuilds
cp -R -L ~/.mlq/<shortcut_dir> <path-to-mlq.sh>/mlq_prebuilds

# mlsq function uses a different directory and a simpler shortcut directory structure
mkdir -p <path-to-mlq_simple.sh>/mlq_simple
cp -R -L ~/mlq_simple/<shortcut.lua> <path-to-mlq_simple.sh>/mlq_simple
```

# Features

**Automatic shortcut rebuilding** : When loading a shortcut, `mlq` detects if it has become out of date, and rebuilds it if possible; if not, `mlq` falls back to the `lmod` `ml` command to load the original modules.

**Coordination between `mlq` and `module` functions** : `mlq` does not allow shortcut modules to coexist with ordinary `lmod` modules. When `mlq` loads a shortcut, a `module reset` is automatically performed to get rid of any loaded shortcut or other modules. `mlq` patches the `ml` command so it performs shortcut-related operations, but otherwise falls back to the original `lmod` `ml` function. However, the behavior of the `lmod` `module` command is not affected, so you can always load a module using ordinary `lmod` by doing `module load <mod>`.

**Module consistency checker** : Loading `mlq` also loads a function called `mlq_check` which checks for version consistency among a given set of modules and their dependencies. To use it, do:
```
# No arguments: checks the loaded module environment
mlq_check

# Specified set of modules (be sure to specify precise versions):
mlq_check <mod1/v1> <mod2/v2> ...
  ```

# How it works

`mlq` works with the `lmod` module system so you can create and use custom-built
   'shortcut' modules to accelerate the loading of large and complex
   module environments.

 For large and complex module environments, the lmod `module` function may spend most of its loading time 
 doing dependency checks. `mlq` works its magic by using a greatly streamlined dependency check during shortcut *loading*, 
    relegating costly dependency checks to the shortcut *building* step. During shortcut building, 
    a cache is built containing the original lua code for the specified modules as well as
    all the modules these depend on, minus the `depends_on()`
   statements. For shortcut loading, `mlq` faithfully executes this code in same order that an ordinary `module load` would.
   
   Rapid dependency checking during shortcut loading is accomplished as follows:
   `mlq` detects if any of the involved module files changes, or even if a single modification
   date changes. If so, then `mlq` uses the lmod `module` command to automatically rebuild the shortcut
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

