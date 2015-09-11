desc <<-END_DESC
Update the private PGP key and passphrase for the redmine server.
Warning: will override and delete the existing one.

Available options:
  * key      => absolute path to key file (interactive, if not given)
  * secret   => passphrase (interactive, if not given)

Example:
  RAILS_ENV="production" rake redmine:update_redmine_pgpkey
  RAILS_ENV="production" rake redmine:update_redmine_pgpkey keyfile="/path/to/key.asc" secret="passphrase"
END_DESC

namespace :redmine do
  task :update_redmine_pgpkey => :environment do |task|
    keyfile = ENV['keyfile']
    @secret = ENV['secret']

    # sanity checks
    puts 'Warning: passphrase is empty (no problem, but are you sure?)' if @secret == ""
    abort 'Error: cannot access "'+keyfile+'". Wrong path?' if not keyfile.blank? and not File.file? keyfile

    # interactive mode: keyfile
    if keyfile.blank?
      while true
        print "Enter absolute path to key file: "
        STDOUT.flush
        keyfile = STDIN.gets.chomp!
        abort 'Abort.' if keyfile.empty?
        break if File.file? keyfile
        puts 'Error: cannot access "'+keyfile+'". Wrong path?'
      end
    end
    puts '... "'+keyfile+'" does exist.'

    # interactive mode: secret
    if @secret == nil
      print "Enter secret: "
      STDOUT.flush
      @secret = STDIN.noecho(&:gets).chomp!
      puts
      puts 'Warning: passphrase is empty (no problem, but are you sure?)' if @secret == ""
    end

    # open and validate keyfile
    @key = File.open(keyfile, "rb").read
    regex = /^\A\s*-----BEGIN PGP PRIVATE KEY BLOCK-----(?:(?!-----BEGIN).)*?-----END PGP PRIVATE KEY BLOCK-----\s*\z/m
    abort 'Error: PGP key not valid (it should start with "-----BEGIN PGP PRIVATE KEY BLOCK-----" and end with "-----END PGP PRIVATE KEY BLOCK-----")' if not @key.match(regex)
    puts '... PGP key seems to be valid.'

    # remove old key from db and from gpg ring, if present
    old_key = Pgpkey.find_by user_id: 0
    if old_key
      old_fpr = old_key.fpr
      old_key.delete
      puts '... removed old key from db.'
      if not Pgpkey.find_by fpr: old_fpr
        gpgme_key = GPGME::Key.get(old_fpr)
        gpgme_key.delete!(true)
        puts '... removed old key from gpg key ring.'
      else
        puts 'Wanring: old key not removed (still referenced by a user)'
      end
    end

    # save new key into gpg key ring
    gpgme_import = GPGME::Key.import(@key)
    abort 'Error: import of the key into gpg key ring failed.' if gpgme_import.imports.empty?
    puts '... PGP key imported into gpg key ring.'
    gpgme_key = GPGME::Key.get(gpgme_import.imports[0].fpr)
    @fpr = gpgme_key.fingerprint

    # test secret
    gpgme = GPGME::Crypto.new
    enc = gpgme.encrypt('test', {:recipients => @fpr, :always_trust => true}).to_s
    begin
      dec = gpgme.decrypt(enc, :password => @secret).to_s
    rescue GPGME::Error::BadPassphrase
      gpgme_key.delete!(true)
      abort "Error: Passphrase was wrong."
    end
    puts '... passphrase is correct.'

    # save new key to db
    if Pgpkey.create(:user_id => 0, :fpr => @fpr, :secret => @secret)
      puts '... saved new key to db.'
    else
      abort "Error: Unkown error."
    end

    puts 'PGP key successfully saved. Exiting.'
  end
end
