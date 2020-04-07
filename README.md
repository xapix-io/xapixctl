# xapixctl

[![Gem Version](https://badge.fury.io/rb/xapixctl.svg)](https://badge.fury.io/rb/xapixctl)

Xapix client library and command line tool

## Installation

Install it via:

    $ gem install xapixctl

On Windows make sure you have ruby installed:

    $ choco install ruby -y
    $ refreshenv
    $ gem install xapixctl

## Usage

To see more details on how to run xapixctl, use:

```
$ xapixctl help

Commands:
  xapixctl api-resources                                            # retrieves a list of all available resource types
  xapixctl apply -f, --file=FILE -o, --org=ORG                      # Create or update a resource from a file
  xapixctl delete [TYPE ID] [-f FILE] -o, --org=ORG                 # delete the resources in the file
  xapixctl export -o, --org=ORG -p, --project=PROJECT               # retrieves all resources within a project
  xapixctl get TYPE [ID] -o, --org=ORG                              # retrieve either all resources of given TYPE or just the resource of given TYPE and ID
  xapixctl help [COMMAND]                                           # Describe available commands or one specific command
  xapixctl logs CORRELATION_ID -o, --org=ORG -p, --project=PROJECT  # Retrieves the execution logs for the given correlation ID
  xapixctl publish -o, --org=ORG -p, --project=PROJECT              # Publishes the current version of the given project

Options:
  -v, [--verbose], [--no-verbose]
      [--xapix-url=XAPIX_URL]      # Fallback: environment variable XAPIX_URL. URL to Xapix. Default: https://cloud.xapix.io/
      [--xapix-token=XAPIX_TOKEN]  # Fallback: environment variable XAPIX_TOKEN. Your access token.
```

The main commands to interact with Xapix are:
* `xapixctl get TYPE` to list all the resources of a specific type. You can get the supported types with `xapixctl api-resources`. To see the complete resource definition instead of an overview use the `-f yaml` switch. Use `xapixctl help get` for more details.
* `xapixctl apply` to create a new resource or update existing ones. Resources are matched using their type and id. If a resource with the same type and id already exists it is updated, otherwise a new one is created.
* `xapixctl publish` to publish the current status of a project.


## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake spec` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and tags, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/xapix-io/xapixctl.
