# Test Units For Kamailio SIP Server #

Test framework with a set of unit tests for Kamailio SIP Server. It targets the use
within a Docker container.

Read more about Kamailio at:

  * https://www.kamailio.org

## The Test Framework ##

The tests can be run using the command line tool `ktestsctl`. Run it without any parameter
in order to see available options.

A unit test is stored in its own directory inside the subfolder `units/`. The name of the
directory is considered to be the name of the unit.

The name of a unit test has the format `txxxxxnnnn`, the rules being:

  * `t` - the first character in the name (`t` from `test`)
  * `xxxx` - any five characters (use lower case letters) that should identify a group of tests
  (e.g., `cfgxx` is used to identify tests related to default `kamailio.cfg`)
  * `nnnn` - four digits to assign to different unit tests in the same group, use zeros to pad
  in order to have always four digits (e.g., `0001`)

Example of full unit test name: `tcfgxx0001`.

Inside each unit directory should be at least two files:

  * `unitname.sh` - an executable shell script to be used to run the unit (e.g., `tcfgxx0001.sh`)
  * `README.md` - to contain the description for the unit test

The shell script is executed inside the unit directory by `ktestsctl`.

The `README.md` in a text file in `markdown` format. It should have a line that starts with
`Summary: ` and provides a short description of the unit test. The text in the line after
`Summary: ` is used by `ktestsctl` when writing the unit tests execution report.

The framework has a configuration file located at `etc/config`. This is a shell script expected
to have lines with `VARIABLE=value`, allowing to set paths to the applications used by
unit scripts.

Useful shell functions that might be handy to use in units are stored inside files from
`lib` subfolder, like:

  * `lib/utils` - common utility functions

The Docker files that can be used to build Docker images to run the unit tests are located in
`docker` subfolder. These are:

  * `docker/Dockerfile` - container build with Debian 9.x (Stretch) deploying Kamailio installed
  from source code. The directory with Kamailio source code is copied from local disk into the
  container

### Tools For Unit Tests ###

Following tools are installed inside the container and can be used to create test units:

  * `sipsak`
  * `sipp` (`sip-tester`)

## Running Unit Tests ##

### Dependencies ###

  * `docker` - it has to be installed in order to follow the next instructions

### Installation ###

  * create a directory where to store the resources and go to it

```
mkdir kamailio-testing
cd kamailio-testing
```

  * clone the `kamailio-tests` git repository

```
git clone https://github.com/kamailio/kamailio-tests
```

  * clone the `kamailio` git repository

```
git clone https://github.com/kamailio/kamailio
```

  * copy desired Dockerfile in the current folder

```
cp kamailio-tests/docker/Dockerfile
```

  * build the Docker image

```
docker build -t kamailio-tests-deb9x .
```

### Execute Unit Tests ###

```
docker run kamailio-tests-deb9x
```

With the default `Dockerfile`, the above command is running all unit tests.

You can edit the `Dockerfile` and change the `CMD` line to execute a different command. Once
you save the changes in the `Dockerfile`, rebuild the docker container and run.

For example, run the unit tests in non-silent mode, set `CMD` inside `Dockerfile` to:

```
CMD /usr/local/src/kamailio-tests/ktestsctl run
```

Save and then run:

```
docker build -t kamailio-tests-deb9x .
docker run kamailio-tests-deb9x
```

Example running only default `kamailio.cfg` related unit tests, update `Dockerfile` to have:

```
CMD /usr/local/src/kamailio-tests/ktestsctl run tcfgxx
```

Save and then run:

```
docker build -t kamailio-tests-deb9x .
docker run kamailio-tests-deb9x
```

If you run `ktestsctl` with `-w` option, you may need to stop the container using `docker` command:

```
docker ps
docker stop <containerid>
```

## Contributing ##

Contributions are more than welcome, recommended way is to do pull requests.

## Support ##

Mailing list:

  * <sr-users [at] lists.kamailio.org>