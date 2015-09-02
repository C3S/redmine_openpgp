module EncryptMails

  def self.included(base) # :nodoc:
    base.send(:include, InstanceMethods)
    base.class_eval do
      alias_method_chain :mail, :relocation
    end
  end

  module InstanceMethods

    def mail_with_relocation(headers={}, &block)

      # whitelist of email action names resulting in unchanged mails
      ignore = [
        'account_activated', 'account_activation_request',
        'account_information', 'register', 'test_email', 'lost_password'
      ]
      return mail_without_relocation(headers, &block) if
        ignore.include? @_action_name

      # get project
      @project = case @_action_name
        when 'issue_add', 'issue_edit'
          @issue.project
        when 'news_added', 'news_comment_added'
          @news.project
        when 'document_added'
          @document.project
        when 'attachments_added'
          @attachments.first.project
        when 'message_posted'
          @message.project
        when 'wiki_content_added', 'wiki_content_updated'
          @wiki_content.project
      end

      # get key of redmine server
      server_key = Pgpkey.find_by(:user_id => 0)

      # relocate recipients
      @relocation = relocate(headers)

      # join headers
      @_message.header_fields.each do |h|
        headers[h.name] = h.value
      end

      # send encrypted mail
      headers_encrypted = headers.deep_dup
      headers_encrypted[:to] = @relocation[:encrypted][:to]
      headers_encrypted[:cc] = @relocation[:encrypted][:cc]
      headers_encrypted[:gpg] = { 
        encrypt: true,
        sign: false,
        keys: @relocation[:encrypted][:keys]
      }
      if server_key
        headers_encrypted[:gpg][:sign] = true
        headers_encrypted[:gpg][:sign_as] = Setting['mail_from']
        headers_encrypted[:gpg][:password] = server_key.secret
      end
      m = mail_without_relocation headers_encrypted do |format|
        format.text
      end
      m.deliver

      # send filtered mail
      @_mail_was_called = false
      @_message = Mail.new
      headers_filtered = headers.deep_dup
      headers_filtered[:to] = @relocation[:filtered][:to]
      headers_filtered[:cc] = @relocation[:filtered][:cc]
      headers_filtered[:gpg] = {
        encrypt: false,
        sign: false
      }
      if server_key
        headers_filtered[:gpg][:sign] = true
        headers_filtered[:gpg][:sign_as] = Setting['mail_from']
        headers_filtered[:gpg][:password] = server_key.secret
      end
      # headers_filtered[:subject] = '[' + @project.name + '] ' + 
      #   l( ("filtered_mail_"+@_action_name).to_sym )
      template_name = @_action_name + '.filtered'
      m = mail_without_relocation headers_filtered do |format|
        format.text { render template_name }
        format.html { render template_name } unless Setting.plain_text_mail?
      end
      m.deliver

      # send unchanged mail
      @_mail_was_called = false
      @_message = Mail.new
      headers[:to] = @relocation[:unchanged][:to]
      headers[:cc] = @relocation[:unchanged][:cc]
      headers[:gpg] = {
        encrypt: false,
        sign: false
      }
      mail_without_relocation headers, &block

    end

    def relocate(headers)

      # relocation hash
      reloaction = {
        :encrypted => {:to => [], :cc => [], :keys => {}},
        :blocked   => {:to => [], :cc => []},
        :filtered  => {:to => [], :cc => []},
        :unchanged => {:to => [], :cc => []}
      }

      # if plugin is inactive
      if Setting.plugin_openpgp['activation'] == 'none' or 
         (Setting.plugin_openpgp['activation'] == 'project' and
          not @project.module_enabled?('openpgp'))
        # unchanged mails
        reloaction[:unchanged][:to] = headers[:to]
        reloaction[:unchanged][:cc] = headers[:cc]
      # if plugin is active
      else
        [:to, :cc].each do |field|
          headers[field].each do |user|
            # encrypted mails
            key = Pgpkey.find_by user_id: user.id
            if key
              reloaction[:encrypted][field].push user
              reloaction[:encrypted][:keys][user.mail] = key.fpr
              next
            end
            case Setting.plugin_openpgp['unencrypted_mails']
              # blocked mails
              when 'blocked'
                reloaction[:blocked][field].push user and next
              # filtered mails
              when 'filtered'
                reloaction[:filtered][field].push user and next
              # unchanged mails
              when 'unchanged'
                reloaction[:unchanged][field].push user and next
            end
          end unless headers[field].blank?
        end
      end
      reloaction

    end

  end
end
