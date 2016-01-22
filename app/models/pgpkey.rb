class Pgpkey < ActiveRecord::Base
  unloadable

  def public_key
    GPGME::Key.get(self.fpr).export(:armor => true).to_s
  end

  def metadata
    GPGME::Key.get(self.fpr).to_s
  end

  def subkeys
    GPGME::Key.get(self.fpr).subkeys
  end
end
