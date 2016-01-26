module DecryptMails

  def self.included(base) # :nodoc:
    base.send(:include, InstanceMethods)
    base.class_eval do
      alias_method_chain :receive, :encryption
    end
  end

  module InstanceMethods

    def receive_with_encryption(email, options={})

      # Extract useful metadata for logging
      sender_email = email.from.to_a.first.to_s.strip
      # We need to store this before decryption, because after decryption
      # email.encrypted? == false
      encrypted = email.encrypted?
      # Sometimes this isn't available after decryption. This seems like a bug,
      # so extract it here so we're guaranteed to have it
      message_id = email.message_id

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
      ignored = !!(Setting.plugin_openpgp['signature_needed'] and not valid)

      if logger
        logger.info "MailHandler: received email from #{sender_email} " +
                    "with Message-ID #{message_id}: " +
                    "encrypted=#{encrypted}, " +
                    "valid=#{valid}, "+
                    "ignored=#{ignored}"
      end

      if ignored
        return false
      end

      receive_without_encryption(email, options)

    end

  end
end
