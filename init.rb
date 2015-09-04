#!/bin/env ruby
# encoding: utf-8

require 'gpgme'
require 'mail-gpg'

Redmine::Plugin.register :openpgp do
  name 'OpenPGP'
  author 'Alexander Blum'
  description 'Email encryption with the OpenPGP standard'
  version '1.0'
  author_url 'mailto:a.blum@free-reality.net'
  url 'https://github.com/C3S/redmine_openpgp'
  settings(:default => {
    'signature_needed' => false,
    'encryption_scope' => 'project',
    'unencrypted_mails' => 'filtered',
    'filtered_mail_footer' => ''
  }, :partial => 'settings/openpgp')
  project_module :openpgp do
    permission :block_email, { :openpgp => :show }
  end
  menu :account_menu, :pgpkeys, { :controller => 'pgpkeys', :action => 'index' }, 
    :caption => 'PGP', :after => :my_account,
    :if => Proc.new { User.current.logged? }
end

# encrypt outgoing mails
ActionDispatch::Callbacks.to_prepare do
  require_dependency 'mailer'
  Mailer.send(:include, EncryptMails)
end

# decrypt received mails
ActionDispatch::Callbacks.to_prepare do
  require_dependency 'mail_handler'
  MailHandler.send(:include, DecryptMails)
end
