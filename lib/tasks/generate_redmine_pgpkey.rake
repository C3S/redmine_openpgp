desc <<-END_DESC
Generate the private PGP key for the redmine server.
Warning: will override and delete the existing one.

Available options:
  * secret   => passphrase (interactive, if not given)

Example:
  RAILS_ENV="production" rake redmine:generate_redmine_pgpkey
  RAILS_ENV="production" rake redmine:generate_redmine_pgpkey secret="passphrase"
END_DESC

namespace :redmine do
  task :generate_redmine_pgpkey => :environment do |task|
    keyfile = ENV['keyfile']
    @secret = ENV['secret']

    # sanity checks
    puts 'Warning: passphrase is empty (no problem, but are you sure?)' if @secret == ""

    # interactive mode: secret
    if @secret == nil
      print "Enter secret: "
      STDOUT.flush
      @secret = STDIN.noecho(&:gets).chomp!
      puts
      puts 'Warning: passphrase is empty (no problem, but are you sure?)' if @secret == ""
    end

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
        puts 'Warning: old key not removed (still referenced by a user)'
      end
    end

    # prepare gpg parameter
    params = {
        :key_type => 'RSA',
        :key_length => '2048',
        :subkey_type => 'RSA',
        :subkey_length => '2048',
        :name_real => 'Redmine Server',
        :name_comment => '',
        :name_email => Setting['mail_from'],
        :expire_date => '0',
        :passphrase => @secret
    }
    data = "<GnupgKeyParms format=\"internal\">\n"
    data += "Key-Type: "       +params[:key_type]      +"\n"
    data += "Key-Length: "     +params[:key_length]    +"\n"
    data += "Subkey-Type: "    +params[:subkey_type]   +"\n"
    data += "Subkey-Length: "  +params[:subkey_length] +"\n"
    data += "Name-Real: "      +params[:name_real]     +"\n"
    data += "Name-Comment: "   +params[:name_comment]  +"\n" unless params['name_comment'].blank?
    data += "Name-Email: "     +params[:name_email]    +"\n"
    data += "Expire-Date: "    +params[:expire_date]   +"\n"
    data += "Passphrase: "     +params[:passphrase]    +"\n" unless params['passphrase'].blank?
    data += "</GnupgKeyParms>"
    puts '... PGP key parameters built.'

    # create key and save into gpg key ring
    GPGME::Ctx.new.genkey(data)
    puts '... PGP key generated and saved into gpg key ring.'

    # save generated key into db
    key = GPGME::Key.find(nil, params[:name_email]).first
    if Pgpkey.create(:user_id => 0, :fpr => key.fingerprint, :secret => params['passphrase'])
      puts '... saved generated key to db.'
    else
      abort "Error: Unkown error."
    end

    puts 'PGP key successfully generated. Exiting.'
  end
end
