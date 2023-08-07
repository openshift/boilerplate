# Subscribers

- [Subscribers](#subscribers)
  - [`suscribers.yaml`](#suscribersyaml)
  - [`subscriber` utility](#subscriber-utility)
    - [`subscriber propose`](#subscriber-propose)
      - [`subscriber propose update`](#subscriber-propose-update)
    - [`subscriber report`](#subscriber-report)
      - [`subscriber report onboarding`](#subscriber-report-onboarding)
      - [`subscriber report pr`](#subscriber-report-pr)
      - [`subscriber report release`](#subscriber-report-release)

Boilerplate tracks consumers via a [YAML file](#suscribersyaml) committed to the boilerplate repository.
Registered consumers ("subscribers") are able to take advantage of certain automations controlled by the [subscriber utility](#subscriber-utility).

## `suscribers.yaml`
[subscribers.yaml](../subscribers.yaml) keeps track of boilerplate consumers, the convention(s) to which they are subscribed, and the state of their subscription.
To register your repository, simply add a stanza to this file, commit the change, and propose a pull request.
The comment at the top of the file describes the schema and contents.

## `subscriber` utility
Subscribers can be managed in various ways using the [`subscriber` utility](../boilerplate/_lib/subscriber).
Some caveats:
- This is intended to be run only from within the boilerplate repository. (FIXME: Then we should put it someplace it doesn't get copied into consumer repositories.)
- The command lives at `./boilerplate/_lib/subscriber`. You may wish to alias or `$PATH` this. But note:
- It (probably) only works if your PWD is the root of the boilerplate repository. (FIXME?)
- Certain subcommands rely on the [`gh` command](https://github.com/cli/cli) being installed and properly configured.
- It relies on [`yq` version 4.x](https://mikefarah.gitbook.io/yq/v/v4.x/).

Subcommands follow:

### `subscriber propose`
Subcommands of `subscriber propose` deal with proposing PRs to subscribers' repositories.
It has no functionality of its own.

#### `subscriber propose update`
Automatically propose a boilerplate update PR to one or more subscribers' repositories.
Run `subscriber propose update -h` for details.

### `subscriber report`
Subcommands of `subscriber report` probe the state of subscribers in various ways.
All of these subcommands are intended to be read-only -- i.e. they won't make any changes.
`subscriber report` has no functionality of its own.

#### `subscriber report onboarding`
Produces a report listing all "onboarded" subscribers (those whose entry in [subscribers.yaml](../subscribers.yaml) contains at least one convention with `manual` (FIXME: or `automated`) status).
Run `subscriber report onboarding -h` for details on the output format.

#### `subscriber report pr`
Produces a report listing all registered subscribers (those with any entry in [subscribers.yaml](../subscribers.yaml)).
Each is shown with zero or more lines describing open boilerplate-related pull requests (those whose branch name starts with `boilerplate-`) in the subscriber's repository.
Run `subscriber report pr -h` for details on the output format.

#### `subscriber report release`
For each "onboarded" subscriber (whose entry in [subscribers.yaml](../subscribers.yaml) contains at least one convention with `manual` (FIXME: or `automated`) status), inspects its [prow configuration in openshift/release](https://github.com/openshift/release/tree/master/ci-operator/config/).
- If the configuration is as expected, reports "A-OK"
- If the configuration is missing, reports "No configuration".
- If the configuration is present, but different from what we expect, prints the diff.

Run `subscriber report release -h` for more.
