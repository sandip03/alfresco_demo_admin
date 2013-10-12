alfresco_demo_admin
===================

Scripts for managing a group of Alfresco demo installations.

Mostly written in Bash.

These make it much easier to quickly spin up a new installation, or a demo
environment for a specific reason. It includes being able to save and restore a backup of an environment.

These are really only written for my own use, and are very specific to my own
Linux environment. They are not designed to be general or portable. I have
maintained these scripts for about 4 years (since Alfresco 3.2), so there is
some cruft that has built up. I have used this script for Debian and Red Hat
based systems, using both mysql and postgres external databases, and have just
modified it as I have gone along.

Over the years I have shared them with a few people and decided it would
be easier to maintain them here. Hopefully they provide you with some ideas and
guidance, but I don't expect them to be immediately useful.

This is for maintenance of demo and evaluation environments. As-is, I would not recommend environments created by this script to be used for production.


Dependencies
------------
You need to download the Alfresco binary installer, put it in the correct
releases directory, and update the paths in the helper script.

The scripts currently work on a Fedora 19 install.

The scripts assume that an external PostgreSQL database is supposed to be used,
rather than the internal Alfresco one. It modifies pg_hba.conf to have correct
access.

The scripts assume that an external JDK is being used.

All other dependencies are satisfied by the installer.


Process
--------
New environments are created by running the Alfresco demo installer, and passing
it a configuration file.

Alfresco is installed in /opt/

Necessary configuration files are then copied over the defaults.

A restore of previous state is then completed.

Each running demo environment needs a different PROJECT_NAME which is used for the DB name, DB password, directory name, and other places.

This script does not redirect access to privileged ports, so Alfresco always
needs to be run as root (not advisable in production).


Structure
---------
scripts: This is where the scripts live.

releases: This is where the supporting Alfresco binaries, configuration files,
and backups live. I only included a couple of these as examples.


Gotchas
--------
I had more demo_confs in the 3.x versions of Alfresco.

When creating a demo environment, you need to type in the db password. I
couldn't get it to echo in with expect.

When backing up and restoring, the indexes are not properly persisted, and so they are rebuilt. This works fine for small amounts of content, but could be done better.
