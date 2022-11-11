# boilerplate

Standard development infrastructure and tooling to be used across repositories in an organization.

This work was inspired by, and partially cribbed from,
[lyft/boilerplate](https://github.com/lyft/boilerplate).

- [boilerplate](#boilerplate)
  - [Quick Start](#quick-start)
  - [Overview](#overview)
    - [A Pretty Picture](#a-pretty-picture)
    - [Consumer Philosophy](#consumer-philosophy)
      - [Trust](#trust)
      - [Ignore](#ignore)
  - [Mechanism](#mechanism)
  - [Consuming](#consuming)
    - [Bootstrap](#bootstrap)
    - [Configure](#configure)
    - [Register](#register)
    - [Update](#update)
    - [Multiple Updates](#multiple-updates)
  - [Contributing](#contributing)
    - [Environment setup](#environment-setup)
    - [Tests](#tests)
    - [Build Images](#build-images)
      - [Making CI Efficient](#making-ci-efficient)
      - [Picking Up (Security) Fixes](#picking-up-security-fixes)

## Quick Start

ignore, testing CI

[Bootstrap](#bootstrap) and [subscribe](#configure) to
[openshift/golang-osd-operator](boilerplate/openshift/golang-osd-operator/) by
pasting the following scriptlet into your terminal. Your pwd should be a clean
checkout of the repository you wish to onboard.

```shell
curl --output boilerplate/update --create-dirs https://raw.githubusercontent.com/openshift/boilerplate/master/boilerplate/update
chmod +x boilerplate/update
echo "openshift/golang-osd-operator" > boilerplate/update.cfg
printf "\n.PHONY: boilerplate-update\nboilerplate-update:\n\t@boilerplate/update\n" >> Makefile
make boilerplate-update
sed -i '1s,^,include boilerplate/generated-includes.mk\n\n,' Makefile
make boilerplate-commit
```

**Pay attention to the output! It contains critical instructions!**

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

For more discussion of the motivation behind copying rather than using
remote sources on the fly, see
[lyft's README](https://github.com/lyft/boilerplate/#why-clone-files).

### A Pretty Picture
The lifecycle from the consuming repository's perspective:

```
              XXXXXXXXXXXXX                           XXXXXXXXXX
              X Bootstrap X                           X Update X
              XXXXXXXXXXXXX                           XXXXXXXXXX

             +-------------+                    +---------------------+
             |Download     |                    |Subscribe (optional):|
             |update script|                    |Edit update.cfg      |
             +-----+-------+                    +----------+----------+
                   |                                       |
                   v                                       v
          +--------+---------+                 +-----------+-----------+
          |Create            |                 |make boilerplate-update|
          |boilerplate-update|                 +-----------+-----------+
          |make target       |                             |
          +--------+---------+                             v
                   |                           +-----------+-----------+
                   v                           |Commit (automated):    |
              +----+-----+                     |make boilerplate-commit|
              |Touch     |                     +-----------+-----------+
              |update.cfg|                                 |
              +----+-----+                                 v
                   |                              +--------+--------+
                   v                              |Validate changes,|
        +----------+------------+                 |make local edits |
        |make boilerplate-update|                 +--------+--------+
        +----------+------------+                          |
                   |                                       v
                   v                               +-------+-------+
+------------------+----------------------+        |Commit (manual)|
|include boilerplate/generated-includes.mk|        +-------+-------+
+------------------+----------------------+                |
                   |                                       v
                   v                                     +-+--+
        +----------+------------+                        |push|
        |Commit (automated):    |                        +----+
        |make boilerplate-commit|
        +----------+------------+
                   |
                   v
                 +-+--+
                 |push|
                 +----+
```

### Consumer Philosophy
Consuming repositories should think about boilerplate deltas the same way you would think about the `vendor/` directory for go dependencies: **trust** and **ignore**.

#### Trust
When reviewing a PR that includes a boilerplate changes, you can trust:
- That they have already been **peer reviewed** in the boilerplate repository itself.
  You may of course wish to review them at a high level to understand how they relate to your specific repository.
- That they are **unchanged from their original form** in the boilerplate repository itself.
  Assuming you are using standardized prow jobs, [freeze-check](boilerplate/_lib/freeze-check) is wired in to make sure of this.

#### Ignore
As with deltas under `vendor/`, changes under `boilerplate/` can be ignored the vast majority of the time.
To facilitate this, you may wish to take advantage of [linguist](https://github.com/github/linguist), which is used by GitHub, to hide deltas under `boilerplate/` by default.
This will make them appear the same as generated mocks, `go.sum`, etc.: unrendered by default, but with a link to render them on demand.
To enable this behavior, add the following to the top of the `.gitattributes` file in the root of your repository:

```
# Hide most boilerplate deltas by default
boilerplate/** linguist-generated=true
```

Note that, for security reasons, boilerplate will generate a block of overrides to force by-default rendering of certain files under `boilerplate/`, as well as the `.gitattributes` file itself.
This is so that malicious changes attempting to subvert the tooling behind the [trust](#trust) model will always be rendered.

## Mechanism

A "convention" lives in a subdirectory hierarchy of `boilerplate` and is
identified by the subdirectory's path. For example, a convention around OSD
operators written in Go lives under `boilerplate/openshift/golang-osd-operator`
and is identified as `openshift/golang-osd-operator`.

A convention comprises:

- Files, which are copied verbatim into the consuming repository at
  update time, replacing whatever was there before. The source directory
  structure is mirrored in the consuming repository -- e.g.
  `boilerplate/boilerplate/openshift/golang-osd-operator/*` is copied into
  `${TARGET_REPO}/boilerplate/golang-osd-operator/*`.
- An `update` script (which can be any kind of executable, but please
  keep portability in mind). If present, this script is invoked twice
  during an update:
  - Once _before_ files are copied, with the command line argument
    `PRE`. This can be used to prepare for the copy and/or validate that
    it is allowed to happen. If the program exits nonzero, the update is
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

2. Touch (create empty) the configuration file `boilerplate/update.cfg`.
   This will be use [later](#configure).

3. Create a `Makefile` target as follows:

```makefile
.PHONY: boilerplate-update
boilerplate-update:
	@boilerplate/update
```

**Note:** It is important that the `Makefile` target have the expected
name, because (eventually) there may be automated jobs that use it
to look for available updates.

4. Run your first update.

```shell
$ make boilerplate-update
```

5. Include the "nexus" makefile. This file is generated by boilerplate and will
   import `make` rules for any conventions you subscribe to, as well as for the
   boilerplate framework itself. Add the following line to your Makefile,
   preferably at the top:

```makefile
include boilerplate/generated-includes.mk
```

6. Commit. For convenience, you can use the `boilerplate-commit` target
   provided by boilerplate:

```shell
$ make boilerplate-commit
```

The above steps can be performed by pasting the following scriptlet into
your console:

```shell
curl --output boilerplate/update --create-dirs https://raw.githubusercontent.com/openshift/boilerplate/master/boilerplate/update
chmod +x boilerplate/update
touch boilerplate/update.cfg
printf "\n.PHONY: boilerplate-update\nboilerplate-update:\n\t@boilerplate/update\n" >> Makefile
make boilerplate-update
sed -i '1s,^,include boilerplate/generated-includes.mk\n\n,' Makefile
make boilerplate-commit
```

7. `boilerplate-commit` creates a commit in a new topic branch. Push it
   to your `origin` remote as usual to create a pull request.

### Configure

The `update` program looks for a configuration file at
`boilerplate/update.cfg`. It contains a list of conventions, which are
simply the names of subdirectory paths under `boilerplate`, one per line.
Whitespace and `#`-style comments are allowed. For example, to adopt the
`openshift/golang-osd-operator` convention, your `boilerplate/update.cfg` may
look like:

```
# Use standards for Go-based OSD operators
openshift/golang-osd-operator
```

Opt into updates of a convention by including it in the file; otherwise
you are opted out, even if you had previously used a given convention.

**Note:** If you opt out of a previously-used convention by removing it
from your config, you are responsible for cleaning up; the main `update`
driver doesn't do it for you.

**Note:** Updates are applied in the order in which they are listed in
the configuration. If conventions need to be applied in a certain order
(which should be avoided if at all possible), it should be called out
in their respective READMEs.

Follow any configuration changes with the "Update" sequence described below:

### Register

To take advantage of certain automations, your consuming repository must be
registered as a subscriber. See the
[documentation](doc/subscriber.md#subscribersyaml) for details on how this
works.

### Update

Use this procedure to pick up newly-subscribed conventions; and run it
periodically to pick up changes to existing subscriptions or to the
boilerplate framework itself.

1. Run `make boilerplate-update` on a clean branch in your consuming
   repository.

2. Commit the changes. For convenience, you can use `make boilerplate-commit`
   to automatically create a new topic branch and commit any changes
   resulting from the update.

3. Sanity check the changes against your specific repository, fixing any
   breakages and making local changes appropriate to the substance of
   the update. If you used `make boilerplate-commit`, you can use
   `git show` to see a summary of what was changed. **NOTE:** You must
   not touch files owned by boilerplate. Any changes to boilerplate
   content must be made in the boilerplate repo itself.

4. If local changes were necessary, commit them manually. You should
   commit to the topic branch you (or `make boilerplate-commit`) created
   above so that your PR is internally consistent and will build. You
   may choose to keep the two commits separate (preferred), or combine
   them.

5. Push the branch to create a PR as usual.

To update multiple consumers at once, use `subscriber propose update` --
see the [documentation](doc/subscriber.md#subscriber-propose-update) for details.

### Multiple Updates
You may create an [update](#update) PR and, before it merges, want or
need to include commits that subsequently merged into boilerplate. (A
common cause is a fix required in boilerplate to make your consumer's CI
pass.) In this case, in order to make sure the PR description is
correct, it is recommended to close the original PR and create a new one
from your default branch. If you had additional commits in play, these
can often simply be rebased onto the new branch.

## Contributing
In your fork of this repository (not a consuming repository):

- Create a subdirectory structure under `boilerplate`. The path of the
  directory is the name of your convention. Do not prefix your
  convention name with an underscore; such subdirectories are reserved
  for use by the infrastructure. In your leaf directory:
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
    - `LATEST_IMAGE_TAG`: The tag for the most recent build image
      produced by boilerplate.

### Environment setup
To test your changes, you can use the `BOILERPLATE_GIT_REPO` environment
variable and set it to your local clone in order to override the version of
boilerplate used (Example: `export BOILERPLATE_GIT_REPO=~/git/boilerplate`).


Default `update` behaviour consists of cloning the git repo, so ensure you have
your changes locally committed for your testing.
Alternatively, you can use the `BOILERPLATE_GIT_CLONE` variable to override the base
command used for cloning the project. Example of usecases :
- Add some flags to the git clone command
- Replace `git clone` by a copy command such as `rsync` or `cp` in order to
avoid having to regularly commit changes

### Tests
Test cases are executed by running `make test`. This must be done on a
clean git repository; otherwise the tests will not be using your
uncommitted changes.

Add new test cases by creating executable files in the [test/case](test/case)
subdirectory. These are discovered and executed in lexicographic order by
`make test`. Your test case should exit zero to indicate success; nonzero to
indicate failure. The [test/lib.sh](test/lib.sh) library defines convenient
variables and functions you can use if your test case is written in `bash`.
See existing test cases for examples.

### Build Images
If you make a change to the build image produced by boilerplate -- i.e.
by changing anything in [config/](config/) -- you must:

1. Publish a new tag. This will be picked up by appsre and used to
   publish a new tagged image for consumption via `LATEST_IMAGE_TAG` in
   conventions. The tag must be named `image-v{X}.{Y}.{Z}`, using
   [semver](https://semver.org/) principles when deciding what
   `{X}.{Y}.{Z}` should be.

Example:

```shell
$ git tag image-v1.2.3
$ git push origin --tags
$ git push upstream --tags
```

**NOTE:** You must do the `upstream` push *after* creating your PR. Otherwise the
tagged commit will not exist upstream.

**NOTE:** Your commit must also update the tag in a couple of places in
the repository. See https://github.com/openshift/boilerplate/pull/180
for an example.

2. Import that tag via boilerplate's ImageStream in `openshift/release`
   by adding an element to the `spec.tags` list in
   [this configuration file](https://github.com/openshift/release/blob/master/clusters/app.ci/supplemental-ci-images/boilerplate/boilerplate.yaml).

#### Making CI Efficient
The backing image is built in prow with every commit, even when nothing about it has changed.
To make this faster, we periodically ratchet the base image (the `FROM` in the [Dockerfile](config/Dockerfile)) to point to the previously-released image, and clear out the [build script](config/build.sh) to start from that point.
However, in app-sre we build from scratch (exactly once per `image-v*` tag!), via a [separate Dockerfile](config/Dockerfile.appsre).
Thus there is a (very small) chance that these builds will behave differently.

#### Picking Up (Security) Fixes
We only build and publish a new build image on commits tagged with `image-v*`, which we [force](config/tag-check.sh) you to do whenever something about *boilerplate's* image configuration changes.
If the base image (`golang-*`) is updated for any reason, including security fixes, the boilerplate build image will only pick up those changes the next time we produce a new version.
To pick up such changes right away, simply produce a new version (identical to the previous in terms of what boilerplate configures) according to the instructions [above](#build-images).
Of course, consumers will need to update to/past the tagged commit in order to use the new image.
