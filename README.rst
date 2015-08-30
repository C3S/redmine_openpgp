Redmine OpenPGP
===============

A plugin for Redmine to enhance the security of email communication by

- de-/encrypting in-/outgoing emails with the OpenPGP standard
- filtering content of unencrypted emails

developed for `C3S - (Cultural Commons Collecting Society) <https://c3s.cc>`_


Details
-------

Users may

- *add* / *remove* their public PGP key
- *see* the public PGP key of the redmine server

Administrators may

- choose to *pass* / *reject* incoming mails without a valid signature for all projects
- activate outgoing mail handling for *all* / *selected* / *no* projects
- *add* / *generate* / *remove* a private PGP key for the redmine server (both *server-side* / *client-side*)
- choose to *pass* / *filter* / *block* outgoing unencrypted mails
- add a *footer message* to filtered mails

Encrypted mails may be

- *PGP/MIME* or *PGP/Inline* (incoming)
- *PGP/MIME* (outgoing)

Unencrypted mails may be

- *blocked*: no mail is sent
- *filtered*: body is reduced to the link to the added / updated object and an invitation to add the public PGP key; headers & subject are unchanged
- *unchanged*: mail is sent unchanged

Notifications, that may be filtered:

- attachments_added
- document_added
- issue_add
- issue_edit
- message_posted
- news_added
- news_comment_added
- reminder
- wiki_content_added
- wiki_content_updated


Dependencies
------------

- gpg (http://www.gnupg.org/download/)
- gpgme (https://github.com/jkraemer/mail-gpg)
- mail-gpg (https://github.com/jkraemer/mail-gpg)


Compatibility
-------------

This plugin has been tested with
::

    gnupg    1.4.18
    redmine  3.1.0
    ruby     2.1.5p273
    rails    4.2.3
    gpgme    2.0.9
    mail-gpg 0.2.4


Installation
------------

#. Clone this repo into ``/path/to/redmine/plugins/openpgp``

  ``$git clone https://github.com/C3S/redmine_openpgp /path/to/redmine/plugins/openpgp``

#. Change into redmine root directory

  ``$cd /path/to/redmine``

#. Install gems

  ``$bundle install``

#. Migrate database

  ``$RAILS_ENV=production rake redmine:plugins:migrate``

#. Restart redmine

  ``$sudo service apache2 restart``


Configuration
-------------

Administrators
''''''''''''''

#. Configure redmine

    *Administration / Settings / Email notifications*

    - Emission email address

    *Administration / Settings / General*

    - Host name and path
    - Protocol

    *Administration / Settings / Incoming emails*

    - Enable WS for incoming emails
    - API key

#. Configure plugin

    *Administration / Plugins / Openpgp*

3. Add or generate a private PGP key for the redmine server 

  - *either* server-side (secure)
  - *or* client-side (**INSECURE over http**, more or less secure over https)

*Note:* The remote server needs enough entropy to generate random, secure keys. If the server side generation process does not proceed or the client side connection has a timeout, connect to the remote server and try ``ls -R /``. If you use ``rngd`` for entropy generation, be advised not to use ``/dev/urandom`` as source for important keys.

Adding an existing private PGP key server-side
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

#. copy the ascii armored key into a file on the server
#. change into redmine root directory

  ``$cd /path/to/redmine``

#. use a rake task to add the existing key (the old one is deleted). Adjust ``keyfile`` and ``secret``:

  ``$RAILS_ENV="production" rake redmine:update_redmine_pgpkey keyfile="/path/to/key.asc" secret="passphrase"``

Generating a new private PGP key server-side
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

#. change into redmine root directory

  ``$cd /path/to/redmine``

#. use a rake task to generate the new key (the old one is deleted). Adjust ``secret``:

  ``$RAILS_ENV="production" rake redmine:generate_redmine_pgpkey secret="passphrase"``

Managing a private PGP keys client-side
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

#. Log into redmine as administrator
#. Visit http://REDMINE.URL/pgp
#. Follow the instructions

Users
'''''

#. Log into redmine
#. Visit http://REDMINE.URL/pgp
#. Add your public PGP key
#. Copy & paste the public PGP key for the redmine server into a local file on your machine
#. Import this file into your local gpg key ring

*Note:* The private PGP key for the redmine server has to be added by an administrator, before the corresponding public PGP key is displayed.


Implementation
--------------

The table ``pgpkeys`` is added to the redmine database:

- each entry associates a redmine user (``user_id``) with the unique fingerprint of a key (``fpr``). This allows for matching fingerprints instead of email address, thus enabling redmine users to use keys, which don't match their email address
- the entry with ``user_id`` 0 is reserved for the private key of the redmine server additionally containing the secret passphrase

The following gems are used:

- ``mail-gpg`` for de-/encryption and signature handling within ``Mail`` / ``ActionMailer``
- ``gpgme`` to interact with ``gpg`` running on the server

Whenever a key is added:

- the key is imported into the ``gpg`` key ring of the system user owning the redmine process
- an entry is added to the table ``pgpkeys``

Whenever a key is removed:

- the corresponding entry in the table ``pgpkeys`` is deleted
- if there are no other references to this key within the table ``pgpkeys``:

  - the key is **removed from the gpg key ring** as well

Whenever a mail is sent:

- if the plugin is enabled globally / on project level:

  - if the recipient owns a key:

    - the mail is encryted for the recipient
    - if the redmine server owns a key:

      - the mail is signed by the redmine user

  - else: the mail is blocked / filtered / passed unchanged, depending on the plugin settings

Whenever a mail is recieved:

- if encrypted:

  - it will be decrypted

- if the signature is invalid and mails with invalid signature should be rejected:

  - it will be rejected


Problems
--------

Pinentry always shows up, although a passhprase is given?

    ``gpg`` == 2.0.X will not work (see `here <https://stackoverflow.com/a/27768542>`_) and ``gpg`` >= 2.1 will probably work, if a gpgme passphrase callback function is added to the code (but is still missing). Downgrade to 1.X or install 1.X parallel and symlink ``/usr/bin/gpg`` to ``/usr/bin/gpg2``


Improvements
------------

- Add tests
- Add languages
- Add LDAP integration for importing keys
- Add gpgme passphrase callback for ``gpg`` >= 2.1, retaining compatibility to ``gpg`` < 2


Links
-----

- `GPG <http://www.gnupg.org/gph/en/manual/x56.html>`_ (reference)
- `ActionMailer <http://apidock.com/rails/ActionMailer/Base>`_ (reference)
- `mail <http://www.rubydoc.info/gems/mail>`_ (reference)
- `gpgme <http://www.rubydoc.info/gems/gpgme/2.0.9>`_ (reference)
- `mail-gpg <http://www.rubydoc.info/gems/mail-gpg/0.2.4>`_ (reference)
- `PGP/MIME <http://www.ietf.org/rfc/rfc3156.txt>`_ (RFC)
- `PGP Formats <http://binblog.info/2008/03/12/know-your-pgp-implementation/>`_ (explanation)


Contributions
-------------

- `Alexander Blum <https://github.com/timegrid>`_


License
-------
::

    Redmine plugin for email encryption with the OpenPGP standard
    Copyright (C) 2015 Alexander Blum <a.blum@free-reality.net>

    This program is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    This program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with this program.  If not, see <http://www.gnu.org/licenses/>.