# boilerplate

Standard development infrastructure and tooling to be used across repositories in an organization.

This work was inspired by, and partially cribbed from,
[lyft/boilerplate](https://github.com/lyft/boilerplate).

## Overview

The principle behind this is to **copy** the standardized artifacts from
this repository into the consuming repository. This is as opposed to
pulling them dynamically on each use. In other words, **consumers update
on demand.** It might seem like a *dis*advantage for consumers to be
allowed to get out of sync, but (as long as a system is in place to
check/update frequently) it allows more careful and explicit curation of
changes. The multiplication of storage space is assumed to be
insignificant. (Don't use this for huge binary blobs. If you need to
boilerplate a compiled binary or similar, consider storing the _source_
here and compiling it at the target via your `update`.)

## Mechanism

A "convention" lives in a subdirectory of `boilerplate` and is identified by
the subdirectory's name. For example, standard Makefile content lives
under `boilerplate/make` and is identified as `make`.

A convention comprises:

- Files, which are copied verbatim into the consuming repository at
  update time, replacing whatever was there before. The source directory
  structure is mirrored in the consuming repository -- e.g.
  `boilerplate/boilerplate/make/*` is copied into
  `${TARGET_REPO}/boilerplate/make/*`.
- An `update` script (which can be any kind of executable, but please
  keep portability in mind). If present, this script is invoked twice
  during an update:
  - Once _before_ files are copied, with the command line argument
    `PRE`. This can be used to prepare for the copy and/or validate that
    it is allowed to happen. If the script exits nonzero, the update is
    aborted.
  - Once _after_ files are copied, with the command line argument
    `POST`. This can be used to perform any configuration required after
    files are laid down. For example, some files may need to be copied
    to other locations, or templated values therein substituted based on the
    environment of the consumer. If the script exits nonzero, the update
    is aborted (subsequent conventions are not applied).

## Consuming

### Bootstrap

1. Copy the main [update script](boilerplate/update) into your repo as
   `boilerplate/update`. Make sure it is executable (`chmod +x`).

**Note:** It is important that the `update` script be at the expected
path, because one of the things it does is update itself!

2. Create a `Makefile` target as follows:

```makefile
.PHONY: update_boilerplate
update_boilerplate:
	@boilerplate/update
```

**Note:** It is important that the `Makefile` target have the expected
name, because (eventually) there may be automated jobs that use it
to look for available updates.

3. Commit the above.

### Configure

The `update` script looks for a configuration file at
`boilerplate/update.cfg`. It contains a list of conventions, which are
simply the names of subdirectories under `boilerplate`, one per line.
Whitespace and `#`-style comments are allowed. For example, to adopt the
`make` and `gofmt` conventions, your `boilerplate/update.cfg` may look like:

```
# Use common makefile targets and functions
make

# Enforce golang style using our gofmt configuration
gofmt
```
Opt into updates of a convention by including it in the file; otherwise
you are opted out, even if you had previously used a given convention.

**Note:** Updates are applied in the order in which they are listed in
the configuration. If conventions need to be applied in a certain order
(which should be avoided if at all possible), it should be called out
in their respective READMEs.

### Update

Periodically, run `make update_boilerplate` on a clean branch in your
consuming repository. If it succeeds, commit the changes, being sure to
notice if any new files were created. **Sanity check the changes against
your specific repository to ensure they didn't break anything.** If they
did, please make every effort to fix the issue _in the boilerplate repo
itself_ before resorting to local snowflake fixups (which will be
overwritten the next time you update) or opting out of the convention.

## Contributing

- Create a subdirectory under `boilerplate`. The name of the directory is
  the name of your convention. By convention, do not prefix your convention
  name with an underscore; such subdirectories are reserved for use by
  the infrastructure. In your subdirectory:
- Add a `README.md` describing what your convention does and how it works.
- Add any files that need to be copied into consuming repositories.
  (Optional -- you might have a convention that only needs to run
  `update`.)
- Create an executable called `update`. (Optional -- you might have a
  convention that only needs to lay down files.)
  - It must accept exactly one command line argument, which will be
    either `PRE` or `POST`. The main driver will invoke `update
    PRE` _before_ copying files, and `update POST` _after_ copying
    files. (You may wish to ignore a phase, e.g. via
    `[[ "$1" == "PRE" ]] && exit 0`.)
    - **Note:** We always run the *new* version of the `update` script.
    - **Note:** The entire convention directory is wiped out and
      replaced between `PRE` and `POST`, so e.g. don't try to store any
      information there.
    is replaced
  - It must indicate success or failure by exiting with zero or nonzero
    status, respectively. Failure will cause the main driver to abort.
  - The main driver exports the following variables for use by
    `update`s:
    - `REPO_ROOT`: The fully-qualified path to the root directory of
      the repository in which we are running.
    - `REPO_NAME`: The short name (so like `boilerplate`, not
      `openshift/boilerplate`) of the git repository in which we are
      running. (Note that discovering this relies on the `origin`
      remote being configured properly.)
    - `CONVENTION_ROOT`: The path to the directory containing the main
      `update` driver and the convention subdirectories themselves. Of
      note, `${CONVENTION_ROOT}/_lib/` contains some utilities that may
      be useful for `update`s.
