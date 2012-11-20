ASBO
====

These docs are still largely TODO.

Asbo is a package-based build- and dependency-management system for projects.

Get Started
-------------
Asbo needs Ruby 1.9 or later and depends on
[trollop] (http://trollop.rubyforge.org/), and
[zip] (http://rubygems.org/gems/zip)


sources.yml
-----------

This file lives in .asbo/sources.yml, and tells Asbo where to find packages.

A typical sources.yml might look like this

```yaml
$base: file://path/to/repo

release: $base/$package-$version
latest: $base/$package-nightly
```

Let's see what's going on here.

### Paths and Variables

First, variables. These start with a `$`, and consist of letters, numbers, and underscores.
There are two which are defined by Asbo: `$package` and `$version`, while any others are left up to you to define.

So, to analyse the file:

```yaml
# This defines a variable called $base, with the value file://path/to/repo
$base: file://path/to/repo

# This tells Asbo where to find the release and 'latest' versions.
# $package is defined by Asbo, and will hold the name of the package
# $version is also defined by Asbo, and specifies the package version
release: $base/$package-$version
latest: $base/$package-nightly
```

You can also define paths and variables on a per-project basis, for example:

```yaml
release: file://path/to/repo/$package_id-$version

project_1:
  $package_id: 20

project_2:
  release: file://path/to/another/repo/project_2-$version
```

Here, we defined our own variable $package_id. For project_1, we defined this to be 20 (this can be useful for systems that require some mapping of id to package name).
For project_2, we defined a completely new path, which overrides the default.

Also, note how we left out the `latest:` key? If this isn't set, the `release:` key is used, with $version` set to "latest".

### Repository types

The prefix on the repo path, "file://" above, says what backend to use when accessing the repo.

Currently only one backend, 'file', is supported: this looks on the local filesystem for the package, in a path relative to the workspace.
In future, 'teamcity' will also be supported.

buildfile.yml
-------------

This file lives in the root of each project, and defines its names and dependencies.

A sample file:

```yaml
package: project_1

dependencies:
  - project_2:0.0.1:Release
  - project_3:latest:Debug
  - project_4:source:Debug
```

The package key defines the name of the project, and the dependencies consist of a list of `<package>:<version>:<build-config>` triplets.

'source' dependencies are not retrieved from the repo, and must instead be built locally.
This allows the developer to use a bleeding-edge version of a package.

