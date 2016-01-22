module DecryptMails

  def self.included(base) # :nodoc:
    base.send(:include, InstanceMethods)
    base.class_eval do
      alias_method_chain :receive, :encryption
    end
  end

  module InstanceMethods

    def receive_with_encryption(email, options={})

      # encrypt and check validity of signature
      if email.encrypted?
        email = email.decrypt(
          :password => Pgpkey.find_by(:user_id => 0),
          :verify => true
        )
        valid = email.signature_valid?
        signatures = email.signatures
      else
        if email.signed?
          verified = email.verify
          valid = verified.signature_valid?
          signatures = verified.signatures
        else
          valid = false
        end
      end

      # compare identity of signature with sender
      if valid
        valid = false
        sender_email = email.from.to_a.first.to_s.strip
        user = User.find_by_mail sender_email if sender_email.present?
        key = Pgpkey.find_by user_id: user.id
        signatures.each do |s|
          key.subkeys.each do |subkey|
            valid = true if subkey.capability.include? :sign and \
                            subkey.fpr == s.fpr
          end
        end if not signatures.empty?
      end

      # error on invalid signature
      if Setting.plugin_openpgp['signature_needed'] and not valid
        if logger
          logger.info "MailHandler: ignoring emails with invalid signature"
        end
        return false
      end

      receive_without_encryption(email, options)

    end

  end
end